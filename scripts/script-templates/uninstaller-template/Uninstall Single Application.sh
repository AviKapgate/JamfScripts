#!/bin/bash

###
#
#            Name:  Uninstall Single Application.sh
#     Description:  A template script to assist with the uninstallation of
#                   macOS products where the vendor has missing or incomplete
#                   removal solutions.
#                   Attempts vendor uninstall by running all provided
#                   uninstallation commands, quits all running target processes,
#                   unloads all associated launchd tasks, then removes all
#                   associated files.
#                   https://github.com/palantir/jamf-pro-scripts/tree/main/scripts/script-templates/uninstaller-template
#         Created:  2017-10-23
#   Last Modified:  2022-04-06
#         Version:  1.3.8pal1
#
#
# Copyright 2017 Palantir Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
###



########## variable-ing ##########



# ENVIRONMENT VARIABLES (leave as-is):
loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
# For any file paths used later in this script, use "$loggedInUserHome" for the
# current user's home folder path.
# Don't just assume the home folder is at /Users/$loggedInUser.
# shellcheck disable=SC2034
loggedInUserHome=$(/usr/bin/dscl . -read "/Users/${loggedInUser}" NFSHomeDirectory | /usr/bin/awk '{print $NF}')
loggedInUserUID=$(/usr/bin/id -u "$loggedInUser")
currentProcesses=$(/bin/ps aux)
launchAgentCheck=$(/bin/launchctl asuser "$loggedInUserUID" /bin/launchctl list)
launchDaemonCheck=$(/bin/launchctl list)


# PROCESSES:
# A list of application processes to target for quitting.
# Names should match what is displayed for the process in Activity Monitor
# (e.g. "Chess", not "Chess.app").
#
# If no processes need to be quit, comment these array values out.
processName="${4}" # Jamf Pro script parameter: "App Process"


# FILE PATHS:
# A list of full file paths to target for launchd unload and removal.
# Leave off trailing slashes from directory paths.
#
# If no files need to be manually deleted, comment these array values out.
resourceFile="${5}" # Jamf Pro script parameter: "App File Path"; should be full path to the application, e.g. "/System/Applications/Chess.app"



########## function-ing ##########



# Exit if any required Jamf Pro arguments are undefined.
check_jamf_pro_arguments () {
  if [ -z "$processName" ] || [ -z "$resourceFile" ]; then
    echo "❌ ERROR: Undefined Jamf Pro argument, unable to proceed."
    exit 74
  fi
}


# Quit target processes and remove associated login items.
quit_processes () {
  if echo "$currentProcesses" | /usr/bin/grep -q "${processName}"; then
    /bin/launchctl asuser "$loggedInUserUID" /usr/bin/osascript -e "tell application \"${processName}\" to quit"
    echo "Quit ${processName}, removed from login items if present."
  else
    echo "${processName} not running."
  fi
}


# Remove all remaining resource files.
delete_files () {
    # Check if file exists.
    if [ -e "$resourceFile" ]; then
      # Check if file is a plist.
      if echo "$resourceFile" | /usr/bin/grep -q ".plist"; then
        # If plist is loaded as LaunchAgent or LaunchDaemon, unload it.
        justThePlist=$(/usr/bin/basename "$resourceFile" | /usr/bin/awk -F.plist '{print $1}')
        if echo "$launchAgentCheck" | /usr/bin/grep -q "$justThePlist"; then
          /bin/launchctl asuser "$loggedInUserUID" /bin/launchctl unload "$targetFile"
          echo "Unloaded LaunchAgent at ${resourceFile}."
        elif echo "$launchDaemonCheck" | /usr/bin/grep -q "$justThePlist"; then
          /bin/launchctl unload "$resourceFile"
          echo "Unloaded LaunchDaemon at ${resourceFile}."
        fi
      fi
      # Remove system immutable flag if present.
      if /bin/ls -ldO "$resourceFile" | /usr/bin/awk '{print $5}' | /usr/bin/grep -q "schg"; then
        /usr/bin/chflags -R noschg "$resourceFile"
        echo "Removed system immutable flag for ${resourceFile}."
      fi
      # Remove file.
      /bin/rm -rf "$resourceFile"
      echo "Removed ${resourceFile}."
    fi
}



########## main process ##########



# Exit if any required Jamf Pro arguments are undefined.
check_jamf_pro_arguments


# Each function will only execute if the respective source array is not empty
# or undefined.
if [ -n "${processName}" ]; then
  echo "Quitting process (if running)..."
  quit_processes
fi

if [ -n "${resourceFile}" ]; then
  echo "Removing files (if present)..."
  delete_files
fi



exit 0
