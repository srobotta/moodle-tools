#!/usr/bin/bash
# 
# Script to parse mbz files of course backups and prints
# basic course details to stdout.
#
# Usage: courseinfo.sh [ file.mbz | directory ]
#
# If the parameter is a backup file of mbz, this file is
# checked.
# If the parameter is a directory, it will be scaned for mbz
# files to parse. The directory hierarchy is not parsed
# recursively. If no directory is given, the current working
# directoy is used.

tmpdir="/tmp/courseinfo-$$"
scandir=$(pwd)

get_file_info () {
  mkdir -p $tmpdir
  tar -zxvf $1 -C $tmpdir course/course.xml > /dev/null 2&>1
  echo $(basename $1)
  echo "        id: $(xmllint --xpath 'string(/course/@id)' $tmpdir/course/course.xml)"
  echo " shortname: $(xmllint --xpath 'string(/course/shortname)' $tmpdir/course/course.xml)"
  echo "  fullname: $(xmllint --xpath 'string(/course/fullname)' $tmpdir/course/course.xml)"
  catname=$(xmllint --xpath 'string(/course/category/name)' $tmpdir/course/course.xml)
  catid=$(xmllint --xpath 'string(/course/category/@id)' $tmpdir/course/course.xml)
  echo "  category: \"$catname\" ($catid)"
  echo
  rm -r $tmpdir
}

if [ "$(which xmllint) " == ' ' ]; then
  echo "xmllint is required by this script"
  exit 1
fi

if [ "$1 " == '--help ' ]; then
  cat $0 | while read line; do
    if [[ ${line:0:1} != '#' ]]; then
      exit 0
    fi
    if [[ ${line:0:2} != '#!' ]]; then
      echo ${line:2}
    fi
  done
  exit 0
fi

# First argument is the directory to scan or the file to use.
if [ "$1 " != ' ' ]; then
  if [ -f $1 ]; then
    get_file_info $1
    exit $?
  fi
  if [ ${1:0:1} == '/' ]; then
    scandir=$1
  else
    scandir=$(realpath $(pwd)/$1)
  fi
fi

for f in $scandir/*.mbz ; do
  get_file_info $f
done
