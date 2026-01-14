#!/bin/bash

grep "GET" server.log | awk -F: '{print $2}' | sort | uniq -c | sort -rn > request_count.txt