#!/bin/bash

exec_path=$1
cd $exec_path

choice=$(dialog --title "$TITLE" --menu "Select an option:" 12 50 2 \
1 "Perform backup" \
2 "Backup and delete Diva's database" \
3>&1 1>&2 2>&3 3>&-)

case $choice in
    1)
        echo "You chose to perform a backup only."
        
        if [ ! -d "diva_backup" ]; then
            mkdir diva_backup
        fi

        UPDATE_TIME=$(date +%Y%m%d%H%M%S)
        mkdir diva_backup/bkp_$UPDATE_TIME

        cp -r .diva diva_backup/bkp_$UPDATE_TIME/
        cp docker-compose.yml diva_backup/bkp_$UPDATE_TIME/docker-compose.yml
        cp .env diva_backup/bkp_$UPDATE_TIME/.env

        echo "Backup completed successfully."
        exit 1
        ;;

    2)
        echo "You chose to backup and delete Diva's database."
        
        if [ ! -d "diva_backup" ]; then
            mkdir diva_backup
        fi

        UPDATE_TIME=$(date +%Y%m%d%H%M%S)
        mkdir diva_backup/bkp_$UPDATE_TIME

        cp -r .diva diva_backup/bkp_$UPDATE_TIME/
        cp docker-compose.yml diva_backup/bkp_$UPDATE_TIME/docker-compose.yml
        cp .env diva_backup/bkp_$UPDATE_TIME/.env

        if [ -d ".diva" ]; then
            sudo rm -rf .diva
            echo "Diva's database has been deleted."
        else
            echo "No Diva database found to delete."
        fi
        rm .env
        exit 1
        ;;                
    *)
        echo "Operation cancelled."
        exit 1
        ;;
esac
