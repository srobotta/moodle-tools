## Backup Purge

We have the problem, that we are archiving courses to free space on the
Moodle data directory. We are using the
[lifecycle plugin](https://github.com/learnweb/moodle-tool_lifecycle)
to backup and then delete the courses from our prod machine.

### Examine backup files in recycle bin

Aparently during the backup step, many course backups are created. These
can be found in the `files` table. Also, `backup.mbz` files are generated
during that step.

The thread
[Deleting large courses didn't free up disk space](https://moodle.org/mod/forum/discuss.php?d=432409)
in the Moodle form, especially a
[reply from Ken Tak](https://moodle.org/mod/forum/discuss.php?d=432409#p1740658)
explains how to get more information on the files.

To start with the investigation as described in the post, a list
of backup files can be selected. In this case a certain user id (1234)
is used (apparently from the user that created and/or runs the lifecycle
jobs) and only files newer than 1774396800 e.g. 2026-03-25 00:00:00 are
searched:

```
sudo -u postgres psql -d moodle -c "\copy (
  select id,userid,contenthash,filename,filearea,filesize,timemodified
  from files
  where filename like '%.mbz'
    and userid = 1234
    and timecreated > 1774396800
  order by timemodified DESC) to '/tmp/files.txt' with csv delimiter ';' header"
```

The resulted csv file can be fetched from the database server to the webserver
for the next steps:

```
scp moodle-db:/tmp/files.txt .
scp files.txt moodle-web:.
``` 

On the webserver we check if these the files exist and if these are really
backup files:

```
cat files.txt | cut -d\; -f 3 | while read l ; do echo $l ; file -b /mnt/moodle-data/filedir/${l:0:2}/${l:2:2}/$l; done
```

the output is something like:

```
gzip compressed data, from Unix, original size modulo 2^32 1931776
gzip compressed data, from Unix, original size modulo 2^32 2632704
gzip compressed data, from Unix, original size modulo 2^32 18037248
gzip compressed data, from Unix, original size modulo 2^32 3509248
gzip compressed data, from Unix, original size modulo 2^32 41984
gzip compressed data, from Unix, original size modulo 2^32 41984
gzip compressed data, from Unix, original size modulo 2^32 157458944 gzip compressed data, reserved method, from FAT filesystem (MS-DOS, OS/2, NT), original size modulo 2^32 157458944
```

On the server where we have course backups stored that were created
using the lifecycle plugin, we need to see if any of those files
exist there as well.

The larger output on the last entry indicates that the file contains
two gzip archived concatenated, with the latter created on a windows
machine (although I have no idea where this comes from, when the backup
is created on a linux server). It might be that the course was
restored by uploading a mbz file which is still in the course space
in the restore area.

To continue, we copy the `files.txt` from the database to the backup storage
server where all the backups are transferred to. There, we need to create
checksums from the existing backup files:

```
for i in /mnt/backup/moodle/course_archive/*.mbz ; do sha1sum $i >> checksum.txt; done
```

This creates a `checksum.txt` that looks like this:

```
c3e9dca0fab4154765b5f4af70a8d460a6148ab7  /mnt/backup/moodle/course_archive/2026-03-19-ID-10863-COURSE-107.mbz
186a6c5f0629d907c11072a2e117c73598815a35  /mnt/backup/moodle/course_archive/2026-03-19-ID-10864-COURSE-857.mbz
da9988451b5c77ce029a56547dc75016a02dd822  /mnt/backup/moodle/course_archive/2026-03-26-ID-10865-COURSE-413.mbz
35da002b2ac4db2351225dcd3f203d34740b1020  /mnt/backup/moodle/course_archive/2026-03-26-ID-10866-COURSE-435.mbz
9cb09eca644d8fbec948d5c6118e646055d51fd9  /mnt/backup/moodle/course_archive/2026-03-26-ID-10867-COURSE-130.mbz
```

Once that is complete, we actually check, if any of the checksums in the `checksum.txt`
is also contained in the `files.txt` that was the result of the data base query and whose
files are still in the moodle data dir on the webserver.

```
cat files.txt | cut -d\; -f3 | while read l; do grep $l checksum.txt; done
```

What we figured out is, that while there are many backup.mbz files on
the webserver, these are not the same. The above grep command yields
no output, hence hashes from the backup files are not found in the database.
