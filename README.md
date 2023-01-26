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

## create_patch.sh

Helps me to create a patch when I am working on a ticket and I need to apply the same changes
to backport branches for releases that need these changes too. Based on the branch name,
the script looks up the last two commits, that should be the latest from the Moodle team
and the last one containing the changes to resolve the ticket. The diff is written into
a patch file that can be used with git apply.

## update_branches.sh

Runs over all existing branches and does a rebase to the latest upstream version (derived
from the branch name). This can be used to updates all branches once a weekly release is
published. If the rebase fails because of a merge conflict, the script stops and the
issue must be resolved manually. Running this on an up-to-date branch doesn't do any harm.