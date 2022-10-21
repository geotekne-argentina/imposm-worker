#!/bin/sh
echo 'Importing OSM files into database'
/scripts/import-pg.sh $PARAMETERS
