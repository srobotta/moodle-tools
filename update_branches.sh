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
# - a branch from the current main is trailed by main
# - a branch from the 4.5 stable branch is trailed by 405
# - a branch from the 5.0 stable branch is trailed by 500
# My branches follow this schema: MDL-XXXXX-[main|405|500]
# To setup upstream correctly in any branch that I use, the
# checkout is done like: git -b MDL-XXX-main upstream/main
# or if it is a release branch: git -b MDL-XXX-405 upstream/MOODLE_405_STABLE
# If upstream is something different, you may reassign a new source
# by checking out the branch and then do a:
# git branch --set-upstream-to upstream/main
#
### Script Usage
#
# Usage: update_branches.sh [-d <srcdir> ] [ -e <exclude_branch> ] [ -n ] [ -u <upstream> ]
#
#   -d <srcdir> directory with the moodle code.
#   -e <exclude_branch> may contain several branches separated by ",". It's also
#      possible to just pass an mdl number to exclude all branches that have
#      this number in the branch name.
#   -n dry run, just show which branches would be handled without doing any changes.
#   -u <upstream> name of the upstream git repo.
#
# You may also predefine the environment variables
#   $MOODLE_DIR for the directory where your repo is checked out
#               (default is ~/workspace/moodle)
#   $MOODLE_UPSTREAM for the upstream reference (default is upstream)
#   $MOODLE_EXCLUDE for branches to exclude
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
  elif [ "$arg" == '-e' ]; then
    s=$arg
  elif [ "$arg" == '-n' ]; then
    dryrun=1
  elif [ "$s" == '-d' ]; then
    repodir=$arg
    s=''
  elif [ "$s" == '-u' ]; then
    upstream=$arg
    s=''
  elif [ "$s" == '-e' ]; then
    exclude=$arg
    s=''
  else
    echo "Invalid argument or missing switch"
    echo "Usage: $(basename $0) [-d <srcdir> ] [ -e <exclude_branch> ] [ -n ] [ -u <upstream> ]"
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

if [ -z $exclude ]; then
  if [ ! -z $MOODLE_EXCLUDE ]; then
    exclude=$MOODLE_EXCLUDE
  fi
fi

echo "upstream: $upstream"
echo "repository directory: $repodir"
echo "exclude branches: $exclude"
echo "start rebasing your branches"

CWD=$(pwd)
cd $repodir

git fetch $upstream

branches=$(git branch | tr -d \*)
for b in $branches; do
  if [ ! -z $exclude ]; then
    excl=$(echo $exclude | tr "," "\n")
    for exclbr in $excl; do
      if [[ "$b" =~ "$exclbr" ]]; then
        echo "Exclude branch $b"
        continue 2
      fi
    done
  fi

  suffix="${b##*-}"
  upbranch=''
  if [ "$suffix" == "master" ] || [ "$suffix" == "main" ]; then
    upbranch=main
  elif [ "$(echo $suffix | grep -E '^[[:digit:]]+$')" != "" ]; then
    upbranch=MOODLE_${suffix}_STABLE
  fi

  if [ ! -z $dryrun ]; then
    echo "Dry run: $b"
    continue
  fi

  if [ "$upbranch " != ' ' ]; then
    git checkout $b
    if [ $? -ne 0 ]; then
      echo "Could not checkout branch $b"
      exit 1
    fi
    br_up=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
    if [ "$br_up" == 'upstream/master' ] || [ "$br_up " == ' ' ]; then
      br_up='upstream/main'
    fi
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
