# H5P in Moodle

## Import wordlist into dialog or flash cards

The [H5P dialog-cards](https://h5p.org/dialog-cards) are a good way of memorizing vocabulary
or similar content. However, when you have to create a list of dialogue cards in Moodle this
starts into a lot of clicking to add one entry at a time. An easier way is to have the word
list in a spreadsheet table and import it from there. This makes the handling a lot easier.
The script `import-cards.py` does this on the command line. Requirements are a installed
Python, an Open Office document and a H5P dialog-card or H5P flash-card file (you can
download an example from H5P.org). While dialog cards just allow text and easy flipping for
self controlled learning, flash cards allow the user to type in the answer. Also, images
are supported in flashcards (but not with this script).

Having a spreadsheet document with a list of answer/responses in two columns and the h5p
file, the creating of the dialog cards is done this way:

```
./import-cards.py dialog-cards-620.h5p Vocabulary.ods --title 'My beginners vocabulary'
```

The script takes arguments for the columns for the front and the back side of the dialog
card (default these are column A and B, columns letters can be provided with `--font X`
and `--back Y` to tell the script in which columns the data is located in). Also header
rows might be skipped with the argument `--row N` starting at line _N_ when the data is
preprended with headlines and column headers. A full list of arguments can be seen with
`--help`. The mandatory arguments are both files, first the H5P file, second the ODS file.

## Checking and updating the libraries

It happens that the libraries are out of date or missing on the file system.
This was the case at my dev enironment. Potentially you are trying to add a
new H5P type via the content bank but cannot store it because of a missing
file. With the help of AI I was able to fix the problem and at my
installion the H5P types do work again.

### Check for the integrity

The script `check_missing_h5p_libraries.php` checks for existence of files
according to what is in the database. It does not modify anything.

* Resolves filedir exactly the way Moodle does - `$CFG->filedir` if set,
  otherwise `$CFG->dataroot.'/filedir'`
* Queries __mdl_files__ for `component = 'core_h5p'`, filearea libraries (by
  default), skipping directory placeholders (filename = '.') and zero-byte
  row that have no byte-file.
* For each row, rebuilds the xx/yy/<hash> path and checks `is_readable()`.
  The ones that aren't are printed with context, itemid (= libraryId),
  filepath/filename and hash.
* Prints a summary grouped by filearea and by storage item, so you can
  immediately see whether it's one library or the whole deployment that lost
  its files.
* Exits 2 if anything is missing, 0 if clean - handy for scripting.

In my case the oupput was very lengthly with a lot of files reported
missing. The summary looked like

```
== Summary ==
Files checked : 5816
Files missing : 986
Unique hashes : 890

Missing by filearea:
  libraries      986
```

### Reinstall libaries

If the above script returns a lot of files missing as it did in my case the
initial attempt was to run the scheduled task to reinstall the files:

```
php public/admin/cli/scheduled_task.php -e='\core\task\h5p_get_content_types_task'
php admin/cli/purge_cache.php
```

The problem, no files had been installed, because in the database they where
still existent while on the file system they where missing. Therefore, I
needed another script that also clears the db of the missing files so that a
newly run would download and install the libraries again.

This is what the script `reset_h5p_libraries.php` should do:

1. Uninstall all H5P libraries via `\core_h5p\api::delete_library` - it clears
   the DB rows, dependencies, cached assets, caches, and the (already-missing)
   file records. Per its docblock (api.php:38-40) it keeps the .h5p source files
   of deployed content, so that content redeploys itself next time it's viewed.
1. Re-run h5p_get_content_types_task — now getLibraryId() returns nothing, so the
   hub re-downloads and re-deploys every content type, rewriting filedir.

The reinstalling of the library consists of these steps:

```
# 1. See what would be removed (no changes):
php reset_h5p_libraries.php

# 2. Actually uninstall the stale library records:
php reset_h5p_libraries.php --run

# 3. Re-download + re-deploy every content type from the hub (now not skipped):
php public/admin/cli/scheduled_task.php -e='\core\task\h5p_get_content_types_task'

# 4. Purge caches (the h5p_library_files / h5p_libraries MUC caches hold stale data):
php public/admin/cli/purge_caches.php
```

Now running a check with the script from above should return the following
(with similar numbers):

```
php check_missing_h5p_library_files.php 
== Checking core_h5p content files against /var/www/moodledata/filedir ==

== Summary ==
Files checked : 4778
Files missing : 0
Unique hashes : 0
```

### Notes and caveats
* ***Content types vs. all libraries***: the hub task only re-fetches the standard
  content types offered by the H5P Hub. Any library you'd previously installed only
  via a manual .h5p upload (not in the hub catalogue) won't be re-fetched by the task
  - but delete_library keeps the .h5p source files, so those redeploy automatically
  the next time that content is opened in the player/editor.
* ***Existing H5P content stays intact***: delete_library removes only the h5p deployment
  rows, not the content-bank items or their stored .h5p files. Content redeploys on next view.

On a production system missing library files should not occure at any time.  This is rather an
issue with docker containers that have been redeployed but the data volume is out of sync.
