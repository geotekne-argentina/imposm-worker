#!/bin/bash
# Usage import-pg.sh [-i osm_pbf_location] [-p postgresqlPort] [-c postgresqlContainerName] [-v postgresqlVersion]
# -i Location of the PBF file to import, or directory containing multiple files with .pbf extensions, to support multi-file import, defaults to $PBF_LOCATION
# -p Local port to use for the PostgreSQL container, defaults to $PG_PORT_DEFAULT
# -v Version of the PostGIS Image to be used, defaults to $PG_IMAGE_VERSION_DEFAULT
# -c Name of the container used for the PostgreSQL container, defaults to $PG_CONTAINER_DEFAULT
# -d Database name to use for importation process, defaults to $PG_DATABASE_DEFAULT
# -u Username for connection, defaults to $PG_USERNAME_DEFAULT
# -w Username's password, defaults to $PG_PASSWORD_DEFAULT

# Variables and defaults
PG_PORT_DEFAULT=25432
PG_PORT=$PG_PORT_DEFAULT
PG_CONTAINER_DEFAULT=osm-postgis
PG_CONTAINER=$PG_CONTAINER_DEFAULT
PG_IMAGE_VERSION_DEFAULT=12.1
PG_IMAGE_VERSION=$PG_IMAGE_VERSION_DEFAULT
PG_USERNAME_DEFAULT=docker
PG_USERNAME=$PG_USERNAME_DEFAULT
PG_PASSWORD_DEFAULT=docker
PG_PASSWORD=$PG_PASSWORD_DEFAULT
PG_DATABASE_DEFAULT=gis
PG_DATABASE=$PG_DATABASE_DEFAULT
PBF_LOCATION_DEFAULT=/pbfs
PBF_LOCATION=$PBF_LOCATION_DEFAULT

# Parse input parameters
set -e
while getopts d::u::w::p::c::v::i: option
do
  case "${option}" in
    p) PG_PORT=${OPTARG};;
    c) PG_CONTAINER=${OPTARG};;
    v) PG_IMAGE_VERSION=${OPTARG};;
    i) PBF_LOCATION=${OPTARG};;
    d) PG_DATABASE=${OPTARG};;
    u) PG_USERNAME=${OPTARG};;
    w) PG_PASSWORD=${OPTARG};;   
  esac
done

echo -e "\n----------- Starting importation process"
# Resolve userid and username in case the command has been called using SUDO
USERID=$UID
USERNAME=$USER
if [ $SUDO_UID ]; then
    USERID=$SUDO_UID
    USERNAME=$SUDO_USER
fi

echo -e "\n---------- Using user id $USERID and username $USERNAME"
mkdir -p work
chown $USERNAME: work

# Wait for Postgis to be ready
echo -e "\n----------- Waiting for Postgis to be ready"
RETRIES=30
until pg_isready -h $PG_CONTAINER -U docker -p 5432 -d gis || [ $RETRIES -eq 0 ]; do
  echo "Waiting for Postgis, $((RETRIES-=1)) remaining attempts..."
  sleep 2
done

mkdir -p work/tmp
rm -rf work/tmp/*

# Create importation working files, from PBF file or files (depending on PBF_LOCATION value)
IMPOSM=false
if [ -f "$PBF_LOCATION" ]; then
  echo -e "\n----------- Running imposm, read from pbf"
  /root/go/bin/imposm import -mapping /scripts/mapping.yml -read $PBF_LOCATION -cachedir work/tmp
  IMPOSM=true
else
  for pbf in $PBF_LOCATION/*.pbf; do
    if [ -f "$pbf" ]; then
        echo -e "\n----------- Running imposm, reading file $pbf"
    	  /root/go/bin/imposm import -mapping /scripts/mapping.yml -read $pbf --appendcache -cachedir work/tmp
        IMPOSM=true
    fi
  done
fi
# Apply importation working files to Postgis
if [ $IMPOSM = true ]; then
	echo -e "\n----------- Running imposm, write to database at $PG_CONTAINER"
        /root/go/bin/imposm import -mapping /scripts/mapping.yml -cachedir work/tmp -write -connection "postgis://$PG_USERNAME:$PG_PASSWORD@$PG_CONTAINER:$PG_PORT/$PG_DATABASE"
	echo -e "\n----------- Deploy imported tables to production"
        /root/go/bin/imposm import -mapping /scripts/mapping.yml -connection "postgis://$PG_USERNAME:$PG_PASSWORD@$PG_CONTAINER:$PG_PORT/$PG_DATABASE" -deployproduction
	echo -e "\n----------- Remove backup scheme"
        /root/go/bin/imposm import -mapping /scripts/mapping.yml -connection "postgis://$PG_USERNAME:$PG_PASSWORD@$PG_CONTAINER:$PG_PORT/$PG_DATABASE" -removebackup
	echo -e "\n----------- Import of PBFs files on Postgis done"
else 
        echo -e "\n----------- Nothing to read from $PBF_LOCATION. Is it ok?"
fi
echo -e "\n----------- Importation process finished"
