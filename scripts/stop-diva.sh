#!/bin/bash

exec_path=$1
cd $exec_path

choice=$(dialog --title "Stop Diva" --menu "Choose an action:" 10 45 2 \
1 "Stop containers only" \
2 "Stop and remove containers" \
3>&1 1>&2 2>&3 3>&-)

if [ "$choice" == "1" ]; then
    action="stop"
elif [ "$choice" == "2" ]; then
    action="rm -f"
else
    exit 1
fi


if docker ps --format '{{.Names}}' | grep -qE 'beacon|execution'; then
    stop_choice=$(dialog --title "Stop/Remove containers" --menu "Choose what to stop/remove:" 11 45 3 \
    1 "Diva and helpers" \
    2 "Ethereum clients" \
    3 "Both of them" \
    3>&1 1>&2 2>&3 3>&-)

    case $stop_choice in
        1)
            docker $action diva prometheus vector validator operator-ui grafana node-exporter
            ;;
        2)
            docker $action beacon execution
            ;;
        3)
            docker $action beacon execution diva prometheus vector validator operator-ui grafana node-exporter
            ;;
        *)
            exit 1
            ;;
    esac
else
    docker $action diva prometheus vector validator operator-ui grafana node-exporter
fi