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
 * CLI helper: uninstall all H5P libraries so the content-types hub task will
 * re-download and re-deploy them (and rewrite the lost filedir files).
 *
 * Use this when the h5p_libraries DB rows exist but their physical files are
 * missing from filedir, which makes h5p_get_content_types_task skip every type
 * as "already installed".
 *
 * Uses the supported \core_h5p\api::delete_library(), which keeps the .h5p
 * source files of deployed content so that content redeploys on next view.
 *
 * Usage (run inside the webserver container, from the dir holding config.php):
 *     php reset_h5p_libraries.php            # dry run: list what would be removed
 *     php reset_h5p_libraries.php --run      # actually uninstall
 *
 * After --run, re-fetch the libraries:
 *     php public/admin/cli/scheduled_task.php -e='\core\task\h5p_get_content_types_task'
 *     php public/admin/cli/purge_caches.php
 *
 * @package   core_h5p
 * @copyright 2026 Stephan Robotta
 * @license   http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);

require(__DIR__ . '/public/config.php');
require_once($CFG->libdir . '/clilib.php');

use core_h5p\api;
use core_h5p\factory;

list($options, $unrecognised) = cli_get_params(
    [
        'help' => false,
        'run'  => false,
    ],
    [
        'h' => 'help',
    ]
);

if ($unrecognised) {
    $unrecognised = implode(PHP_EOL . '  ', $unrecognised);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognised));
}

if ($options['help']) {
    echo <<<EOT
Uninstall all H5P libraries so the content-types hub task re-downloads them.

Usage:
    php reset_h5p_libraries.php [--run]

Options:
    -h, --help   Print this help.
    --run        Actually uninstall. Without it, only lists what would happen.

Afterwards, re-fetch and purge caches:
    php public/admin/cli/scheduled_task.php -e='\\core\\task\\h5p_get_content_types_task'
    php public/admin/cli/purge_caches.php

EOT;
    exit(0);
}

$factory = new factory();

$libraries = $DB->get_records('h5p_libraries', null, 'machinename ASC, majorversion ASC, minorversion ASC',
    'id, machinename, majorversion, minorversion, patchversion');

$total = count($libraries);
cli_heading(($options['run'] ? 'Uninstalling' : 'Dry run — would uninstall') . " $total H5P library record(s)");

if ($total === 0) {
    cli_writeln('No H5P libraries found in the database. Nothing to do.');
    cli_writeln('Just run the content types task to install them from the hub.');
    exit(0);
}

$removed = 0;
foreach ($libraries as $lib) {
    $label = sprintf('%s %d.%d.%d (id %d)',
        $lib->machinename, $lib->majorversion, $lib->minorversion, $lib->patchversion, $lib->id);

    // delete_library() cascades to dependent libraries, so a row may already be
    // gone by the time we reach it. Skip those that no longer exist.
    if (!$DB->record_exists('h5p_libraries', ['id' => $lib->id])) {
        cli_writeln("  skip (already removed by a dependency cascade): $label");
        continue;
    }

    if (!$options['run']) {
        cli_writeln("  would remove: $label");
        continue;
    }

    try {
        $library = api::get_library($lib->id);
        api::delete_library($factory, $library);
        $removed++;
        cli_writeln("  removed: $label");
    } catch (\Throwable $e) {
        cli_writeln("  ERROR removing $label: " . $e->getMessage());
    }
}

cli_writeln('');
if ($options['run']) {
    cli_heading('Done');
    cli_writeln("Uninstalled $removed library record(s).");
    cli_writeln('Now re-fetch the content types and purge caches:');
    cli_writeln("  php public/admin/cli/scheduled_task.php -e='\\core\\task\\h5p_get_content_types_task'");
    cli_writeln('  php public/admin/cli/purge_caches.php');
} else {
    cli_heading('Dry run complete');
    cli_writeln('Re-run with --run to actually uninstall.');
}

exit(0);
