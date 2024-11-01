#!/bin/bash

exec_path=$1
cd $exec_path

set -a && source .env && set +a

host="localhost"
port=30000
timeout=15
elapsed=0
while ! sh -c "echo > /dev/tcp/$host/$port" 2>/dev/null; do
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timeout reached: Port $port is not listening after $timeout seconds."
    exit 1
  fi
  echo "Waiting for port $port to be opened... ($elapsed seconds)"
  sleep 1
  elapsed=$((elapsed + 1))  # Incrémentation de elapsed
done

response=$(curl -sS -X 'GET' \
  "http://$host:$port/api/v2/participant/dkgs" \
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
      "http://$host:$port/api/v2/participant/dkgs" \
      -H 'accept: application/json' \
      -H "Authorization: Bearer $DIVA_API_KEY"
  fi
fi
