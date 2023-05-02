#!/bin/bash

###
#
#            Name:  uninstaller-template.sh
#     Description:  A template script to assist with the uninstallation of macOS products where the vendor has missing or incomplete removal solutions. Attempts vendor uninstall by running all provided uninstallation executables, quits all running target processes, unloads all associated launchd tasks, then removes all associated files.
#                   https://github.com/palantir/jamf-pro-scripts/tree/main/scripts/script-templates/uninstaller-template
#         Created:  2017-10-23
#   Last Modified:  2023-05-02
#         Version:  1.3.10
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



# ENVIRONMENT VARIABLES (leave as-is)
loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
# For any file paths used later in this script, use "$loggedInUserHome" for the current user's home folder path. Don't just assume the home folder is at /Users/${loggedInUser}.
# shellcheck disable=SC2034
loggedInUserHome=$(/usr/bin/dscl . -read "/Users/${loggedInUser}" NFSHomeDirectory | /usr/bin/awk '{print $NF}')
loggedInUserUID=$(/usr/bin/id -u "$loggedInUser")
currentProcesses=$(/bin/ps aux)
launchAgentCheck=$(/bin/launchctl asuser "$loggedInUserUID" /bin/launchctl list)
launchDaemonCheck=$(/bin/launchctl list)


# VENDOR UNINSTALLERS
# A list of file paths for vendor-provided uninstallation tools. Note that vendor uninstaller workflows may differ greatly. Some vendors may use their own command-line tools with custom flags or other workflows to accomplish this task (that's why this script exists!), so make any necessary changes to the below commands if the uninstallation workflow isn't simply calling executable files. If the vendor did not provide an uninstaller workflow, comment these array values out.
vendorUninstallers=(
  "/path/to/vendor_uninstaller_command1.sh"
  "/path/to/vendor_uninstaller_command2.sh"
)


# PROCESSES
# A list of application processes to target for quitting. Names should match what is displayed for the process in Activity Monitor (e.g. "Chess", not "Chess.app"). If no processes need to be quit, comment these array values out.
processNames=(
  "Process Name 1"
  "Process Name 2"
)


# FILE PATHS
# A list of full file paths to target for launchd unload and removal. Leave off trailing slashes from directory paths. If no files need to be manually deleted, comment these array values out.
resourceFiles=(
  "/path/to/file1"
  "/path/to/file2"
)



########## function-ing ##########



# Runs vendor uninstallers.
run_vendor_uninstallers () {
  for uninstaller in "${vendorUninstallers[@]}"; do
    if [[ -e "$uninstaller" ]]; then
      ./"${uninstaller}"
    else
      echo "Vendor uninstaller not found at ${uninstaller}."
    fi
  done
}


# Quits target processes.
quit_processes () {
  for process in "${processNames[@]}"; do
    if echo "$currentProcesses" | /usr/bin/grep -q "$process"; then
      /bin/launchctl asuser "$loggedInUserUID" /usr/bin/osascript -e "tell application \"${process}\" to quit"
      echo "Quit ${process}."
    fi
  done
}


# Removes all remaining resource files.
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
          echo "Unloaded LaunchAgent at ${targetFile}."
        elif echo "$launchDaemonCheck" | /usr/bin/grep -q "$justThePlist"; then
          /bin/launchctl unload "$targetFile"
          echo "Unloaded LaunchDaemon at ${targetFile}."
        fi
      fi
      # Remove system immutable flag if present.
      if /bin/ls -ldO "$targetFile" | /usr/bin/awk '{print $5}' | /usr/bin/grep -q "schg"; then
        /usr/bin/chflags -R noschg "$targetFile"
        echo "Removed system immutable flag for ${targetFile}."
      fi
      # Remove file.
      /bin/rm -rf "$targetFile"
      echo "Removed ${targetFile}."
    fi
  done
}



########## main process ##########



# Each function will only execute if the respective source array is not empty or undefined.
if [[ -n "${vendorUninstallers[*]}" ]]; then
  echo "Running vendor uninstallers..."
  run_vendor_uninstallers
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
