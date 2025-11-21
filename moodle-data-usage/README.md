# Check usage of unused files in the moodle data dir

## Data from the database

In case you run postgres, you might export the relevant data from the `files` table
into a CSV file like this:

```
COPY (select contenthash, filepath, filename, filesize FROM files)
TO '/tmp/filelist.csv' (FORMAT csv, DELIMITER ';');
```

If you are using MariaDB, the file can be generated like this:

```
select contenthash, filepath, filename, filesize FROM files
INTO OUTFILE '/tmp/filelist.csv' FIELDS TERMINATED BY ';';
```

Usually, the database user differs from the login user, hence cannot write in the home
directory of the login user. Therefore, I tell to use the system temp dir to create the
file.

## Data from the filesystem

The Moodle data directory is defined in `$CFG->dataroot`. This directory must be appended
by `filedir` to actually have the location where the corresponding files are stored.

```
find /var/data/moodle.example.org/moodle-data/filedir/ -type f -print > dirlist.txt
```

This file list contains the complete directory as you searched with `find`. To have a
better handling and also to shrink the file size of the listing we need to remove the
prefix file path (basically the content of `$CFG->dataroot`) to keep the relative path only
which is also used in the database.

Depending on your path, the replace command looks a bit different. In my case the path
also contains the domain name of the moodle installation.

```
sed -i 's|^/var/data/moodle\.example\.org/moodle\-data/filedir/||' dirlist.txt
```

Sed uses regular expressions, therefore I used the pipe as a delimiter so not to have to
escape the path delimiters. I still need to escape other special chars such as `.`
or `-` that are used in the path name.

This shrinks the file to nearly half of the size, in my case.

## Compare data from database and file system

Before doing any checks, I copy the files onto my machine and run everything locally.
The php script ([compare.php](compare.php)) reads both files and compares the data. The
script only lists files with missmatches. There is no immediate action to delete a file or
an entry in the database (also because from the local machine you do not have direct access
to the moodle installation).

Files that are not existend in the database but on the file system only are easy to be
deleted. Entries in the DB without a corresponding file cannot be deleted easily. Because
each existing entry in the database usually has a reference where it belongs to. That
reference must be deleted as well in order to have correct data in the database. Otherwise,
data leaks will occur in the database, having the entry in the `file` table deleted but somwhere
else a reference to that deleted entry may still exist.

Details on deletion in the Database will follow.

### Result

When you have named the files from the database data and file system data, and placed them
in this folder, you just can run the `compare.php` that writes the results to standard out.
I redirect it into a file:

```
php compare.php -d filelist.csv -f dirlist.txt > result.txt
```

Also note, that the `ini_set` at the begining of the script might need to be increased.
Remember, the script does all the compare on my local machine, so there is no harm on
the productive systems.

The output, in my case it's in the `results.txt`, contains to sections with a list of
files:

```
Files in DB but not in moodle-data
a4/db/a4db0643c3914c3801bbfd15bdade931e41c842d -: backup-moodle2-course-1234-bba2210_5-20-20200227-1356-nu.mbz
8a/75/8a7531318475f74a80d23b639aa2b3987ba41041 -: f1.jpg
...

Files in moodle-data but not in DB
e4/23/e423c3e1c4e22ae7dc91dfbb2717434207ae6e80
e4/4e/e44e1faf14dce30fa3f3d2a8ee1ec9dfeb1bdf92

```

The first section are entries in the database that apparently have no file anymore in the
moodle data directory. Check with a simple
`ls <moodle_data>/a4/db/a4db0643c3914c3801bbfd15bdade931e41c842d` and see whether the file is
listed or not.

Because of the listed name, we may also guess what kind of file is missing. In the example
this is an image `f1.jpg` and a moodle course (activity) backup file (because of the name we
also know the course id and the daten when this apparently was created).

In the second section we have a file but do not have a corresponding entry in the database
that references this file. We even don't now what kind of file this is. In Linux the
cli tool `file` may give some more information before actually looking into the file
content with an editor.