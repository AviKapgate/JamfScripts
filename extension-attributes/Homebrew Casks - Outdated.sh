#!/bin/sh

###
#
#            Name:  Homebrew Casks - Outdated.sh
#     Description:  Returns list of Homebrew-installed casks with pending
#                   updates (if Homebrew is installed). Runs as currently
#                   logged-in user to avoid running in root context.
#         Created:  2021-04-01
#   Last Modified:  2022-03-29
#         Version:  1.0.1.1
#
#
# Copyright 2021 Palantir Technologies, Inc.
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



loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
# Determine Homebrew directory based on platform architecture,
# use to define Homebrew binary paths.
architectureCheck=$(/usr/bin/arch)
if [ "$architectureCheck" = "arm64" ]; then
  brewPrefix="/opt/homebrew/bin"
else
  brewPrefix="/usr/local/bin"
fi
brewPath="${brewPrefix}/brew"
brewOutdatedCask=""



########## main process ##########



# Check for presence of Homebrew and get list of outdated casks.
if [ -e "$brewPath" ]; then
  brewOutdatedCask=$(sudo -u "$loggedInUser" "$brewPath" outdated --cask --quiet 2>&1)
fi


# Report result.
echo "<result>${brewOutdatedCask}</result>"



exit 0
