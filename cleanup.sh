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
sudo bash -c "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/cleanup.sh)" 'source ~/.bashrc' <USERNAME>
```

'

# Set username
if [[ ! -z "$1" ]]
then
USER_NAME="${1}"
else
USER_NAME='unigrid'
fi

ASCII_ART () {
echo -e "\e[0m"
clear 2> /dev/null
cat << "UNIGRID"
 _   _ _   _ ___ ____ ____  ___ ____
| | | | \ | |_ _/ ___|  _ \|_ _|  _ \
| | | |  \| || | |  _| |_) || || | | |
| |_| | |\  || | |_| |  _ < | || |_| |
 \___/|_| \_|___\____|_| \_\___|____/

UGD Software AB 2022

UNIGRID
}

CLEANUP_SYSTEMCTL() {
    echo "Removing ${USER_NAME} data files"
    systemctl stop "${USER_NAME}".service 
    systemctl disable "${USER_NAME}".service  
    rm /etc/systemd/system/"${USER_NAME}".service  
    systemctl daemon-reload 
    systemctl reset-failed
    echo "systemctl cleanup complete"
}

REMOVE_USER() {
    echo "Removing ${USER_NAME} from server"
    sudo userdel -r unigrid
}

ASCII_ART

if [[ "${ASCII_ART}" ]]
then
    ${ASCII_ART}
fi
CLEANUP_SYSTEMCTL
REMOVE_USER
echo "Completed cleanup"
stty sane 2>/dev/null
echo
sleep 0.1
# End of setup script.
