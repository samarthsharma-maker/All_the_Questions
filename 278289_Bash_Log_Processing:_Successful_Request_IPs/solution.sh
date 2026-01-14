#!/bin/bash

grep " 200 " web.log | awk '{print $8}' | sort -u > unique_success_ips.txt