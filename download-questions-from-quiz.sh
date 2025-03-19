#!/bin/bash

# Script to download questions from a quiz in the Moodle XML format.
# The questions are downloaded to one xml file named quiz_id.xml.
# The script requires a settings file with the following variables:
# USERNAME, PASSWORD of your Moodle user that you can login with.
# MOODLE the url (excl. protocol) of your Moodle installation.
# The settings must be provided as key=value pairs with no spaces.
# The settings file can be ~/.moodle-env or passed as second parameter.
#
# Usage: download-questions-from-quiz.sh <quiz_id> [-l] [<settings_file>]
#
# Params:
#  -l list question ids, do not download any xml.
### End Help

settings=~/.moodle-env
listqid=0
quizid=$1

for arg in "$@"; do
  if [ "$arg" == '--help' ]; then
    end=$(grep -nE '^### End Help' $0 | cut -d ':' -f 1)
    head $0 -n $(($end - 1)) | grep  -v \#\! | sed 's|^# \?||g'
    exit
  elif [ "$arg" == '-l' ]; then
    listqid=1
    continue
  elif [ "$arg" == "$quizid" ]; then
    continue
  elif [ ! -f "$arg" ]; then
    echo "Given settings $arg file not found."
    exit 1
  else
    settings=$arg
  fi
done

# Load the settings file and check if the required variables are set.
if [ ! -f "$settings" ]; then
  echo 'Settings file not found. Must be ~/.moodle-env or set as second parameter.'
  exit 1
fi
source $settings
if [ -z $USERNAME ] || [ -z $PASSWORD ] || [ -z $MOODLE ]; then
  echo 'Settings file must contain the variables USERNAME, PASSWORD and MOODLE.'
  exit 1
fi

# Check if the quiz id is provided and numeric.
if [ -z $quizid ]; then
  echo 'Please enter the quiz id.'
  exit 1
fi
regex='^[1-9][0-9]*$'
if [[ ! $quizid =~ $regex ]]; then
  echo 'Quiz id must be numeric.'
  exit 1
fi

# Create a new quiz.xml file and write opening tag.
echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<quiz>\n" > $quizid.xml

# Login
cookiefile=`basename $0`.cookie
curl -s -X POST -L -d "username=${USERNAME}&password=${PASSWORD}" -c $cookiefile \
  --url https://${MOODLE}/login/index.php > /dev/null

# Call the question tab in the quiz.
curl -s -b $cookiefile --url "https://${MOODLE}/mod/quiz/edit.php?cmid=$quizid" > quiz.$$
# From that file get the session id and the links to the questions.
sessid=$(cat quiz.$$ | sed -n 's/.*sesskey=\([[:alnum:]]\{1,20\}\).*/\1/p' | head -1)
for link in $(cat quiz.$$ | sed -n 's/.*\(https:.*editquestion\/question\.php?returnurl[^"]*\)".*/\1/p'); do
  # From the link extact the question id.
  qid=$(echo $link | sed -n 's/.*;id=\([0-9]\{1,10\}\).*/\1/p')
  # If we list the question id only, then do not download the question xml.
  if [ $listqid -eq 1 ]; then
    echo $qid
  else
    # Call the export to xml for the question and store the result.
    curl -s -b $cookiefile \
      --url "https://${MOODLE}/question/bank/exporttoxml/exportone.php?id=${qid}&sesskey=${sessid}&cmid=$quizid" > $qid.xml
    # From the question xml remove the xml header and the <quiz> tags and add the rest to the quiz.xml
    sed '1,2d;$ d' $qid.xml >> $quizid.xml
    rm $qid.xml
  fi
done
# Delete helper files.
rm $cookiefile
rm quiz.$$
# When we list the question ids, then also delete the started
# $quizid.xml file and exit here
if [ $listqid -eq 1 ]; then
  rm $quizid.xml
  exit 0
fi
# Check if there is content in the quiz.xml.
lines=$(wc -l < "$quizid.xml")
if [[ "$lines" -lt 4 ]]; then
  echo 'No questions found, maybe the quiz id is wrong.'
  rm $quizid.xml
  exit 1
fi
# Write closing tag to the quiz.xml
echo -e "</quiz>\n" >> $quizid.xml
