<?php
/**
 * Get a list of your branches and show the ticket status along with the branch.
 * Usage: php brstatus.php [-d <repodir>] [-c <col,col,col ...>] [-m N] [-t <format>] [--help|-h]
 *
 * Arguments:
 * -c: Provide a list of column names that is displayed in the output. Valid column names are:
 *     branch, mdl, title, type, typeId, priority, priorityId, status, statusId,
 *     resolution, resolutionId, created, updated, resolved, assignee, reporter
 *     Default is 'branch', 'title', 'status', 'updated', 'resolved', 'assignee'
 *     Set it to 'ALL' to see all available columns.
 * -d: The directory where your moodle repo is checked out. Can be also defined via the
 *     environment variable $MOODLE_DIR. If both are empty, the current working dir is used.
 * -m: Maximum col width, default is 45. Set 0 when truncation of values is not wanted.
 * -t: The string to format the date/time columns created, updated, and resolved.
 *     See https://www.php.net/manual/en/datetime.format.php for details, default is: Y-m-d
 */


/**
 * Write message to stdout and quit script execution with exit code 1.
 * @param string $msg
 * @return void
 */
function dieNice(string $msg) {
    echo $msg . PHP_EOL;
    echo 'See php ' . basename($_SERVER['argv'][0]) . ' --help for more details' . PHP_EOL;
    exit(1);
}

/**
 * Get branches from git, return the branch names as an array.
 * @param string $workdir
 * @return array
 */
function getBranches(string $workdir): array
{
    $branches = [];
    exec("cd $workdir && git branch",$out, $res);
    if ($res !== 0) {
        dieNice('Could not fetch git branches. Is the working dir ' . $workdir . ' correct?');
    }
    foreach ($out as $line) {
        $line = trim($line);
        if (str_starts_with($line, '* ')) {
            $line = substr($line, 2);
        }
        $branches[] = $line;
    }
    return $branches;
}

/**
 * Alternative to str_pad because it doesn't deal with multibyte strings.
 * @param string $string
 * @param int $length
 * @param string $padString
 * @param int $pos
 * @return string
 * @throws Exception
 */
function mbStrPad(string $string, int $length, string $padString = " ", int $pos = STR_PAD_RIGHT)
{
    if ($pos === STR_PAD_RIGHT) {
        return $string . str_repeat($padString, $length - mb_strlen($string));
    }
    if ($pos === STR_PAD_LEFT) {
        return str_repeat($padString, $length - mb_strlen($string)) . $string;
    }
    throw new Exception('$pos ' . $pos . ' is not supported');
}

/**
 * Convert a date string like this one: Tue, 17 Jan 2023 00:53:02 +0800
 * into a DateTime object. If the string is not parsable then 1.1.1970 is used.
 *
 * @param string $str
 * @param string $format
 * @return string
 */
