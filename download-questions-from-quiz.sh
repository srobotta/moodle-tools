#!/bin/bash

# Script to download questions from a quiz in the Moodle XML format.
# The questions are downloaded to one xml file named quiz_id.xml.
# The script requires a settings file with the following variables:
# USERNAME, PASSWORD of your Moodle user that you can login with.
# MOODLE the url (excl. protocol) of your Moodle installation.
# The settings must be provided as key=value pairs with no spaces.
# The settings file can be ~/.moodle-env or passed as second parameter.
#
# Usage: download-questions-from-quiz.sh <quiz_id> [<settings_file>]

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  head $0 -n 12 | grep  -v \#\! | sed 's|^# \?||g'
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
  echo 'Please enter the quiz id.'
  exit 1
fi
regex='^[1-9][0-9]*$'
if [[ ! $1 =~ $regex ]]; then
  echo 'Quiz id must be numeric.'
  exit 1
fi

# Create a new quiz.xml file and write opening tag.
echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<quiz>\n" > $1.xml

# Login
cookiefile=`basename $0`.cookie
curl -s -X POST -L -d "username=${USERNAME}&password=${PASSWORD}" -c $cookiefile \
  --url https://${MOODLE}/login/index.php > /dev/null

# Call the question tab in the quiz.
curl -s -b $cookiefile --url "https://${MOODLE}/mod/quiz/edit.php?cmid=$1" > quiz.$$
# From that file get the session id and the links to the questions.
sessid=$(cat quiz.$$ | sed -n 's/.*sesskey=\([[:alnum:]]\{1,20\}\).*/\1/p' | head -1)
for link in $(cat quiz.$$ | sed -n 's/.*\(https:.*editquestion\/question\.php?returnurl[^"]*\)".*/\1/p'); do
  # From the link extact the question id.
  qid=$(echo $link | sed -n 's/.*;id=\([0-9]\{1,10\}\).*/\1/p')
  # Call the export to xml and store the result.
  curl -s -b $cookiefile \
    --url "https://${MOODLE}/question/bank/exporttoxml/exportone.php?id=${qid}&sesskey=${sessid}&cmid=$1" > $qid.xml
  # From the question xml remove the xml header and the <quiz> tags and add the rest to the quiz.xml
  sed '1,2d;$ d' $qid.xml >> $1.xml
  rm $qid.xml
done
# Delete helper files.
rm $cookiefile
rm quiz.$$
# Check if there is content in the quiz.xml.
lines=$(wc -l $1.xml | cut -d ' ' -f 1)
if [ $lines -lt 4 ]; then
  echo 'No questions found, maybe the quiz id is wrong.'
  rm $1.xml
  exit 1
fi
# Write closing tag to the quiz.xml
echo -e "</quiz>\n" >> $1.xml