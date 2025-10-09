#!/bin/bash

## Use Case
#
# This script should work on a Moodle plugin, that is checked out and
# a new release should be created. The release is based on a tag that
# must exist and pushed to the repo.
# From that tag, a new release is created on github.com and then
# uploaded to moodle.org. For both sites the APIs are used.
#
## Prerquisites
#
# You need at least a token on github.com, see documentation at:
# https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app
# In your account (right upper corner click tthe icon) then go to
# Settings -> Developer Settings -> Personal access tokens ->
# Fine-grained-tokens. For the tokens permissions you may set
# an expire date, I choose "All repositories" for repository access,
# and the repository permissions "Contents" and "Workflows" to
# read and write.
#
# You need a API token for moodle.org. Login at moodle.org and
# navigate to Plugins (top navigation) -> API access (right navigation)
# and create a new token.
#
## Usage
#
# The script need a few mandatory information before a release can be
# created. The minimum is the release tag. Furthermore, a token for
# moodle.org and for github.com is necessary. These tokens can be
# put into an environment variable or a config file.
#
# The following arguments are possible:
# -c <file>: Path and file name of a custom config file.
# -g <token>: Token for github.com (can be set in GITHUB_COM_TOKEN).
# -m <token>: Token for moodle.org (can be set in MOODLE_ORG_TOKEN).
# -no-github: Skip publishing a release of github.com.
# -no-moodle: Skip publishing a release of moodle.org.
# -t <tag>: mandatory tag name (that must exist in the project).
#
# The following settings can be set either via an environment
# variable or via a settings file in ini format (no spaces at the =)
# so that it is a valid bash script. You can place the settings file
# anywhere and use it via -c. By default a settings file named
# .release-plugin.ini is your home directory searched and read
# if it exists.
# 
# The following settings can be used:
# CONFIG_INI=<valid_path_and_file>
# GITHUB_COM_TOKEN=<token for your github accout & repo access>
# MOODLE_ORG_TOKEN=<token for your Moodle API access>
# RELEASE_TO_GITHUB=0|1 default is 1
# RELEASE_TO_MOODLE=0|1 default is 1
#
# Except for the tokens, any of these settings can be overwritten
# via command line arguments.
### End Help

# Some global switched that might be modified later.
if [ -z $RELEASE_TO_GITHUB ]; then
  RELEASE_TO_GITHUB=1
fi
if [ -z $RELEASE_TO_MOODLE ]; then
  RELEASE_TO_MOODLE=1
fi
if [ -z $CONFIG_INI ]; then
  CONFIG_INI=~/.release-plugin.ini
fi

# Check dependecies.
for cmd in curl jq git; do
  if [ "$(which $cmd) " == " " ]; then
    echo "$cmd is required to run this script."
    exit 1
  fi
done

# Evaluate the command line switches.
for arg in "$@"; do
  if [ "$arg" == '--help' ]; then
    end=$(grep -nE '^### End Help' $0 | cut -d ':' -f 1)
    head $0 -n $(($end - 1)) | grep  -v \#\! | sed 's|^# \?||g'
    exit
  elif [ "$arg" == '-no-github' ]; then
    RELEASE_TO_GITHUB=0
    s=''
  elif [ "$arg" == '-no-moodle' ]; then
    RELEASE_TO_MOODLE=0
    s=''
  elif [[ "$arg" =~ ^-[cgmt]$ ]]; then
    s=$arg
  elif [ "$s" == '-c' ]; then
    CONFIG_INI=$arg
    s=''
  elif [ "$s" == '-g' ]; then
    GITHUB_COM_TOKEN=$arg
    s=''
  elif [ "$s" == '-m' ]; then
    MOODLE_ORG_TOKEN=$arg
    s=''
  elif [ "$s" == '-t' ]; then
    GIT_TAG=$arg
    s=''
  else
    echo -e "Invalid argument or missing switch\nSee --help for more details."
    exit 2
  fi
done

# Try to include the config file, if it exists.
if [ ${CONFIG_INI:0:1} == '/' ]; then
  realConfigFile=$CONFIG_INI
else
  realConfigFile=$(realpath $(pwd)/$CONFIG_INI)
fi
if [ -f $realConfigFile ]; then
  source $realConfigFile
fi

# Check if we have a tag set.
if [ -z $GIT_TAG ]; then
  echo 'No tag of a release specified.'
  exit 1
fi

# When publishing a release to github.com, we need a token.
if [ -z $GITHUB_COM_TOKEN ] && [ $RELEASE_TO_GITHUB -eq 1 ]; then
  echo 'Github token missing.'
  exit 1
fi

# When publishing a release to moodle.org, we need a token.
if [ -z $MOODLE_ORG_TOKEN ] && [ $RELEASE_TO_MOODLE -eq 1 ]; then
  echo 'Moodle token missing.'
  exit 1
fi

# Get the plugin name from the $plugin->component variable inside the version.php.
pluginName=$(grep component version.php | sed "s/.*['\"]\([^'\"]*\)['\"].*/\1/")
if [ "$pluginName " == ' ' ]; then
  echo 'Plugin name not found in version.php. Are we inside a plugin directory?'
  exit 2
fi

# Get the remote git url and examine repo name and owner.
repourl=$(git remote get-url origin)
if [ $? -ne 0 ]; then
  echo 'Could not determine git remote origin, are we in a git controlled directory?'
  exit 3
fi
repourl="${repourl/\.git/}"
repourl="${repourl##*:}"
owner=$(echo $repourl | cut -d / -f1)
repoName="${repourl##*/}"

# Check if the tag exists an then fetch the commit message of that tag.
tagVerified=$(git tag | grep -E "^${GIT_TAG}$")
if [ "$tagVerified" != $GIT_TAG ]; then
  echo "Git tag $GIT_TAG not found."
  exit 4
fi
releaseDescription=$(git show -s --format=%B $GIT_TAG | grep -Ev '^(Tagger:|tag )')

# Run the command to create a new release on github.com.
if [ $RELEASE_TO_GITHUB -eq 1 ]; then
  cat > ".temp.release-plugin.$$" << EOF
  {
    "tag_name":"$GIT_TAG",
    "name":"$GIT_TAG",
    "body":"$releaseDescription",
    "draft":false,
    "prerelease":false,
    "generate_release_notes":true
  }
EOF
  response=$(curl -s -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_COM_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/${owner}/${repoName}/releases \
    -d @.temp.release-plugin.$$)
  echo "Response from github.com:"
  echo "$response"
  rm .temp.release-plugin.$$
fi

# Run the command to create a new release on moodle.org.
if [ $RELEASE_TO_MOODLE -eq 1 ]; then
  zipurl="https://api.github.com/repos/${owner}/${repoName}/zipball/${GIT_TAG}"
  response=$(curl -s https://moodle.org/webservice/rest/server.php \
    --data-urlencode "wstoken=${MOODLE_ORG_TOKEN}" \
    --data-urlencode "wsfunction=local_plugins_add_version" \
    --data-urlencode "moodlewsrestformat=json" \
    --data-urlencode "frankenstyle=${pluginName}" \
    --data-urlencode "zipurl=${zipurl}" \
    --data-urlencode "vcssystem=git" \
    --data-urlencode "vcsrepositoryurl=https://github.com/${owner}/${repoName}" \
    --data-urlencode "vcstag=${GIT_TAG}" \
    --data-urlencode "altdownloadurl=${zipurl}")
  echo "Response from moodle.org:"
  echo $response | jq
  if [ $? -ne 0 ]; then
    echo "$response"
  fi
fi