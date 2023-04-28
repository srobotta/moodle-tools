#!/bin/bash

### Introduction
#
# For the different MDLs that I am working on, I have a branch in my
# repo. Whenever upstream (the original Moodle repo where I did the fork
# from) is updated, I need to update my local branches.
#
### Prerequisites
#
# The command: git remote -v
# returns your repo locations. In my case I see:
# upstream	git://git.moodle.org/moodle.git (fetch)
# upstream	git://git.moodle.org/moodle.git (push)
#
# My branch names follow this convention:
# - a branch from the current master is trailed by master
# - a branch from the 4.0 stable branch is trailed by 400
# - a branch from the 3.11 stable branch is trailed by 311
# My branches follow this schema: MDL-XXXXX-[master|400|311]
# To setup upstream correctly in any branch that I use, the
# checkout is done like: git -b MDL-XXX-master upstream/master
# or if it is a release branch: git -b MDL-XXX-401 upstream/MOODLE_401_STABLE
# If upstream is something different, you may reassign a new source
# by checking out the branch and then do a:
# git branch --set-upstream-to upstream/master
#
### Script Usage
#
# Usage: update_branches.sh [-d <srcdir> ] [ -u <upstream> ]
#
# You may also predefine the environment variables
#   $MOODLE_DIR for the directory where your repo is checked out
#               (default is ~/workspace/moodle)
#   $MOODLE_UPSTREAM for the upstream reference (default is upstream)
#
# Variables can be passed like: export MOODLE_DIR=/path/to/your/moodle_repo
# before running this script.
### End Help <-- do not remove
s=''
for arg in "$@"; do
  if [ "$arg" == '--help' ]; then
    end=$(grep -nE '^### End Help' $0 | cut -d ':' -f 1)
    head $0 -n $(($end - 1)) | grep  -v \#\! | sed 's|^# \?||g'
    exit
  elif [ "$arg" == '-d' ] || [ "$arg" == '-u' ]; then
    s=$arg
  elif [ "$s" == '-d' ]; then
    repodir=$arg
    s=''
  elif [ "$s" == '-u' ]; then
    upstream=$arg
    s=''
  else
    echo "Invalid argument or missing switch"
    echo "Usage: $(basename $0) [-d <srcdir> ] [ -u <upstream> ]"
    exit 1
  fi
done

if [ -z $repodir ]; then
  if [ ! -z $MOODLE_DIR ]; then
    repodir=$MOODLE_DIR
  else
    repodir=~/workspace/moodle
  fi
fi
if [ ! -d $repodir ]; then
  echo "Could not determine location of Moodle code"
  exit 1
fi

if [ -z $upstream ]; then
  if [ ! -z $MOODLE_UPSTREAM ]; then
    upstream=$MOODLE_UPSTREAM
  else
    upstream=upstream
  fi
fi

echo "upstream: $upstream"
echo "repository directory: $repodir"
echo "start rebasing your branches"

CWD=$(pwd)
cd $repodir

git fetch $upstream
 
branches=$(git branch | tr -d \*)
for b in $branches; do
  suffix="${b##*-}"
  upbranch=''
  if [ "$suffix" == "master" ]; then
    upbranch=master
  elif [ "$suffix" == "400" ]; then
    upbranch=MOODLE_400_STABLE
  elif [ "$suffix" == "401" ]; then
    upbranch=MOODLE_401_STABLE
  elif [ "$suffix" == "402" ]; then
    upbranch=MOODLE_402_STABLE
  fi
  
  if [ "$upbranch " != ' ' ]; then
    git checkout $b
    if [ $? -ne 0 ]; then
      echo "Could not checkout branch $b"
      exit 1
    fi
    br_up=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
    if [ "$br_up" != "$upstream/$upbranch" ]; then
      echo "skip $b because remote location is not $upstream but $br_up"
      continue
    fi
    git rebase $upstream/$upbranch && git push origin $b -f
    if [ $? -ne 0 ]; then
      echo "error updating branch."
      exit 1
    fi
  fi
done

cd $CWD
