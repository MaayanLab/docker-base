#!/bin/bash

set -e

for f in $(find /root -maxdepth 2 -name entrypoint.sh); do
  . "$f"
done
