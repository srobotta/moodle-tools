# moodle-tools

Everything inside here should help me in the Moodle development and make tidy tasks easier
to handle.

Each of these scripts has a --help switch. Use this or look into the source code to get
more specific information about any of these tools.

## brstatus.php

This script fetches Moodle tracker information based on the existing branches that are existing
in your working directory. It runs over all branches, from the branch name the affected ticket
number is derived and with this number information from the Moodle Tracker are fetched. The
result is a list with branch names and the corresponding ticket information.

## dbdump.sh

Assuming that you use the [Moodle-Docker](https://github.com/moodlehq/moodle-docker) setup to
develop for Moodle, this script makes a dump and a restore of the database. I find it useful
to dump the data before doing an upgrade or before installing a plugin, so that with the
restore process I can eassily switch back to an older version. Also for testing upgrade
processes of a plugin where data is changed, this lets you easily repeat the process during
the test phase in the development.

## create_patch.sh

Helps me to create a patch when I am working on a ticket and I need to apply the same changes
to backport branches for releases that need these changes too. Based on the branch name,
the script looks up the last two commits, that should be the latest from the Moodle team
and the last one containing the changes to resolve the ticket. The diff is written into
a patch file that can be used with git apply.

## download-questions-from-quiz.sh

Script that downloads the questions of a quiz in the Moodle XML format. The script needs
the credentials of your Moodle login and the Moodle domain. It then uses curl and other
shell tools to login to Moodle, call the quiz page, from there extract the question ids
and call the export xml on each question. The result is combined into a single xml file.

## export-qbank.sh

Exports all questions and the category hierachy from a question bank. It basically uses
the export function of Moodle to get the xml with the questions. The input parameter is
the question bank id. The script works very similar to the `download-questions-from-quiz.sh`.
The script was developed for the new questionbank feature from >4.6. It might work with
lower versions for Moodle as well.

## update_branches.sh

Runs over all existing branches and does a rebase to the latest upstream version (derived
from the branch name). This can be used to updates all branches once a weekly release is
published. If the rebase fails because of a merge conflict, the script stops and the
issue must be resolved manually. Running this on an up-to-date branch doesn't do any harm.

## Howtos

* [Behat Cheat Sheet](behat.md)
* [Teacher with 150 courses in Moodle](teacher-with-150-courses.md) 