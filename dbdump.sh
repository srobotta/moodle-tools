#!/bin/bash

# Create or restores a database dump of the moodle db or a single table
# only. The script is designed to work with the standard moodle docker
# installation and the postgres database.
#
# Usage: dbdump.sh [-d <dump_dir>] | [-r <dump_file>]
#                  [-c <moodle_yaml>] [ -t <table> ]
#
# Arguments:
# -c yaml file in the moodle docker setup that contains the database
#    credentials. When not given, ~/workspace/moodle-docker/base.yml
#    is used.
# -d dump dir where the dumps are written to, when not given the
#    current working directory is used.
# -r switch to restore mode, the given argument is the dump file
#    that is supposed to be restored.
# -t table name or pattern to dump this/these table(s) only.
#
### End Help <-- do not remove

MOODLE_YAML=~/workspace/moodle-docker/base.yml
DUMP_DIR=''
RESTORE_MODE=0
RESTORE_FILE=''
TABLE_NAME=''

# Parse the arguments.
s=''
for arg in "$@"; do
  if [ "$arg" == '--help' ]; then
    end=$(grep -nE '^### End Help' $0 | cut -d ':' -f 1)
    head $0 -n $(($end - 1)) | grep  -v \#\! | sed 's|^# \?||g'
    exit
  elif [ "$arg" == '-c' ] || [ "$arg" == '-d' ] || [ "$arg" == '-t' ]; then
    s=$arg
  elif [ "$arg" == '-r' ]; then
    RESTORE_MODE=1
    s=$arg
  elif [ "$s" == '-c' ]; then
    MOODLE_YAML=$arg
    s=''
  elif [ "$s" == '-d' ]; then
    DUMP_DIR=$arg
    s=''
  elif [ "$s" == '-r' ]; then
    RESTORE_FILE=$arg
    s=''
  elif [ "$s" == '-t' ]; then
    TABLE_NAME=$arg
    s=''
  else
    echo -e "Invalid argument or missing switch\nSee --help for more details."
    exit 1
  fi
done

# Check if the moodle docker directory and inside the base.yml exists.
if [ ! -f ${MOODLE_YAML} ]; then
  echo "Moodle docker yml file $MOODLE_YAML not found."
  exit 1
fi
if [ ! -d ${DUMP_DIR} ]; then
  mkdir -p ${DUMP_DIR}
fi

# In the yaml file, get the dbname and dbuser.
dbname=`cat ${MOODLE_YAML} | grep DBNAME`
dbname=`echo ${dbname#*:} | xargs`
dbuser=`cat ${MOODLE_YAML} | grep DBUSER`
dbuser=`echo ${dbuser#*:} | xargs`

# Get the container id of the running db container.
dbcontainer=`docker ps | grep -E '[a-zA-Z0-9\-]+db' | awk '{print $1}'`
if [ "$dbcontainer " == " " ]; then
  echo "No db container found."
  exit 1
fi
if [[ $dbcontainer =~ [[:space:]] ]]; then
  echo -e "Too many matches for db container found:\n$dbcontainer"
  exit 1
fi

# If restore mode is set, restore the database from the given dump file (in $DUMP_DIR).
if [ $RESTORE_MODE -eq 1 ]; then
  if [ ! -f $RESTORE_FILE ]; then
    echo "No dump file found: $RESTORE_FILE"
    exit 1
  fi
  zcat $RESTORE_FILE | docker exec -i $dbcontainer /usr/bin/psql -U ${dbuser} -d ${dbname}
  exit 0
fi
# Here we are in backup mode.

# If dump directory is not set, use the current directory.
if [ "$DUMP_DIR" == '' ]; then
  DUMP_DIR=.
fi
# Dump the database to the given directory.
if [ "$TABLE_NAME" != '' ]; then
  tablearg="-t $TABLE_NAME"
  # The table name as prefix, in case a pattern is used strip all special characters.
  prefix=${dbname}-`echo ${TABLE_NAME} | tr -dc '[:alnum:]_-'`
else
  tablearg=''
  prefix=$dbname
fi
suffix=`date +%Y-%m-%d-%H-%M`.sql.gz
docker exec -i $dbcontainer /usr/bin/pg_dump -U ${dbuser} -d ${dbname} ${tablearg} -c | \
  gzip > $DUMP_DIR/${prefix}-${suffix} 2>&1
# Check for reasonable file size and report error when to small.
fsize=$(stat --printf="%s" $DUMP_DIR/${prefix}-${suffix})
if [ $fsize -lt 1200 ]; then
  echo "File too small, dump failed."
  rm $DUMP_DIR/${prefix}-${suffix}
  exit 1
fi