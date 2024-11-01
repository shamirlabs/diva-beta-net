#!/bin/bash

exec_path=$1
cd $exec_path

set -a && source .env && set +a
response=$(curl -sS -X 'GET' \
  'http://localhost:30000/api/v2/participant/dkgs' \
  -H 'accept: application/json' \
  -H "Authorization: Bearer $DIVA_API_KEY" 2>&1)

if [ $? -ne 0 ]; then
  echo "$response"
  exit 1
fi

old_dkgs=$(echo "$response" | jq -r '. | if .error then 1 else 0 end')

if [ "$old_dkgs" -eq 1 ]; then
  code=$(echo "$response" | jq -r '.error.code')

  if [ "$code" == "PARTICIPANT_DELETING_ALL_DKGS" ]; then
    curl -sS -X 'DELETE' \
      'http://localhost:30000/api/v2/participant/dkgs' \
      -H 'accept: application/json' \
      -H "Authorization: Bearer $DIVA_API_KEY"
  fi
fi
