directories=($(curl ftp://ftp2.census.gov/geo/tiger/ -l))

latestYear=0
indexOfDirectory=0

function lowercase() {
  echo $1 | tr '[:upper:]' '[:lower:]'
}

for i in "${!directories[@]}" ; do
    directory="${directories[$i]}"
    year=$(echo "$directory" | perl -wnE'say for /(?<=TIGER)([0-9]{4})$/')

    if [ -z "$year" ]; then
        continue
    fi
    if (($year>$latestYear)); then
        latestYear=$year
        indexOfDirectory=$i
    fi
done

fullDirectory="ftp2.census.gov\\/geo\\/tiger\\/""${directories[$indexOfDirectory]}""\\/ADDRFEAT\\/"

stateToID=("AL" "AK" "AZ" "AR" "CA" "CO" "CT" "DE" "DC" "FL" "GA" "HI" "ID" "IL" "IN" "IA" "KS" "KY" "LA" "ME" "MD" "MA" "MI" "MN" "MS" "MO" "MT" "NE" "NV" "NH" "NJ" "NM" "NY" "NC" "ND" "OH" "OK" "OR" "PA" "RI" "SC" "SD" "TN" "TX" "UT" "VT" "VA" "WA" "WV" "WI" "WY")
IDToState=("01" "02" "04" "05" "06" "08" "09" "10" "11" "12" "13" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31" "32" "33" "34" "35" "36" "37" "38" "39" "40" "41" "42" "44" "45" "46" "47" "48" "49" "50" "51" "53" "54" "55" "56")
for i in "${!stateToID[@]}"
do
  state=${stateToID[$i]}
  stateId=${IDToState[$i]}
  stateLowerCase=$(lowercase $state)

  alreadyExists=$(docker images | grep "izackp/go_location_address_${stateLowerCase}     0.2");
  if [ -n "$alreadyExists" ]; then
      echo "izackp/go_location_address_${stateLowerCase} already exists"
      continue
  fi

  mkdir $state

  cp ./Go_Location_Address ./$state/Go_Location_Address
  cp ./loadStateInfo.sh ./$state/loadStateInfo.sh

  cd $state
  sed "s/__STATE_ID__/${stateId}/g; s/__FTP_DIRECTORY__/${fullDirectory}/g" ../Dockerfile.template > Dockerfile
  sed "s/__STATE_ABBR__/${state}/g; s/__STATE_ABBR_LC__/${stateLowerCase}/g" ../microservice.yml.template > microservice.yml

  docker build -t izackp/go_location_address_${stateLowerCase}:0.2 ./

  docker push izackp/go_location_address_${stateLowerCase}:0.2
  cd ..

done
