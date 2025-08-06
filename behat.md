# Behat test cheat sheet

## Some useful lines for behat tests

### Set some configuration values for your Behat tests


```
Given the following config values are set as admin:
   | config_key | config value (as it is saved in the DB) | plugin_name  |

```

The first and the second value is mandatory. This is the settings name and
the settings value. For core settings this is just it. There is a 3rd parameter
for the plugin name. In the GUI for the above setting below the label you would
see in small letters the setting name, or the plugin_name/setting_name.
There is an optional fourth value (not used here) possible.

### Autocomplete options

Test for options that should appear in the autocomplete form (such as
the course search).

```
And I open the autocomplete suggestions list
When I type "test"
And I should see "Some value" in the ".form-autocomplete-suggestions" "css_element"
And I should see "Some other value" in the ".form-autocomplete-suggestions" "css_element"
```


### Language packs

A behat test that needs language packs installed

```
And the following "language packs" exist:
  | language |
  | fr       |
  | de       | 
  | es       |
```

And via these steps the user may change the language:

```
Then I follow "Preferences" in the user menu
And I follow "Preferred language"
And I select "de" from the "Preferred language" 
```

### Moodle version

Sometimes it's neccessary that a behat tests runs on a certain version of Moodle.

Behat test running in Moodle 4.4 and lower

```
Scenario: Check some feature in an older version.
  Given the site is running Moodle version 4.3 or lower
  And ...
```

Behat test running in Moodle 4.5 and higher

```
Scenario: Check some feature in a newer version.
  Given the site is running Moodle version 4.5 or higher
  And ...
```

Behat test running in Moodle 4.2 only

```
Scenario: Check some feature in Moodle 4.2
  Given the site is running Moodle version 4.2
  And ...
```

### Change View port

For some reasons you may adapt the view port size in the following way:

```
And I change viewport size to "1200x1000"
```

### Set field via xpath or css

And I set the field with xpath "(//select[contains(@class, 'category-percentage')])[2]" to "0.25"
And I set the field with xpath "//*[text()='Structure']/../..//select" to "0.00"

## Behat test initialization

### This is not a Behat Testsite

This error message appears when a previous initialization of the behat testsuite failed, e.g.
a plugin did not match the requirements.

In my case, because of dropping the old behat testsite tables I was missing the correct DB entry.
Make sure that `select * from b_config where name like '%test';` returns an entry with
the name `behattest`. The "b_" prefix is configured in my *config.php* as
`$CFG->behat_prefix = 'b_';`. If not existend add it by
`INSERT INTO b_config (name, value) VALUES ('behattest', '1');`.

Make sure that the cache is cleared. Because of the behat test
site, the normal cache cli function doesn't touch that cache. I did a temporary change in
the *lib/moodlelib.php* file:

```
index 5247b840e31..5a01ad94c86 100644
--- a/lib/moodlelib.php
+++ b/lib/moodlelib.php
@@ -1044,6 +1044,7 @@ function get_config($plugin, $name = null) {
 
     $cache = cache::make('core', 'config');
     $result = $cache->get($plugin);
+    $result = false;
     if ($result === false) {
         // The user is after a recordset.
         if (!$iscore) {
```

that forces a cache rebuild of the config. After running the `php admin/tool/behat/cli/init.php` once more, that modification can be removed again. Any subsequent reinitialization should work now as it did before.


## Behat and BBB

To be able to let the BBB behat tests run, you need a BBB mock server. Moodle HQ
has a docker image prepared that can be started with:

```
docker run -p 8001:80 moodlehq/bigbluebutton_mock
```

Also the config.php must be adjusted. The following line must be
inserted somewhere below the definition of the `$CFG->wwwroot` variable:

```
define('TEST_MOD_BIGBLUEBUTTONBN_MOCK_SERVER', "http://host.docker.internal:8001/hash" . sha1($CFG->wwwroot));
```

If you use the MDK the your domain name in the URL in the config should be `localhost`.
I use a docker environment for developing and therefore the connection must go out from
inside the docker container of the moodle webserver to my host machine. The docker host is available
via `host.docker.internal` because in my setup I added the following lines in the `base.yml`:

```
    extra_hosts:
      - host.docker.internal:host-gateway
```

More information about the BBB Mock Server Image can be found at:
https://github.com/moodlehq/bigbluebutton_mock
