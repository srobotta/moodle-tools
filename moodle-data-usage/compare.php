<?php
/**
 * <one line to give the program's name and a brief idea of what it does.>
 * Copyright (C) <year>  <name of author>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Increase memory limit for large file listings.
ini_set('memory_limit', '2G');

// File path an name from the database export.
$fileListDb = null;
// File path an name from the directory listing.
$fileListDir = null;

// CLI options.
$options = getopt('d:f:hn', ['dbfile:', 'dirfile:', 'help', 'noname']);

if (array_key_exists('help', $options) || array_key_exists('h', $options)) {
    $help = [
        'Compare files in moodledata with database export.',
        'The data must be available as described in the README.md.',
        '',
        'Options:',
        '-h, --help               Print out this help',
        '-d, --dbfile             File with database export',
        '-f, --dirfile            File with directory listing',
        '-n, --noname             Do not show file names in the output',
        '',
        'Example:',
        '$php compare.php -d filelist.csv -f dirlist.txt',
    ];
    echo implode("\n", $help) . "\n";
    die;
}

if (array_key_exists('d', $options)) {
    $fileListDb = $options['d'];
} elseif (array_key_exists('dbfile', $options)) {
    $fileListDb = $options['dbfile'];
}
if (array_key_exists('f', $options)) {
    $fileListDir = $options['f'];
} elseif (array_key_exists('dirfile', $options)) {
    $fileListDir = $options['dirfile'];
}
if (!$fileListDb || !$fileListDir) {
    die("Both database file and directory listing file must be provided.\n");
}

// Show file name in db listing.
$showFileName = (!array_key_exists('n', $options) && !array_key_exists('noname', $options));
    
// Array that contains the data from the directory listing.
// This array is structured as $filesInDir[path1][path2][hash] = true and
// emptied as we find files in the database export.
$filesInDir = [];
// Array to remember when we have processed a database entry, because there
// are more db rows with the same hash.
$fileProcessed = [];

// Open the directory listing and read all files into the array.
$fp = fopen($fileListDir, "rb");
if (!$fp) die("Could not open $fileListDir");
while (!feof($fp)) {
    $line = fgets($fp, 1024);
    $data = explode('/', trim($line));
    if (count($data) < 3) continue;
    [$p1, $p2, $hash] = $data;
    if (!array_key_exists($p1, $filesInDir)) {
        $filesInDir[$p1] = [];
    }
    if (!array_key_exists($p2, $filesInDir[$p1])) {
        $filesInDir[$p1][$p2] = [];
    }
    $filesInDir[$p1][$p2][$hash] = true;
}
fclose($fp);

echo "\nFiles in DB but not in moodle-data\n";

// Open the database export and compare with the directory listing array.
$fp = fopen($fileListDb, "rb");
if (!$fp) die("Could not open $fileListDb");
while (!feof($fp)) {
    $line = fgets($fp, 1024);
    $data = explode(';', trim($line));
    if (count($data) < 4) continue;
    [$hash, $path, $name, $size] = $data;
    // We processed the file before.
    if (array_key_exists($hash, $fileProcessed)) {
        continue;
    }
    // From the hash get the path parts.
    $p1 = substr($hash, 0, 2);
    $p2 = substr($hash, 2, 2);
    // And check if that file exists in the directory listing array.
    if (array_key_exists($p1, $filesInDir) &&
        array_key_exists($p2, $filesInDir[$p1]) &&
        array_key_exists($hash, $filesInDir[$p1][$p2])
    ) {
        unset($filesInDir[$p1][$p2][$hash]);
        if (empty($filesInDir[$p1][$p2])) {
            unset($filesInDir[$p1][$p2]);
        }
        if (empty($filesInDir[$p1])) {
            unset($filesInDir[$p1]);
        }
        $fileProcessed[$hash] = true;
        continue;
    }
    echo implode('/' , [$p1, $p2, $hash]);
    if ($showFileName) {
        echo ' -: ' . $name;
    }
    echo "\n";
}

echo "\nFiles in moodle-data but not in DB\n";
// If that array still contains entries, these are files that are in the
// directory listing but not in the database export.
foreach (array_keys($filesInDir) as $p1) {
    foreach (array_keys($filesInDir[$p1]) as $p2) {
        foreach (array_keys($filesInDir[$p1][$p2]) as $hash) {
            echo "$p1/$p2/$hash\n";
        }
    }
}

        
