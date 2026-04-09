#!/bin/bash

for f in $(find /root -maxdepth 2 -name install.sh); do
  bash "$f" &
done

wait
