#!/bin/bash
# Version: 0.3.1
# Last Update: February 21, 2016
#
# Description: Bash script to deploy a Bedrock+Sage WordPress project to WP Engine's hosting platform
# Repository: https://github.com/hello-jason/bedrock-sage-deploy-to-wpengine.git
# README: https://github.com/hello-jason/bedrock-sage-deploy-to-wpengine/blob/master/README.md
#
#######################################
#
# Edited by Dan Abel to use from Bedrock's parent dir so it can be used with a Trellis set up
# Also, if themeName is set to an empty string it bypasses the theme building for when not using a Sage theme
# Last Update: 2016-08-26
#
#######################################
#
# Tested Bedrock Version: 1.5.3
# Tested Sage Version: 8.4.2
# Tested bash version: 4.3.42
# Author: Jason Cross
# Author URL: http://hellojason.net/
########################################
# PLEASE EDIT
# Your theme directory name (/web/app/themes/yourtheme)
# Set to empty string if not using a sage theme
themeName=""
########################################

####################
# Usage
####################
# bash wpedeploy.sh nameOfRemote

####################
# Thanks
####################
# Thanks to [schrapel](https://github.com/schrapel/wpengine-bedrock-build) for
# providing some of the foundation for this script.
# Also thanks to [cmckni3](https://github.com/cmckni3) for guidance and troubleshooting

####################
# Set variables
####################
if [ -z "$1" ]; then
echo -e "[\033[31mERROR\033[0m] You must specify a remote as your first argument. e.g. staging or production or whatever your remote is called."
exit 1
fi
# WP Engine remote to deploy to
wpengineRemoteName=$1
# Get present working directory
presentWorkingDirectory=`pwd`
bedrockDirectory="${presentWorkingDirectory}/site"
# Get current branch user is on
currentLocalGitBranch=`git rev-parse --abbrev-ref HEAD`
# Temporary git branch for building and deploying
tempDeployGitBranch="wpedeployscript/${currentLocalGitBranch}"
# Bedrock themes directory
bedrockThemesDirectory="${bedrockDirectory}/web/app/themes/"

####################
# Perform checks before running script
####################

# Git checks
####################
# Halt if there are uncommitted files
if [[ -n $(git status -s) ]]; then
echo -e "[\033[31mERROR\033[0m] Found uncommitted files on current branch \"$currentLocalGitBranch\".\n        Review and commit changes to continue."
git status
exit 1
fi

# Check if specified remote exist
git ls-remote "$wpengineRemoteName" &> /dev/null
if [ "$?" -ne 0 ]; then
echo -e "[\033[31mERROR\033[0m] Unknown git remote \"$wpengineRemoteName\"\n        Visit \033[32mhttps://wpengine.com/git/\033[0m to set this up."
echo "Available remotes:"
git remote -v
exit 1
fi

# Directory checks
####################
# Halt if theme directory does not exist
if [ "$themeName" != "" ]; then
if [ ! -d "$bedrockDirectory"/web/app/themes/"$themeName" ]; then
echo -e "[\033[31mERROR\033[0m] Theme \"$themeName\" not found.\n        Set \033[32mthemeName\033[0m variable in $0 to match your theme in $bedrockThemesDirectory"
echo "Available themes:"
ls $bedrockThemesDirectory
exit 1
else
echo "Theme folder $themeName exists. Good to go."
fi
else
echo "No Sage theme specified, moving on!..."
fi
####################
# Begin deploy process
####################
# Checkout new temporary branch
echo "Preparing deploy on branch ${tempDeployGitBranch}..."
git checkout -b "$tempDeployGitBranch" &> /dev/null

# Go into bedrock directory
cd "$bedrockDirectory"

# Run composer
composer install

# delete bedrock gitignore
rm .gitignore &> /dev/null

# back to root directory
cd "$presentWorkingDirectory"

# WPE-friendly gitignore
rm .gitignore &> /dev/null
echo -e "/*\n!wp-content/" > ./.gitignore

# Copy meaningful contents of web/app into wp-content
mkdir wp-content && cp -rp "$bedrockDirectory"/web/app/plugins wp-content && cp -rp "$bedrockDirectory"/web/app/themes wp-content
echo "Created wp-content and copied in plugins and themes from bedrock"

if [ "$themeName" != "" ]; then
# Go into theme directory
cd "$presentWorkingDirectory/wp-content/themes/$themeName" &> /dev/null

# Build theme assets
npm install && bower install && gulp --production

# Back to the top
cd "$presentWorkingDirectory"

# Cleanup wp-content
####################
# Remove sage theme cruft
# Files
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/.bowerrc &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/.editorconfig &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/.gitignore &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/.jscsrc &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/.jshintrc &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/.travis.yml &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/bower.json &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/gulpfile.js &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/package.json &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/composer.json &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/composer.lock &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/ruleset.xml &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/CHANGELOG.md &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/CONTRIBUTING.md &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/LICENSE.md &> /dev/null
rm "$presentWorkingDirectory"/wp-content/themes/"$themeName"/README.md &> /dev/null
# Directories
rm -rf "$presentWorkingDirectory"/wp-content/themes/"$themeName"/node_modules &> /dev/null
rm -rf "$presentWorkingDirectory"/wp-content/themes/"$themeName"/bower_components &> /dev/null
rm -rf "$presentWorkingDirectory"/wp-content/themes/"$themeName"/assets &> /dev/null
rm -rf "$presentWorkingDirectory"/wp-content/themes/"$themeName"/vendor &> /dev/null
fi


####################
# Push to WP Engine
####################
git ls-files | xargs git rm --cached &> /dev/null
cd "$presentWorkingDirectory"/wp-content/
find . | grep .git | xargs rm -rf
cd "$presentWorkingDirectory"

git add --all &> /dev/null
git commit -am "WP Engine build from: $(git log -1 HEAD --pretty=format:%s)$(git rev-parse --short HEAD 2> /dev/null | sed "s/\(.*\)/@\1/")" &> /dev/null
echo "Pushing to WPEngine..."

# Push to a remote branch with a different name
# git push remoteName localBranch:remoteBranch
git push "$wpengineRemoteName" "$tempDeployGitBranch":master --force

####################
# Back to a clean slate
####################
git checkout "$currentLocalGitBranch" &> /dev/null
rm -rf wp-content/ &> /dev/null
git branch -D "$tempDeployGitBranch" &> /dev/null
echo "Done"
