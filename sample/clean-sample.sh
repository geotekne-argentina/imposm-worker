#!/bin/bash
docker-compose down
docker volume rm sample_pgdata
rm ./pbfs/*.pbf
