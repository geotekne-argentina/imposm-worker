#!/bin/bash
# execute docker-compose which includes a pgadmin, a postgres database and the importing process using a sample PBF file download

# Download my Selection PBF (ie. Estonia)
echo -e "\n --- Download OSM High Resolution Sample PBF file ---"
curl "https://download.geofabrik.de/europe/estonia-latest.osm.pbf" -o ./pbfs/andorra-latest.osm.pbf

echo -e "\n --- Importing PBF into Postgis database ---"
docker-compose up
