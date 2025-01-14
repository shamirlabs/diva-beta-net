#!/bin/bash

exec_path=$1
cd $exec_path

if [ ! -d "diva_backup" ]; 
then   
    mkdir diva_backup; 
fi

UPDATE_TIME=$(date +%Y%m%d%H%M%S)
mkdir diva_backup/bkp_$UPDATE_TIME
docker compose down
cp -r .diva diva_backup/bkp_$UPDATE_TIME/
cp docker-compose.yml diva_backup/bkp_$UPDATE_TIME/docker-compose.yml
cp .env diva_backup/bkp_$UPDATE_TIME/.env

git fetch
git reset --hard origin/main

docker stop prometheus
docker rm -f prometheus

if [ -d "prometheus" ];
then
    sudo rm -rf prometheus
fi

if [ -d ".docker/prometheus/config/prometheus.yml" ];
then
    sudo rm -rf .docker/prometheus/config/prometheus.yml
fi

set -a && source .env && set +a && envsubst < "./.docker/prometheus/config/prometheus.yml.template" > "./.docker/prometheus/config/prometheus.yml"

sudo cp -r diva_backup/bkp_$UPDATE_TIME/.diva/* .diva
sudo cp diva_backup/bkp_$UPDATE_TIME/.env .env

docker compose pull

if [[ -f ".env" ]]; then
    # .env already exists
    dialog --title "$TITLE" --yesno "Do you want to run the update with the exsiting configuration?" 0 0
    exitcode=$?;
    if [ $exitcode -ne 1 ];
    then
        docker compose up -d
        exit 1
    fi
else
    ./scripts/run-diva.sh $exec_path
fi
