#!/bin/bash
# shellcheck disable=SC2034

###
#
#            Name:  Uninstall Single Application.sh
#     Description:  A template script to assist with the uninstallation of
#                   macOS products where the vendor has missing or incomplete
#                   removal solutions.
#                   Attempts vendor uninstall by running all provided
#                   uninstallation commands, quits all running target processes,
#                   unloads all associated launchd tasks, disables kernel
#                   extensions, then removes all associated files.
#                   https://github.com/palantir/jamf-pro-scripts/tree/main/scripts/script-templates/uninstaller-template
#         Created:  2017-10-23
#   Last Modified:  2021-11-15
#         Version:  1.3.7pal1
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
scriptName=$(/usr/bin/basename "$0")
loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
# For any file paths used later in this script, use "$loggedInUserHome" for the
# current user's home folder path.
# Don't just assume the home folder is at /Users/$loggedInUser.
loggedInUserHome=$(/usr/bin/dscl . -read "/Users/$loggedInUser" NFSHomeDirectory | /usr/bin/awk '{print $NF}')
loggedInUserUID=$(/usr/bin/id -u "$loggedInUser")
currentProcesses=$(/bin/ps aux)
launchAgentCheck=$(/bin/launchctl asuser "$loggedInUserUID" /bin/launchctl list)
launchDaemonCheck=$(/bin/launchctl list)


# UNINSTALLER BASH SCRIPTS:
# A list of file paths for vendor-provided uninstallation Bash scripts.
# Note that vendor uninstaller workflows may differ greatly. Some vendors may
# use their own command-line tools, custom flags, or other workflows to
# accomplish this task (that's why this script exists!), so make any necessary
# changes to the below commands if the uninstall workflows are not Bash
# executable files.
#
# This may not work as expected if you reference nonexistent scripts or
# binaries, or if the uninstaller resources are not executable via Bash.
#
# If the vendor did not provide an uninstaller workflow, comment these array
# values out.
vendorUninstallerBashScripts=(
#  "/path/to/vendor_uninstaller_command1.sh"
#  "/path/to/vendor_uninstaller_command2.sh"
)


# PROCESSES:
# A list of application processes to target for quit and login item removal.
# Names should match what is displayed for the process in Activity Monitor
# (e.g. "Chess", not "Chess.app").
#
# If no processes need to be quit, comment these array values out.
processNames=(
  "$4" # Jamf Pro script parameter: "App Process"
)


# FILE PATHS:
# A list of full file paths to target for launchd unload and removal.
# Leave off trailing slashes from directory paths.
#
# If no files need to be manually deleted, comment these array values out.
resourceFiles=(
  "$5" # Jamf Pro script parameter: "App File Path"; should be full path to the application, e.g. "/System/Applications/Chess.app"
)



########## function-ing ##########



# Exit if any required Jamf Pro arguments are undefined.
check_jamf_pro_arguments () {
  jamfProArguments=(
    "${processNames[0]}"
    "${resourceFiles[0]}"
  )
  for argument in "${jamfProArguments[@]}"; do
    if [ -z "$argument" ]; then
      echo "❌ ERROR: Undefined Jamf Pro argument, unable to proceed."
      exit 74
    fi
  done
}


# Run vendor uninstaller Bash scripts.
run_vendor_uninstaller_scripts () {
  for vendorUninstaller in "${vendorUninstallerBashScripts[@]}"; do
    bash "${vendorUninstaller}"
  done
}


# Quit target processes and remove associated login items.
quit_processes () {
  for process in "${processNames[@]}"; do
    if echo "$currentProcesses" | /usr/bin/grep -q "$process"; then
      /bin/launchctl asuser "$loggedInUserUID" /usr/bin/osascript -e "tell application \"$process\" to quit"
      /usr/bin/osascript -e "tell application \"System Events\" to delete every login item whose name is \"$process\""
      echo "Quit $process, removed from login items if present."
    else
      echo "$process not running."
    fi
  done
}


# Remove all remaining resource files.
delete_files () {
  for targetFile in "${resourceFiles[@]}"; do
    # Check if file exists.
    if [ -e "$targetFile" ]; then
      # Check if file is a plist.
      if echo "$targetFile" | /usr/bin/grep -q ".plist"; then
        # If plist is loaded as LaunchAgent or LaunchDaemon, unload it.
        justThePlist=$(/usr/bin/basename "$targetFile" | /usr/bin/awk -F.plist '{print $1}')
        if echo "$launchAgentCheck" | /usr/bin/grep -q "$justThePlist"; then
          /bin/launchctl asuser "$loggedInUserUID" /bin/launchctl unload "$targetFile"
          echo "Unloaded LaunchAgent at $targetFile."
        elif echo "$launchDaemonCheck" | /usr/bin/grep -q "$justThePlist"; then
          /bin/launchctl unload "$targetFile"
          echo "Unloaded LaunchDaemon at $targetFile."
        fi
      fi
      # Remove system immutable flag if present.
      if /bin/ls -ldO "$targetFile" | /usr/bin/awk '{print $5}' | /usr/bin/grep -q "schg"; then
        /usr/bin/chflags -R noschg "$targetFile"
        echo "Removed system immutable flag for $targetFile."
      fi
      # Move all files to /tmp/$scriptName.
      tmpKillPath="/tmp/$scriptName"
      /bin/mkdir -p "$tmpKillPath"
      /bin/mv "$targetFile" "$tmpKillPath/"
      echo "Moved $targetFile to $tmpKillPath. File will be deleted on subsequent restart."
    fi
  done
}



########## main process ##########



# Exit if any required Jamf Pro arguments are undefined.
check_jamf_pro_arguments


# Each function will only execute if the respective source array is not empty
# or undefined.
if [[ -n "${vendorUninstallerBashScripts[*]}" ]]; then
  echo "Running vendor uninstaller Bash scripts..."
  run_vendor_uninstaller_scripts
fi


if [[ -n "${processNames[*]}" ]]; then
  echo "Quitting processes (if running)..."
  quit_processes
fi


if [[ -n "${resourceFiles[*]}" ]]; then
  echo "Removing files (if present)..."
  delete_files
fi



exit 0
