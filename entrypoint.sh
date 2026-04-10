#!/bin/bash

set -e

for f in $(find /opt -maxdepth 2 -name entrypoint.sh); do
  . "$f"
done
