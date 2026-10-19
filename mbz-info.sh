#!/usr/bin/bash
# 
# Script to parse mbz files of course and activity backups and prints
# basic course details to stdout.
#
# Usage: mbz-info.sh [ file.mbz | directory ]
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
  echo $(basename $1)
  mkdir -p $tmpdir
  tar -zxvf $1 -C $tmpdir moodle_backup.xml > /dev/null 2&>1
  if [ ! -f $tmpdir/moodle_backup.xml ]; then
    echo "Error, maybe not a Moodle backup file."
    exit $?
  fi
  # Backup type, whether a full course or some activities
  backup_type=$(xmllint --xpath "string(//information/details/detail/type)" $tmpdir/moodle_backup.xml)
  if [ "$backup_type" == 'course' ]; then
    for t in id shortname fullname; do
      value=$(xmllint --xpath "string(//information/original_course_$t)" $tmpdir/moodle_backup.xml)
      printf "%-12s%s\n" "${t}:" "${value}"
    done
    tar -zxvf $1 -C $tmpdir course/course.xml > /dev/null 2&>1
    catname=$(xmllint --xpath 'string(/course/category/name)' $tmpdir/course/course.xml)
    catid=$(xmllint --xpath 'string(/course/category/@id)' $tmpdir/course/course.xml)
    echo "category:   \"$catname\" ($catid)"
  elif [ "$backup_type" == 'activity' ]; then
    xmllint --xpath "//activities/activity" $tmpdir/moodle_backup.xml | grep -E '<modulename>|<title>' | while read l
    do
      if [[ $l =~ '<modulename>' ]]; then
        mod=$(echo "$l" | sed -e 's/.*<modulename>//' -e 's|</modulename>.*||')
        echo "module: $mod"
      elif [[ $l =~ '<title>' ]]; then
        title=$(echo "$l" | sed -e 's/.*<title>//' -e 's|</title>.*||')
        echo "title:  $title"
      fi
    done
  else
    echo "Cannot handle backup type: ${backup_type}"
  fi
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
