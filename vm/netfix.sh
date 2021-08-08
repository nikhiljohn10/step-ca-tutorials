#!/bin/bash

for table in filter nat mangle; do
  sudo iptables-legacy -t $table -S | grep Multipass | xargs -L1 sudo iptables-nft -t $table
done