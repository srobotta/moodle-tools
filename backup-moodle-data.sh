#!/bin/bash
# Backup your data directory of your Moodle installation from inside a docker container.
#
# When you have a docker setup and the moodle data dir is inside of your
# docker container, you may backup and restore the moodle data directory
# with this script.
#
# Usage: backup-moodle-data.sh <backupdir>
#        backup-moodle-data.sh -r <backupdir>
# See --help for detailed information.

if [ -z $1 ]; then
  echo "Please provide a backup directory on your machine."
  exit 1
fi
cwd=$(pwd)

# Check for help:
if [ "$1" == '-h' ] || [ "$1" == '--help' ]; then
  cat $0 | while read l; do
    if [ "${l:0:1}" != '#' ]; then
      exit 0
    fi
    if [ "${l:0:2}" == '# ' ]; then
      echo ${l:2}
    else
      echo 
    fi
  done
  exit 0
fi

# Get container id for Moodle webserver.
container=$(docker ps | grep -E 'moodle.*?webserver' | cut -d' ' -f 1)
if [ "$container " == ' ' ]; then
  echo 'Moodle webserver container not found.'
  exit 1
fi

# Get the data root in the container as configured by Moodle.
# This assums that entering the container, we are right in the
# Moodles root directory.
dataroot=$(docker exec $container php -r 'define("CLI_SCRIPT", 1); include("config.php"); echo $CFG->dataroot;')

# Check whether we do want a restore.
if [ "$1 " == '-r ' ] || [ "$1 " == '--restore ' ]; then
  # Restore mode, $2 contains the directory with the backup, to be restored.
  if [ -z $2 ]; then
    echo "For restore a second parameter with the directory is required."
    exit 1
  fi
  backupdir=$2
  if [ ! -d $backupdir ]; then
    echo "Given backup directory does not exist."
    exit 1
  fi
  if [ -d $backupdir/filedir ] && [ -d $backupdir/trashdir ]; then
    docker cp -a $backupdir ${container}:${dataroot}/..
    if [ $? -ne 0 ]; then
      echo "Error copying data into container dataroot"
      exit 1
    fi
  else
    echo "Error: content of ${backupdir} does not seem to contain Moodle data."
    exit 1
  fi
  docker exec -it $container bash -c "chown -R www-data:www-data $dataroot"
  if [ $? -ne 0 ]; then
    echo "Error changing owner of dataroot"
    exit 1
  fi
  exit 0
fi

# Normal backup procedure.  
backupdir=$1

# Create the backup dir when it doesn't exist yet.
if [ ! -e $backupdir ]; then
  mkdir -p $backupdir
fi
# Create a new subdir (includes date time) for the current backup.
cd $backupdir
realdir=$(pwd)
subdir=$(date +%F-%H-%M)
mkdir $subdir

# Copy all data from the moodle dataroot from inside the container into that backup dir.
docker cp -a ${container}:${dataroot} $realdir/$subdir

# The following was copying file by file, which takes way longer.
#find . -type d -exec docker exec -it $container bash -c 'mkdir -p /var/www/moodledata/filedir/{}' \;
#find . -type f -exec docker cp {} ${container}:/var/www/moodledata/filedir/{} \;
#docker exec -it $container bash -c 'chown -R www-data:www-data /var/www/moodledata/filedir'

cd $cwd
