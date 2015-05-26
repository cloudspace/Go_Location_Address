#Not sure why this user is missing
DATADIR="/var/lib/postgresql/9.3/main"
CONF="/etc/postgresql/9.3/main/postgresql.conf"
POSTGRES="/usr/lib/postgresql/9.3/bin/postgres"
su - postgres -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF <<< \"CREATE USER docker WITH SUPERUSER ENCRYPTED PASSWORD 'docker';\""

#Download state data
GISDIR="/gisdata"
TMPDIR=${GISDIR}/temp
UNZIPTOOL=unzip
WGETTOOL="/usr/bin/wget"
STATEID=$1
FILENAMEPATTERN=$2
DBPATH=$3

mkdir $GISDIR
chmod -R 777 $GISDIR
cd $GISDIR
wget ftp://${DBPATH}${FILENAMEPATTERN} --no-parent --relative --recursive --level=2 --accept=zip --reject=html -nc
cd ${GISDIR}/${DBPATH}

for z in ${FILENAMEPATTERN} ; do $UNZIPTOOL -o -d $TMPDIR $z; done
for z in */${FILENAMEPATTERN} ; do $UNZIPTOOL -o -d $TMPDIR $z; done

##### Import into db
service postgresql start

export PGBIN=/usr/bin/
PSQL=${PGBIN}/psql
SHP2PGSQL=${PGBIN}/shp2pgsql

cd $TMPDIR;
sudo -u postgres ${PSQL} -d postgres -c "DROP SCHEMA IF EXISTS tiger_staging CASCADE;"
sudo -u postgres ${PSQL} -d postgres -c "CREATE SCHEMA tiger_staging;"

sudo -u postgres ${PSQL} -d postgres -c "CREATE TABLE tiger_data._addrfeat(CONSTRAINT pk_addrfeat PRIMARY KEY (gid)) INHERITS(addrfeat);ALTER TABLE tiger_data.${STATEABBR}_addrfeat ALTER COLUMN statefp SET DEFAULT '12';"

for z in *.dbf; do
  sudo -u postgres ${SHP2PGSQL} -D -S -s 4269 -g the_geom -W "latin1" $z tiger_staging._addrfeat | sudo -u postgres ${PSQL} -d postgres
  sudo -u postgres ${PSQL} -d postgres -c "ALTER TABLE tiger_staging._addrfeat DROP COLUMN road_mtfcc, DROP COLUMN tfidl, DROP COLUMN tfidr;"
  sudo -u postgres ${PSQL} -d postgres -c "SELECT loader_load_staged_data(lower('_addrfeat'), lower('_addrfeat'));"
done

sudo -u postgres ${PSQL} -d postgres -c "ALTER TABLE tiger_data._addrfeat NO INHERIT addrfeat;"
sudo -u postgres ${PSQL} -d postgres -c "ALTER TABLE tiger_data._addrfeat DROP COLUMN gid, DROP COLUMN tlid, DROP COLUMN aridl, DROP COLUMN aridr, DROP COLUMN linearid, DROP COLUMN zipl, DROP COLUMN zipr, DROP COLUMN edge_mtfcc, DROP COLUMN parityr, DROP COLUMN plus4l, DROP COLUMN plus4r, DROP COLUMN lfromtyp, DROP COLUMN ltotyp, DROP COLUMN rfromtyp, DROP COLUMN rtotyp, DROP COLUMN offsetl, DROP COLUMN offsetr, DROP COLUMN statefp, DROP COLUMN parityl;"

sudo -u postgres ${PSQL} -d postgres -c "vacuum full analyze;"
sudo -u postgres reindexdb

#cleanup
rm -f ${TMPDIR}/*.*
service postgresql stop
apt-get purge -y wget
apt-get purge -y unzip
apt-get clean
