<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * CLI helper: list core_h5p "libraries" filearea files whose physical content
 * file is missing from filedir.
 *
 * This diagnoses the "copy(... /filedir/xx/yy/<hash>): No such file or directory"
 * error raised when exporting an H5P content bundle, which happens when a
 * mdl_files row exists but its byte-file was lost (e.g. a recreated Docker
 * volume that desynced the DB from filedir).
 *
 * Usage (run inside the container, from the webroot that holds config.php):
 *     php check_missing_h5p_library_files.php
 *     php check_missing_h5p_library_files.php --area=libraries,content
 *     php check_missing_h5p_library_files.php --all --verbose
 *
 * @package   core_h5p
 * @copyright 2026 Stephan Robotta
 * @license   http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);

require(__DIR__ . '/public/config.php');
require_once($CFG->libdir . '/clilib.php');

list($options, $unrecognised) = cli_get_params(
    [
        'help'    => false,
        'area'    => 'libraries',
        'all'     => false,
        'verbose' => false,
    ],
    [
        'h' => 'help',
        'v' => 'verbose',
    ]
);

if ($unrecognised) {
    $unrecognised = implode(PHP_EOL . '  ', $unrecognised);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognised));
}

if ($options['help']) {
    echo <<<EOT
List core_h5p file records whose physical content file is missing from filedir.

Usage:
    php check_missing_h5p_library_files.php [options]

Options:
    -h, --help       Print this help.
    --area=<list>    Comma separated fileareas to check. Default: libraries.
    --all            Check every core_h5p filearea (overrides --area).
    -v, --verbose    Also print the full expected filedir path for each miss.

Exit status is 2 when at least one missing file is found, 0 otherwise.

EOT;
    exit(0);
}

// Resolve the filedir base path the same way file_system_filedir does.
$filedir = !empty($CFG->filedir) ? $CFG->filedir : $CFG->dataroot . '/filedir';

// Build the filearea filter.
$params = ['component' => 'core_h5p'];
$areasql = '';
if (!$options['all']) {
    $areas = array_filter(array_map('trim', explode(',', $options['area'])));
    if ($areas) {
        list($insql, $inparams) = $DB->get_in_or_equal($areas, SQL_PARAMS_NAMED, 'fa');
        $areasql = " AND filearea $insql";
        $params += $inparams;
    }
}

// filesize = 0 rows are directory placeholders (filename = '.') or empty files;
// they share the SHA1 of an empty string and have no byte-file to find. Skip them.
$sql = "SELECT id, contextid, filearea, itemid, filepath, filename, contenthash, filesize
          FROM {files}
         WHERE component = :component
               $areasql
               AND filename <> '.'
               AND filesize > 0
      ORDER BY filearea, itemid, filepath, filename";

$rs = $DB->get_recordset_sql($sql, $params);

cli_heading('Checking core_h5p content files against ' . $filedir);

$checked = 0;
$missing = 0;
$byarea = [];        // filearea => count.
$bylibrary = [];     // "filearea #itemid" => ['count' => n, 'sample' => filepath/filename].
$missinghashes = []; // Unique missing content hashes.

foreach ($rs as $file) {
    $checked++;
    $hash = $file->contenthash;
    $path = $filedir . '/' . substr($hash, 0, 2) . '/' . substr($hash, 2, 2) . '/' . $hash;

    if (is_readable($path)) {
        continue;
    }

    $missing++;
    $missinghashes[$hash] = true;

    $areakey = $file->filearea;
    $byarea[$areakey] = ($byarea[$areakey] ?? 0) + 1;

    $libkey = sprintf('%-12s itemid=%d  ctx=%d', $file->filearea, $file->itemid, $file->contextid);
    if (!isset($bylibrary[$libkey])) {
        $bylibrary[$libkey] = ['count' => 0, 'sample' => $file->filepath . $file->filename];
    }
    $bylibrary[$libkey]['count']++;

    echo sprintf(
        "MISSING  [%s]  ctx=%d itemid=%d  %s%s  (hash %s)\n",
        $file->filearea,
        $file->contextid,
        $file->itemid,
        $file->filepath,
        $file->filename,
        $hash
    );
    if ($options['verbose']) {
        echo "         expected: $path\n";
    }
}
$rs->close();

echo "\n";
cli_heading('Summary');
echo "Files checked : $checked\n";
echo "Files missing : $missing\n";
echo "Unique hashes : " . count($missinghashes) . "\n";

if ($byarea) {
    echo "\nMissing by filearea:\n";
    foreach ($byarea as $area => $count) {
        echo sprintf("  %-14s %d\n", $area, $count);
    }
    echo "\nMissing grouped by storage item (library/content):\n";
    foreach ($bylibrary as $key => $info) {
        echo sprintf("  %s  ->  %d file(s), e.g. %s\n", $key, $info['count'], $info['sample']);
    }
    echo "\nFor 'libraries' items, re-deploy the affected H5P libraries\n";
    echo "(re-import/upload the content type) and purge caches to rewrite filedir.\n";
}

exit($missing > 0 ? 2 : 0);
