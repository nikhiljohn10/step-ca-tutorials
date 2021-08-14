#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]]; then
    echo "PERMISSION DEINED: Require root access."
    exit 1
else
  for table in filter nat mangle; do
    iptables-legacy -t $table -S | grep Multipass | xargs -L1 iptables-nft -t $table
  done
fi

