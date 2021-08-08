#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]]; then
  echo "The script need to be run as root..."
  exit 1
fi

systemctl daemon-reload
systemctl enable step-ca
systemctl start step-ca
systemctl status step-ca
# journalctl --follow --unit=step-ca