# Generate Docker Images
This will generate up to date docker images containing postgres TIGER address data (ADDRFEAT) for each state in the united states

#### Usage

1.  Build Go_Location_Address and place it inside of the GenerateDockerImages directory
2.  Update generateDockerFiles.sh and microservice.yml.template with your docker username/tag
3.  Start up boot2docker and make sure that your shell is initialized with the proper exports
4.  chmod +x generateDockerFiles.sh
5.  run generateDockerFiles.sh
