#!/bin/bash

cd $(dirname -- "$0")

exec_path=$(pwd)

if ! command -v dialog &> /dev/null
then
    echo "dialog could not be found. Installing dialog"
    if [[ $OSTYPE == 'darwin'* ]]; then
        brew install dialog
    else
        sudo apt update -y
        sudo apt install dialog -y
    fi
fi


HEIGHT=14
WIDTH=35
CHOICE_HEIGHT=4
TITLE="Diva Beta testnet"
MENU="Select one of the following options:"

OPTIONS=(1 "Run Diva"
         2 "Update Diva"
         3 "Stop Diva"
         4 "Backup and delete Diva")

CHOICE=$(dialog --clear \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            ./scripts/run-diva.sh $exec_path
            ;;
        2)
            ./scripts/update-diva.sh $exec_path
            ;;
        3)
            ./scripts/stop-diva.sh $exec_path
            ;;
        4)
            ./scripts/cleanup-diva.sh $exec_path
            ;;            
esac
