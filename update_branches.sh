#!/bin/bash

# For the different MDLs that I am working on, I have a branch in my
# repo. Whenever upstream (the original Moodle repo where I did the fork)
# is updated, I need to update my local branches.
# My branch names follow this convention:
# - a branch from the current master is trailed by master
# - a branch from the 4.0 stable branch is trailed by 400
# - a branch from the 3.11 stable branch is trailed by 311
# My branches follow this schema: MDL-XXXXX-[master|400|311]

MOODLE_DIR=~/workspace/moodle

CWD=$(pwd)
cd $MOODLE_DIR

git fetch upstream
 
branches=$(git branch | tr -d \*)
for b in $branches; do
  suffix="${b##*-}"
  git checkout $b
  echo $b and $suffix
  if [ "$suffix" == "master" ]; then
    git rebase upstream/master
    git push origin $b -f
  elif [ "$suffix" == "400" ]; then
    git rebase upstream/MOODLE_400_STABLE
    git push origin $b -f
  elif [ "$suffix" == "311" ]; then
    git rebase upstream/MOODLE_311_STABLE
    git push origin $b -f
  fi
done

cd $CWD
