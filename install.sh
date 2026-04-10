#!/bin/bash

for f in $(find /opt -maxdepth 2 -name install.sh); do
  bash "$f" &
done

wait
