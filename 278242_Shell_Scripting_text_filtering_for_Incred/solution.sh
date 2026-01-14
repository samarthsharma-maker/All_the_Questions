#!/bin/bash

set -euo pipefail
awk '$4 == "POST" { print $3 }' log.tf | sort | uniq > unique_ip.txt
