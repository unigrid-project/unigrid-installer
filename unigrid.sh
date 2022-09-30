#!/bin/bash
# shellcheck disable=SC2034
# Copyright © 2021-2022 The Unigrid Foundation, UGD Software AB

# This program is free software: you can redistribute it and/or modify it under the terms of the
# addended GNU Affero General Public License as published by the Free Software Foundation, version 3
# of the License (see COPYING and COPYING.addendum).

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.

# You should have received an addended copy of the GNU Affero General Public License with this program.
# If not, see <http://www.gnu.org/licenses/> and <https://github.com/unigrid-project/unigrid-installer>.

: '
# Run this file

```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/unigrid.sh)" ; source ~/.bashrc
```

'

# Github user and project.
INSTALLER_REPO='unigrid-project/unigrid-installer'
DAEMON_REPO='unigrid-project/daemon'
HEDGEHOD_REPO=''
GROUNDHOG_REPO='unigrid-project/groundhog'
# GitHub Auth Token
AUTH_TOKEN='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'
# Set username
USER_NAME='unigrid'
# Display Name.
DAEMON_NAME='UNIGRID'
# Coin Ticker.
TICKER='UGD'
# Binary base name.
BIN_BASE='unigrid'
GROUNDHOG_BASE='groundhog.jar'
# Direct Daemon Download if github has no releases.
#DAEMON_DOWNLOAD='https://github.com/unigrid-project/daemon/releases/download/v2.9.3/unigrid-2.9.3-x86_64-linux-gnu.tar.gz'
DAEMON_DOWNLOAD=''
# Direct groundhog Download if github has no releases.
#GROUNDHOG_DOWNLOAD='https://github.com/unigrid-project/groundhog/releases/download/v0.0.1/groundhog-0.0.1-SNAPSHOT-jar-with-dependencies.jar'
GROUNDHOG_DOWNLOAD=''
# Directory.
DIRECTORY='.unigrid'
# Conf File.
CONF='unigrid.conf'
# Port.
DEFAULT_PORT=51992
# Explorer URL.
EXPLORER_URL='http://explorer.unigrid.org/'
# Rate limit explorer.
EXPLORER_SLEEP=1
# Amount of Collateral needed.
COLLATERAL=3000
# Blocktime in seconds.
BLOCKTIME=60
# Multiple on single IP.
MULTI_IP_MODE=0
# Home directory
USR_HOME="/home/${USER_NAME}"

ASCII_ART () {
echo -e "\e[0m"
clear 2> /dev/null
cat << "UNIGRID"
 _   _ _   _ ___ ____ ____  ___ ____
| | | | \ | |_ _/ ___|  _ \|_ _|  _ \
| | | |  \| || | |  _| |_) || || | | |
| |_| | |\  || | |_| |  _ < | || |_| |
 \___/|_| \_|___\____|_| \_\___|____/

UNIGRID
}

cd ~/ || exit
COUNTER=0
rm -f ~/___ugd.sh
while [[ ! -f ~/___ugd.sh ]] || [[ $( grep -Fxc "# End of setup script." ~/___ugd.sh ) -eq 0 ]]
do
  rm -f ~/___ugd.sh
  echo "Downloading Unigrid Setup Script."
  wget -4qo- https://raw.githubusercontent.com/unigrid-project/unigrid-installer/main/setup.sh -O ~/___ugd.sh
  COUNTER=1
  if [[ "${COUNTER}" -gt 3 ]]
  then
    echo
    echo "Download of setup script failed."
    echo
    exit 1
  fi
done

(
  sleep 2
  rm ~/___ugd.sh
) & disown

(
# shellcheck disable=SC1091
# shellcheck source=/root/___ugd.sh
. ~/___ugd.sh
UNIGRID_SETUP_THREAD
)
# shellcheck source=/root/.bashrc
. ~/.bashrc
stty sane 2>/dev/null

