#!/bin/bash

# When working on a ticket and there are changes committed, backporting to
# stable releases may has to be done. Therefore this script is creating a
# patch file, that can be used to create a commit in a branch from one of
# these backports.
# The script makes use of git commands to figure out the current changes
# from the latest commit to the previous commit.
#
# Usage: create_patch.sh [-d <target_dir>] [-r repodir] [-s]
#
# Arguments:
# -d directory where to write the patch file. Default is the current dir.
# -r directory where the repository resides in.
# -s write diff to standard out without creating a patch file.
#
# You may also predefine the environment variables
#   $MOODLE_DIR for the directory where your repo is checked out.
#   $MOODLE_PATCH_DIR for the directory where to write the patches.
#
# Variables can be passed like: export MOODLE_DIR=/path/to/your/moodle_repo
# before running this script.

s=''
for arg in "$@"; do
  if [ "$arg" == '--help' ]; then
    head $0 -n 22 | grep  -v \#\! | sed 's|^# \?||g'
    exit
  elif [ "$arg" == '-s' ]; then
    stdout=1
    s=''
  elif [ "$arg" == '-d' ] || [ "$arg" == '-r' ]; then
    s=$arg
  elif [ "$s" == '-d' ]; then
    outdir=$arg
    s=''
  elif [ "$s" == '-r' ]; then
    repodir=$arg
  else
    echo -e "Invalid argument or missing switch\nSee --help for more details."
    exit 1
  fi
done


if [ -z $repodir ]; then
  if [ ! -z $MOODLE_DIR ]; then
    repodir=$MOODLE_DIR
  else
    repodir="."
  fi
fi

CWD=$(pwd)

if [ -z $outdir ]; then
  if [ ! -z $MOODLE_PATCH_DIR ]; then
    outdir=$MOODLE_PATCH_DIR
  else
    outdir=$CWD
  fi
fi

cd $repodir
if [ $? -ne 0 ]; then
  exit 1
fi

rev=($(git log -n 2 | grep 'commit' | cut -d " " -f 2))
if [ "$rev" == '' ]; then
  exit 2
fi
a=${rev[0]}
b=${rev[1]}

if [ ! -z $stdout ]; then
  git diff $b $a
  cd $CWD
  exit 0
fi

mdl=$(git status | head -n 1 | grep -o '[0-9]*')
git diff $b $a > "${outdir}/mdl-${mdl}.patch"

cd $CWD

