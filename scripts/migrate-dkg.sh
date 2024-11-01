#!/bin/bash

exec_path=$1
cd $exec_path

if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
fi

set -a && source .env && set +a
response=$(curl -s -X 'GET' \
  'http://localhost:30000/api/v2/participant/dkgs' \
  -H 'accept: application/json' \
  -H "Authorization: Bearer $DIVA_API_KEY")

old_dkgs=$(echo "$response" | jq -r '. | if .error then 1 else 0 end')

if [ "$old_dkgs" -eq 1 ]; then
  code=$(echo "$response" | jq -r '.error.code')
  
  if [ "$code" == "PARTICIPANT_DELETING_ALL_DKGS" ]; then
    curl -s -X 'DELETE' \
      'http://localhost:30000/api/v2/participant/dkgs' \
      -H 'accept: application/json' \
      -H "Authorization: Bearer $DIVA_API_KEY"
  fi
fi
