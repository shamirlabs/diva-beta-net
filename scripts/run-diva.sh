#!/bin/bash
cd $(dirname -- "$0")

exec_path=$1

HEIGHT=16
WIDTH=40
TITLE="Install Diva"

MIN_MEMORY_MB=8192  # 8 GB
MIN_DISK_SPACE_GB=750  # 750 GB
MIN_CPU_CORES=4  # 4 CPU cores
rungrafana=false
runclients=false

if [[ ! -x "$(command -v docker)" ]]; then
    # Docker is not installed
    dialog --title "$TITLE" --yesno "We need to install docker in your machine first. After docker is installed, you will need to close your SSH session, login and execute the script again.\n\nDo you want to continue?" 0 0
    exitcode=$?;
    if [ $exitcode -ne 1 ];
    then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh

        sudo groupadd docker
        sudo usermod -aG docker $USER
    fi
    clear
    exit 1
fi

cd $exec_path
git pull --quiet

if [[ -f ".env" ]]; then
    # .env already exists
    dialog --title "$TITLE" --yesno ".env exists in the project directory\n\nDo you want to run Diva with the current .env configuration?" 0 0
    exitcode=$?;
    if [ $exitcode -ne 1 ];
    then
        docker compose up -d
        exit 1
    fi
else
    cp .env.example .env
    # Let's assume the vault_password should be generated randomly
    vault_pw=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    sed -i.bak -e "s,^DIVA_VAULT_PASSWORD *=.*,DIVA_VAULT_PASSWORD=${vault_pw}," .env
fi

dialog --title "$TITLE" --yesno "Do you want to run your own Ethereum clients in this machine?" 0 0
exitcode=$?;

