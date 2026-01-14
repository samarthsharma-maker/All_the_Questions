#!/bin/bash

grep -E ";40[13];" access.log | awk -F';' '{print $6}' | sort | uniq -c | sort -rn | awk '$1 >= 3' > suspicious_ips.txt