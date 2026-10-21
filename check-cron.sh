#!/bin/bash

# Check whether cron is regulary running at your Moodle site.
# The script exits with 0 and remains silent if everything is
# ok. The interval by default are 600 seconds -> 10 minutes.
# When the lastrun was before that timeframe, exit code 1 is
# send and an output it done to strout.
#
# Usage ./check-cron.sh [ MOODLE_DIR ] [ INTERVAL ]
#
# If MOODLE_DIR is not set, the current working directory is used.
# If INTERVAL is not set, 600 seconds are used.

# Where is you moodle root directory?
  MOODLE_DIR=$(pwd)
if [ ! -z $1 ]; then
  MOODLE_DIR="$1"
  if [ ! -d $MOODLE_DIR ]; then
    echo "Moodle directorx $MOODLE_DIR does not exist"
    exit 1
  fi
fi

# The max interval (in seconds) when no alarm is triggered
INTERVAL_OK=600
if [ ! -z $2 ]; then
  INTERVAL_OK=$(printf '%d' "$2" 2>/dev/null)
  if [[ $INTERVAL_OK -lt 1 ]]; then
    echo "Interval must be seconds > 0"
    exit 1
  fi
fi

# Get the information when cron was executed.
lastrun=$(php ${MOODLE_DIR}/admin/cli/cfg.php --component=tool_task --name=lastcronstart)
if [[ $? -ne 0 ]]; then
  echo "Error fetching last run time."
  exit 1
fi

now=$(date +%s)
offset=$((now - lastrun))

if [[ $offset -gt $INTERVAL_OK ]]; then
    min=$(($offset / 60))
    sec=$(($offset - ($min * 60)))
    echo "Cron did not run for ${min} minutes and ${sec} seconds."
    exit 1
fi
