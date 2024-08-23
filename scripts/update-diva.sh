#!/bin/bash

exec_path=$1
cd $exec_path

if [ ! -d "diva_backup" ]; 
then   
    mkdir diva_backup; 
fi


UPDATE_TIME=$(date +%Y%m%d%H%M%S)
mkdir diva_backup/bkp_$UPDATE_TIME

cp -r .diva diva_backup/bkp_$UPDATE_TIME/
cp docker-compose.yml diva_backup/bkp_$UPDATE_TIME/docker-compose.yml
cp .env diva_backup/bkp_$UPDATE_TIME/.env

git reset --hard origin/main
git pull

sudo cp -r diva_backup/bkp_$UPDATE_TIME/.diva/* .diva
sudo cp diva_backup/bkp_$UPDATE_TIME/.env .env

docker compose pull
docker compose up -d
