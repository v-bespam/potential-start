#!/bin/bash

# Pulling up new versions for conteiners in compose file and run them
docker compose pull
docker compose up -d

if [[ "$?" -eq 1 ]]; then
  echo "Can't upgrade Docker containers. Something went wrong."
  exit 1
fi

# Removing Unused Images
docker image prune -f
docker image prune -a -f

# Removing Unused Volumes
docker volume prune -f
