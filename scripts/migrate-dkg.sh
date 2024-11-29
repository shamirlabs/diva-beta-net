#!/bin/bash

exec_path=$1
cd $exec_path

if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
fi

set -a && source .env && set +a
docker compose up -d

echo "Node needs to be restarted and synced, the proccess may take a while..."

is_synced(){
  is_syncing=true
  while [ "$is_syncing" != "false" ]; do
    sync_response=$(curl -s -X GET \
      "http://localhost:30000/api/v2/protocol/info" \
      -H "accept: application/json" \
      -H "Authorization: Bearer $DIVA_API_KEY")

   

    is_syncing=$(echo "$sync_response" | jq -r '.data.is_syncing')

    if [ "$is_syncing" == "true" ]; then
      echo "Node is syncing..."
      sleep 5
    elif [ "$is_syncing" == "false" ]; then
      echo "Node is Synced."
      return 0
    else
      echo "Node is starting..."
      sleep 5
    fi
  done
  return 1
}

is_alive(){
  is_syncing=true
  while [ "$is_syncing" != "false" ]; do
    sync_response=$(curl -s -X GET \
      "http://localhost:30000/api/v2/protocol/info" \
      -H "accept: application/json" \
      -H "Authorization: Bearer $DIVA_API_KEY")

   

    is_syncing=$(echo "$sync_response" | jq -r '.data.is_syncing')

    if [ "$is_syncing" == "true" ]; then
      echo "Node started."
      sleep 5
      return 0
    elif [ "$is_syncing" == "false" ]; then
      echo "Node started."
      return 0
    else
      echo "Node is starting..."
      sleep 30
    fi
  done
  return 1
}

echo "Waiting for the node to be started..."
is_alive
while [ $? -ne 0 ]; do
  sleep 5
  is_alive
done
response=""
while [ -z "$response" ]; do
  response=$(curl -s -X 'POST' \
    'http://localhost:30000/api/v2/node/reset' \
    -H 'accept: application/json' \
    -H "Authorization: Bearer $DIVA_API_KEY")

  if [ -z "$response" ]; then
    echo "Node is starting, it can take around 1 min. Retrying reset..."
    sleep 30
  fi
done
echo "Reset completed."

fetch_response() {
    local response=""
    local attempts=0
    local max_attempts=5
    local sleep_duration=5
    sleep 30
    while [ -z "$response" ] && [ $attempts -lt $max_attempts ]; do
        response=$(curl -s -X 'GET' \
          'http://localhost:30000/api/v2/node/signing-pools' \
          -H 'accept: application/json' \
          -H "Authorization: Bearer $DIVA_API_KEY")
        
        if [ -z "$response" ]; then
            echo "No response received. Retrying in $sleep_duration seconds..."
            sleep $sleep_duration
            attempts=$((attempts + 1))
        else
            echo "$response" | jq empty 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "Invalid JSON response received. Retrying..."
                response=""
                sleep $sleep_duration
                attempts=$((attempts + 1))
            fi
        fi
    done

    if [ -z "$response" ]; then
        echo "Failed to fetch response after $max_attempts attempts."
        exit 1
    fi

    echo "$response"
}

is_synced
while [ $? -ne 0 ]; do
  sleep 5
  is_synced
done
echo "Waiting 1m"

response=$(fetch_response)
if [ -z "$response" ]; then
    echo "Error: Empty response received."
    exit 1
fi

validator_keys=$(echo "$response" | jq -r '.data[].validator_public_key' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$validator_keys" ]; then
    echo "Error: Unable to parse validator_public_key from response."
    exit 1
fi

for validator_key in $validator_keys; do
    echo "Processing validator_public_key: $validator_key"
    put_response=""
    attempts=0
    max_attempts=10
    while [ -z "$put_response" ] && [ $attempts -lt $max_attempts ]; do
        put_response=$(curl -s -X PUT \
            "http://localhost:30000/api/v2/node/signing-pools/$validator_key/slashing-protection" \
            -H "accept: application/json" \
            -H "Authorization: Bearer $DIVA_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{ "attestation": null, "block": null }')
        echo "$put_response" | jq empty 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Invalid response for $validator_key. Retrying..."
            put_response=""
            sleep 5
            attempts=$((attempts + 1))
        fi
    done

    if [ -z "$put_response" ]; then
        echo "Failed to send PUT request for $validator_key after $max_attempts attempts."
    else
        echo "Request successful for $validator_key"
    fi
done

echo "Upgrade completed."
