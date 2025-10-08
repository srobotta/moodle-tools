#!/bin/bash

# Use case:
# You have your moodle code for dev environment some where at e.g.
# ~/workspace/moodle
# and an additional plugin that you work on, checked out at:
# ~/workspace/moodle-frankenstylepluginname
# and you must synchronize the separate plugin under git control
# with the install dir of the plugin in your Moodle installation.
# In the past, I used two separate scripts inside each checked
# out plugin dir, this script and it's couterpart should combine
# the work instead of having two script in each plugin.
#
# Usage:
# Change to the directory where your plugin is installed and where
# you handle all git related commands. From here you want to
# synchronize your moodle dev environment with the latest version
# of the plugin:
# rsync-moodle.sh
# Optional arguments
# -m <dir> target directory of your moodle src dir.
# -n test only, without actually copying the files.
# -p <dir> plugin dir where the code is pushed to.
# -r reverse: copy the code from the moodle dir into the
#    plugin dir.
#
# Configuration:
# use the environment variables:
# MOODLE_SRC_DIR = Directory where your moodle installation is
#                  located at. Use of -m overrides this.
#
# In my ~/bin directory I created two files that call this script.
# There is rsync_moodle.sh with the conten:
# ~/workspace/moodle-tools/rsync-moodle.sh $@
# and moodle_rsync.sh with the content:
# ~/workspace/moodle-tools/rsync-moodle.sh -r $@
### End Help

TEST_ONLY=0
REVERSE=0

# Examining the plugin type
parse_name() {
  # Assuming we are in the plugin directory
  local franken=$(basename $(pwd))
  # Remove prefix up to the first dash
  local part1="${franken#*-}"

  # Split by underscore
  type="${part1%%_*}"
  name="${part1#*_}"
  
  # Tiny has a different location:
  if [ "$type" == "tiny" ]; then
    type="lib/editor/tiny/plugins"
  elif [ "$type" == "qbank" ]; then
    type="question/bank"
  elif [ "$type" == "qtype" ]; then
    type="question/type"
  fi
}
# Check for directory arguments and set them for the rsync command
eval_arg_dir() {
  if [ "$PLUGIN_DIR " != " " ]; then
    argdir=$PLUGIN_DIR
  elif [ "$MOODLE_SRC_DIR " != " " ]; then
    argdir=$MOODLE_SRC_DIR
    # Moodle 5.1 has a new public dir
    if [ -d "$MOODLE_SRC_DIR/public" ]; then
      argdir+=/public
    fi
    argdir+=/$type/$name    
  else 
    echo "Missing $1 directory for Moodle or plugin, use -m or -p."
    exit 3
  fi
}

# Check if we are actually in a plugin directory.
line=$(grep component version.php 2>/dev/null)
parse_name
if [[ ! $line == *"_${name}"* ]]; then
  echo "The current dirctory does not seem to contain a Moodle plugin."
  exit 1
fi 

# Evaluate the command line switches.
for arg in "$@"; do
  if [ "$arg" == '--help' ]; then
    end=$(grep -nE '^### End Help' $0 | cut -d ':' -f 1)
    head $0 -n $(($end - 1)) | grep  -v \#\! | sed 's|^# \?||g'
    exit
  elif [ "$arg" == '-n' ]; then
    TEST_ONLY=1
    s=''
  elif [ "$arg" == '-r' ]; then
    REVERSE=1
    s=''
  elif [ "$arg" == '-m' ]  || [ "$arg" == '-p' ]; then
    s=$arg
  elif [ "$s" == '-m' ]; then
    MOODLE_SRC_DIR=$arg
    s=''
  elif [ "$s" == '-p' ]; then
    PLUGIN_DIR=$arg
  else
    echo -e "Invalid argument or missing switch\nSee --help for more details."
    exit 2
  fi
done

# When copying from the plugin into Moodle
if [ $REVERSE -eq 0 ]; then
  eval_arg_dir "destination"
  SRC=`pwd`
  DEST=$argdir
  
  if [ ! -d $DEST ] && [ $TEST_ONLY -ne 1 ]; then
    mkdir -p $DEST
    if [ $? -ne 0 ]; then
      echo "Destination dir does not exist and count not be created: $DEST"
      exit 4
    fi
  fi
else # Copy from moodle into this plugin dir
  eval_arg_dir "source"
  SRC=$argdir
  DEST=`pwd`
  
  if [ ! -d $SRC ]; then
    echo "Missing source directory $SRC use -m or -p"
    exit 5
  fi
fi

# Finally use rsync to copy the changed files.
rsync="rsync -av"
if [ $TEST_ONLY -eq 1 ]; then
  rsync+="n"
fi

# Not the .git files but the .github should be included.
$rsync --exclude=".git/" $SRC $DEST