if [ $exitcode -eq 1 ];
then
    MENU="Type the IP and PORT of your execution client websocket RPC\n"
    if [ -f .env ]; then
        current_url=$(grep -E '^EXECUTION_CLIENT_URL=' .env | cut -d '=' -f2 | cut -d ' ' -f1)
        if ! [ -z "$current_url" ]; then
            MENU="Type the IP and PORT of your execution client websocket RPC\n\nCurrent configuration: $current_url \n"
        fi
    fi
    WARN="Example: ws://HOST_IP:8546 for geth"

    while true
    do
        execution_client_url=$(dialog --clear \
                    --title  "$TITLE" \
                    --inputbox "$MENU \n$WARN" \
                    $HEIGHT $WIDTH 2>&1 >/dev/tty)

        exitcode=$?;
        if [ $exitcode -eq 1 ];
        then
            exit 1
        fi
        if [[ ! -z "${execution_client_url}" && "${execution_client_url}" =~ ^[wW][sS]:// ]];
        then
            sed -i.bak -e "s,^EXECUTION_CLIENT_URL *=.*,EXECUTION_CLIENT_URL=${execution_client_url}," .env
            break
        else
            WARN="WebSocket validation error for \"${execution_client_url}\""
        fi
    clear
    done


    MENU="Type the IP and PORT of your consensus client REST API\n"
    WARN="Example: http://HOST_IP:5052 for Lighthouse"
    if [ -f .env ]; then
        current_url=$(grep -E '^CONSENSUS_CLIENT_URL=' .env | cut -d '=' -f2 | cut -d ' ' -f1)
        if ! [ -z "$current_url" ]; then
            MENU="Type the IP and PORT of your consensus client REST API\n\nCurrent configuration: $current_url \n"
        fi
    fi
    while true
    do
        consensus_client_url=$(dialog --clear \
                    --title  "$TITLE" \
                    --inputbox "$MENU \n$WARN" \
                    $HEIGHT $WIDTH 2>&1 >/dev/tty)

        exitcode=$?;
        if [ $exitcode -eq 1 ];
        then
            exit 1
        fi

        status_code=$(curl --write-out '%{http_code}' --silent --output /dev/null $consensus_client_url/eth/v1/node/health)
        if [[ "$status_code" -lt 300 ]] ; then
            sed -i.bak -e "s,^CONSENSUS_CLIENT_URL *=.*,CONSENSUS_CLIENT_URL=${consensus_client_url}," .env
            break
        else
            WARN="HTTP connection error for \"${consensus_client_url}\""
        fi
    clear
    done
else

    AVAILABLE_MEMORY_MB=$(free -m | awk '/^Mem:/{print $7}')

    if [ "$AVAILABLE_MEMORY_MB" -lt "$MIN_MEMORY_MB" ]; then
        echo "Error: Not enough available memory. At least ${MIN_MEMORY_MB}MB are required."
        exit 1
    fi

    if [ ! -d "./beacon" ] || [ ! -d "./execution" ]; then
        AVAILABLE_DISK_SPACE_GB=$(df -P . | tail -1 | awk '{print $4}')

        if [ "$AVAILABLE_DISK_SPACE_GB" -lt "$(($MIN_DISK_SPACE_GB*1000000))" ]; then
            echo "Error: Not enough available disk space. At least ${MIN_DISK_SPACE_GB}GB are required."
            exit 1
        fi
    fi
    
    AVAILABLE_CPU_CORES=$(nproc)

    if [ "$AVAILABLE_CPU_CORES" -lt "$MIN_CPU_CORES" ]; then
        echo "Error: Not enough CPU cores. At least ${MIN_CPU_CORES} cores are required."
        exit 1
    fi

    runclients=true
    dialog --title "$TITLE" --yesno "Do you want to run a Grafana to monitor your node?" 0 0
    exitcode=$?;
    if [ $exitcode -ne 1 ]; then
        rungrafana=true
        envsubst < "./prometheus/config/prometheus_template.yaml" > "./prometheus/config/prometheus.yaml"
    fi

    sed -i.bak -e "s,^EXECUTION_CLIENT_URL *=.*,EXECUTION_CLIENT_URL=ws://execution:8546," .env
    sed -i.bak -e "s,^CONSENSUS_CLIENT_URL *=.*,CONSENSUS_CLIENT_URL=http://beacon:5052," .env
fi

if [[ "$runclients" == "true" && "$rungrafana" == "true" ]]; then
    sed -i.bak -e "s/^COMPOSE_PROFILES *=.*/COMPOSE_PROFILES=metrics,clients/" .env
elif [[ "$runclients" == "false" && "$rungrafana" == "true" ]]; then
    sed -i.bak -e "s/^COMPOSE_PROFILES *=.*/COMPOSE_PROFILES=metrics/" .env
elif [[ "$runclients" == "true" && "$rungrafana" == "false" ]]; then
    sed -i.bak -e "s/^COMPOSE_PROFILES *=.*/COMPOSE_PROFILES=clients/" .env
elif [[ "$runclients" == "false" && "$rungrafana" == "false" ]]; then
    sed -i.bak -e "s/^COMPOSE_PROFILES *=.*/COMPOSE_PROFILES=/" .env
fi

current_pw=$(grep -E '^DIVA_API_KEY=' .env | cut -d '=' -f2 | cut -d ' ' -f1)
if [ "$current_pw" == "changeThis" ]; then
    change_password=true
else
    dialog --title "$TITLE" --yesno "Do you want to edit your current password?" 0 0
    exitcode=$?;
    if [ $exitcode -ne 1 ];
    then
        change_password=true        
    fi
    clear
fi

if [ "$change_password" == true ]; then
    MENU="Type the API key/password that you want to use to connect to your Diva node\n"
    WARN='Example: UseSecureP4ssw0rd$!'

    while true
    do
        diva_api_key=$(dialog --clear \
                    --title  "$TITLE" \
                    --inputbox "$MENU \n$WARN" \
                    $HEIGHT $WIDTH 2>&1 >/dev/tty)

        exitcode=$?;
        if [ $exitcode -eq 1 ];
        then
            exit 1
        fi

        if ! [ -z "${diva_api_key}" ]
        then
            sed -i.bak -e "s/^DIVA_API_KEY *=.*/DIVA_API_KEY=${diva_api_key}/" .env
            break
        else
            WARN="Invalid API key \"${diva_api_key}\""
        fi
    clear
    done
fi
clear

current_username=$(grep -E '^TESTNET_USERNAME=' .env | cut -d '=' -f2 | cut -d ' ' -f1)
if [ "$current_username" == "username-operatoraddress" ]; then
    change_username=true
else
    dialog --title "$TITLE" --yesno "Do you want to edit your current username?" 0 0
    exitcode=$?;
    if [ $exitcode -ne 1 ]; then
        change_username=true        
    fi
    clear
fi

if [ "$change_username" == true ]; then
    MENU="Type the username that you want to use in the Diva testnet\n"
    WARN="Example: username-address"

    while true
    do
        username=$(dialog --clear \
                    --title  "$TITLE" \
                    --inputbox "$MENU \n$WARN" \
                    $HEIGHT $WIDTH 2>&1 >/dev/tty)

        exitcode=$?;
        if [ $exitcode -eq 1 ];
        then
            exit 1
        fi

        if ! [ -z "${username}" ]
        then
            sed -i.bak -e "s,^TESTNET_USERNAME *=.*,TESTNET_USERNAME=${username}," .env
            break
        else
            WARN="\"${username}\" is not a valid username"
        fi
    clear
    done
fi

export $(grep -v '^#' ./.env | sed 's/ *#.*//g' | xargs)

docker compose up -d
