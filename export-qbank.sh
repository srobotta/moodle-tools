#!/bin/bash

# Script to export all questions from a question bank in the Moodle XML format.
# On the export page the top category of that question bank is selected and all
# questions are downloaded to one xml file named qbank_id.xml.
# The script requires a settings file with the following variables:
# USERNAME, PASSWORD of your Moodle user that you can login with.
# MOODLE the url (excl. protocol) of your Moodle installation.
# The settings must be provided as key=value pairs with no spaces.
# The settings file can be ~/.moodle-env or passed as second parameter.
# The file should not contain any other code than the variable assignments.
#
# Usage: export-qbank.sh <qbank_id> [<settings_file>]

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  head $0 -n 13 | grep  -v \#\! | sed 's|^# \?||g'
  exit 0
fi

# Check if the settings file is provided or use the default.
if [ -z $2 ]; then
  settings=~/.moodle-env
else
  settings=$2
fi
if [ ! -f $settings ]; then
  echo 'Settings file not found. Must be ~/.moodle-env or set as second parameter.'
  exit 1
fi
# Load the settings file and check if the required variables are set.
source $settings
if [ -z $USERNAME ] || [ -z $PASSWORD ] || [ -z $MOODLE ]; then
  echo 'Settings file must contain the variables USERNAME, PASSWORD and MOODLE.'
  exit 1
fi

# Check if the quiz id is provided and numeric.
if [ -z $1 ]; then
  echo 'Please enter the question bank id.'
  exit 1
fi
regex='^[1-9][0-9]*$'
if [[ ! $1 =~ $regex ]]; then
  echo 'Question bank id must be numeric.'
  exit 1
fi

# Login
cookiefile=`basename $0`.cookie
curl -s -L -X POST -d "username=${USERNAME}&password=${PASSWORD}" -c $cookiefile \
  --url https://${MOODLE}/login/index.php > /dev/null

# Call the question bank export page
curl -s -b $cookiefile --url "https://${MOODLE}/question/bank/exportquestions/export.php?cmid=$1" > qbank.$$
# From that file get the session id and the link to the top question category.
sessid=$(cat qbank.$$ | sed -n 's/.*sesskey=\([[:alnum:]]\{1,20\}\).*/\1/p' | head -1)
catids=$(cat qbank.$$ | \
  sed -n 's/.*<option value="\([[:digit:]]\{1,10\},[[:digit:]]\{1,10\}\)".*/\1\n/p' | \
  head -1 | \
  sed 's/,/%2C/g')

# Send the form with the appropriate data to export the questions and get the xml.
curl -s -b $cookiefile \
  -X POST \
  -d "cmid=$1&cat=$catids&qpage=0&sesskey=$sessid&_qf__qbank_exportquestions_form_export_form=1&format=xml&category=$catids&cattofile=1&contexttofile=1&submitbutton=Export+questions" \
  --url "https://${MOODLE}/question/bank/exportquestions/export.php" > qbank.$$

# Find the XML in the response and download it.
link=$(cat qbank.$$ | sed -n 's/.*href="\([^"]*\)".*/\1/p' | grep question/export)
curl -s -b $cookiefile --url $link > $1.xml

# Delete helper files.
rm $cookiefile
rm qbank.$$

# Check if there is content in the quiz.xml.
firstline=$(head -1 $1.xml | grep '<?xml')
if [[ "$firstline " == " " ]]; then
  echo 'No questions found, maybe the question bank id is wrong.'
  rm $1.xml
  exit 1
fi