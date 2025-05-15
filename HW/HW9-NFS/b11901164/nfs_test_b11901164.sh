#!/bin/bash

# env
MOUNT_DIR="/mnt/nfs-share"
FILENAME="${USER}_dir/testfile_${USER}_$(hostname)"
FILEPATH="$MOUNT_DIR/$FILENAME"

# remove the existing file
if [ -f "$FILEPATH" ]; then
  rm -f "$FILEPATH"
fi

# get the load before testing
LOAD_BEFORE=$(uptime | awk -F'load average: ' '{print $2}' | cut -d',' -f1)

echo "建立測試檔案：$FILEPATH"

# write 1GB test file
START_WRITE=$(date +%s.%N)
dd if=/dev/zero of=$FILEPATH bs=1M count=1024 oflag=direct status=none
END_WRITE=$(date +%s.%N)
WRITE_TIME=$(echo "$END_WRITE - $START_WRITE" | bc)
WRITE_SPEED=$(echo "scale=2; 1024 / $WRITE_TIME" | bc)

# Read
START_READ=$(date +%s.%N)
dd if=$FILEPATH of=/dev/null bs=1M iflag=direct status=none
END_READ=$(date +%s.%N)
READ_TIME=$(echo "$END_READ - $START_READ" | bc)
READ_SPEED=$(echo "scale=2; 1024 / $READ_TIME" | bc)

# avg speed
AVG_SPEED=$(echo "scale=2; ($WRITE_SPEED + $READ_SPEED) / 2" | bc)

# get the load after testing
LOAD_AFTER=$(uptime | awk -F'load average: ' '{print $2}' | cut -d',' -f1)

# output
echo "寫入時間：$WRITE_TIME s"
echo "寫入速率：$WRITE_SPEED MB/s"
echo "讀取時間：$READ_TIME s"
echo "讀取速率：$READ_SPEED MB/s"
echo "平均傳輸速率：$AVG_SPEED MB/s"
echo "CPU 使用率/負載：$LOAD_BEFORE → $LOAD_AFTER"

