#!/bin/bash

# For the different MDLs that I am working on, I have a branch in my
# repo. Whenever upstream (the original Moodle repo where I did the fork
# from) is updated, I need to update my local branches.
# git remote -v returns your repo locations. In my case I see:
# upstream	git://git.moodle.org/moodle.git (fetch)
# upstream	git://git.moodle.org/moodle.git (push)
#
# My branch names follow this convention:
# - a branch from the current master is trailed by master
# - a branch from the 4.0 stable branch is trailed by 400
# - a branch from the 3.11 stable branch is trailed by 311
# My branches follow this schema: MDL-XXXXX-[master|400|311]
# The variable MOODLE_DIR can be defined as a variable or
# passed as an argument and should contain the location to
# your checked out Moodle git repo.

if [ ! -z $1 ]; then
  repodir=$1
elif [ ! -z $MOODLE_DIR ]; then
  repodir=$MOODLE_DIR
else
  repodir=~/workspace/moodle
fi

if [ ! -d $repodir ]; then
  echo "Could not determine location of Moodle code"
  exit 1
fi

CWD=$(pwd)
cd $repodir

git fetch upstream
 
branches=$(git branch | tr -d \*)
for b in $branches; do
  suffix="${b##*-}"
  upbranch=''
  if [ "$suffix" == "master" ]; then
    upbranch=master
  elif [ "$suffix" == "400" ]; then
    upbranch=MOODLE_400_STABLE
  elif [ "$suffix" == "311" ]; then
    upbranch=MOODLE_311_STABLE
  fi
  
  if [ "$upbranch " != ' ' ]; then
    git checkout $b
    git rebase upstream/$upbranch
    git push origin $b -f    
  fi
done

cd $CWD
