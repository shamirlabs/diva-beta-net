#!/bin/bash

exec_path=$1
cd $exec_path

if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
fi
set -a && source .env && set +a
docker compose up -d
response=""
while [ -z "$response" ]; do
  response=$(curl -s -X 'POST' \
    'http://localhost:30000/api/v2/node/reset' \
    -H 'accept: application/json' \
    -H "Authorization: Bearer $DIVA_API_KEY")
  
  if [ -z "$response" ]; then
    sleep 5
  fi
done