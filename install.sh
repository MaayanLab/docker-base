#!/bin/bash

for f in $(find /opt -maxdepth 2 -name install.sh); do
  bash "$f" &
done

while [ $(jobs -rp | wc -l) -gt 0 ]; do
   wait -n || { echo "A job failed!"; exit 1; }
done
