#!/bin/bash
# Run this as the 'vagrant' user on an LMS devstack to easily transfer log files
# to the analytics devstack

cd /edx/var/log/tracking/ || exit

MATCH="tracking.log-*.gz"
TARGET_DIR="/edx-analytics-pipeline/input"
WEB_HDFS_URL="http://192.168.33.11:50075/webhdfs/v1"

for f in $MATCH
do
  echo "Uploading $f..."
  curl -i -X PUT -T $f "$WEB_HDFS_URL$TARGET_DIR/$f?op=CREATE&namenoderpcaddress=localhost:9000&overwrite=true&user.name=hadoop"
done