function formatDateTime(string $str, string $format): string
{
    $months = array_flip(['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
    $str = preg_replace_callback('/^(\w+, )(\d+)( \w+ )/', function($item) use ($months) {
        $m = $months[trim($item[3])] ?? -1;
        if ($m === -1) return '';
        return mbStrPad($item[2], 2, '0', STR_PAD_LEFT) . '.'
            . mbStrPad(($m + 1), 2, '0', STR_PAD_LEFT) . '.';
    }, $str);
    $d = new DateTime();
    $ts = strtotime($str);
    if ($ts === false) {
        return '';
    } else {
        $d->setTimestamp($ts);
    }
    return $d->format($format);
}

/**
 * Get information from the moodle tracker issue by reading the xml page of the issue, parsing the xml, derive
 * the relevant information and store it in an associative array.
 *
 * @param int $issueNo
 * @param string $dateFormat
 * @return array
 */
function getTrackerInfo(int $issueNo, string $dateFormat): array
{
    @$xml = simplexml_load_file(rawurlencode(sprintf(
        'https://tracker.moodle.org/si/jira.issueviews:issue-xml/MDL-%1$d/MDL-%1$d.xml', $issueNo
    )));
    if ($xml === false) return [];
    $title = (string)$xml->channel->item->title;
    $title = trim(substr($title, strpos($title, ']') + 2));
    return [
        'mdl' => $issueNo,
        'title' => $title,
        'type' => trim($xml->channel->item->type),
        'typeId' => (int)$xml->channel->item->type['id'],
        'priority' => trim($xml->channel->item->priority),
        'priorityId' => (int)$xml->channel->item->priority['id'],
        'status' => trim($xml->channel->item->status),
        'statusId' => (int)$xml->channel->item->status['id'],
        'resolution' => trim($xml->channel->item->resolution),
        'resolutionId' => (int)$xml->channel->item->resolution['id'],
        'created' => formatDateTime((string)$xml->channel->item->created, $dateFormat),
        'updated' => formatDateTime((string)$xml->channel->item->updated, $dateFormat),
        'resolved' => formatDateTime((string)$xml->channel->item->resolved, $dateFormat),
        'assignee' => trim($xml->channel->item->assignee),
        'reporter' => trim($xml->channel->item->reporter),
    ];
}

/**
 * Print a table with the branches and the ticket info from the tracker.
 *
 * @param array $branches
 * @param array $tableCols
 * @param int $maxWidth
 * @param string $dateFormat
 * @return void
 */
function printTable(array $branches, array $tableCols, int $maxWidth, string $dateFormat)
{
    $colOther='';
    // start a new table, fill the first row with the desired col names.
    $table = [];
    $width = []; // store max width for each col, needed for nice output.
    foreach ($tableCols as $col) {
        $table[0][$col] = $col;
        $width[$col] = mb_strlen($col);
    }

    // name for the other col in case there is an error and branch and col is displayed only.
    if(isset($tableCols[1])) {
        $colOther = $tableCols[1] !== 'branch' ? $tableCols[1] : $tableCols[0];
    }
    // store here the fetched tracker data for each issue, key is the issue number
    $info = [];
    foreach ($branches as $branch) {
        $len = strlen($branch);
        if ($len > $width['branch']) {
            $width['branch'] = $len;
        }
        preg_match('/(MDL\-)(\d+)(\s|\b)/', $branch, $m);
        if (!isset($m[2])) {
            $table[] = ['branch' => $branch,  $colOther => 'other'];
            continue;
        }
        $mdl = (int)$m[2];
        if (!isset($info[$mdl])) {
            $info[$mdl] = getTrackerInfo($mdl, $dateFormat);
        }
        if (empty($info[$mdl])) {
            $table[] = ['branch' => $branch, $colOther => 'no data found'];
            continue;
        }
        $line = [];
        foreach ($tableCols as $col) {
            $line[$col] = ($col === 'branch') ? $branch : $info[$mdl][$col] ?? '';
            $len = mb_strlen($line[$col]);
            if ($len > $width[$col]) {
                $width[$col] = min($len, $maxWidth);
            }
            if ($len > $maxWidth) {
                $line[$col] = mb_substr($line[$col], 0, $maxWidth - 1) . mb_chr(0x2026);
            }
        }
        $table[] = $line;
    }

    foreach (array_keys($table) as $row) {
        foreach ($tableCols as $col) {
            $val = $table[$row][$col] ?? '';
            echo mbStrPad($val, $width[$col]) . ' ';
        }
        // backspace to remove the last space and add a new line
        echo chr(8) . PHP_EOL;
    }
}

// Main program starts here

// defaults
$repodir    = getenv('MOODLE_DIR') ?: getcwd();
$maxWidth   = 45;
$cols       = ['branch', 'title', 'status', 'updated', 'resolved', 'assignee'];
$cols_all   = ['branch', 'title', 'status', 'statusId', 'created', 'updated',
    'resolved', 'assignee', 'reporter', 'resolution', 'resolutionId', 'priority',
    'priorityId', 'type', 'typeId'];
$dateFormat = 'Y-m-d';

// start handling command line args
$args = $_SERVER['argv'];
array_shift($args);
while ($arg = array_shift($args)) {
    if ($arg === '-d') {
        $argv = array_shift($args);
        if (empty($argv)) {
            dieNice('Argument -d needs directory');
        }
        $repodir = substr($argv, 0, 1) === DIRECTORY_SEPARATOR
            ? $argv : realpath(getcwd() . DIRECTORY_SEPARATOR . $argv);
        if (!is_dir($repodir)) {
            dieNice('Directory ' . $argv . ' does not exist');
        }
    } elseif ($arg === '-c') {
        $argv = array_shift($args);
        if (empty($argv)) {
            dieNice('Argument -c needs column names separated by ","');
        }
        if ($argv === 'ALL') {
            $cols = $cols_all;
        } else {
            $cols = [];
            foreach (explode(',', $argv) as $col) {
                $col = trim($col);
                if (empty($col) || in_array($col, $cols)) {
                    continue;
                }
                $cols[] = $col;
            }
            if (!in_array('branch', $cols)) {
                array_unshift($cols, 'branch');
            }
        }
    } elseif ($arg === '-m') {
        $argv = array_shift($args);
        $intArg = (int)$argv;
        if ('' . $intArg !== $argv || $intArg < 0) {
            dieNice('Argument -m needs a value of 0 or greater');
        }
        $maxWidth = $intArg === 0 ? PHP_INT_MAX : $intArg;
    } elseif ($arg === '-t') {
        $dateFormat = array_shift($args);
        if (empty($dateFormat)) {
            dieNice('Argument -t needs a value for the date time format');
        }
    } elseif ($arg === '--help' || $arg === '-h') {
        $out = false;
        foreach (explode(PHP_EOL, file_get_contents($_SERVER['argv'][0])) as $line) {
            if (str_contains($line, '/**') !== false) {
                $out = true;
                continue;
            }
            if ($out && str_contains($line, '*/') !== false) {
                exit(0);
            }
            if ($out) {
                echo substr($line, strpos($line, '*') + 2) . PHP_EOL;
            }
        }
    } else {
        dieNice('Invalid argument ' . escapeshellarg($arg));
    }
}
// end handling command line args

// fetch branches and print table
$branches = getBranches($repodir);
if (empty($branches)) {
    dieNice('No branches found');
}
printTable($branches, $cols, $maxWidth, $dateFormat);
