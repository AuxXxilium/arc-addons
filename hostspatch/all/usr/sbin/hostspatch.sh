#!/usr/bin/env bash

# Define the entries to be added
ENTRIES=("127.0.0.1 checkip.synology.com" "::1 checkipv6.synology.com")

# Loop over each entry
for ENTRY in "${ENTRIES[@]}"
do
  if [ -f /etc/hosts ]; then
      # Check if the entry is already in the file
      if grep -Fxq "$ENTRY" /etc/hosts; then
          echo "Entry $ENTRY already exists"
      else
          echo "Entry $ENTRY does not exist, adding now"
          echo "$ENTRY" >> /etc/hosts
      fi
  fi
  if [ -f /etc.defaults/hosts ]; then
      if grep -Fxq "$ENTRY" /etc.defaults/hosts; then
          echo "Entry $ENTRY already exists"
      else
          echo "Entry $ENTRY does not exist, adding now"
          echo "$ENTRY" >> /etc.defaults/hosts
      fi
  fi
done

exit 0