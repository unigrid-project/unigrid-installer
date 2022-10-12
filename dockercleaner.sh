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
bash -c "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/dockercleaner.sh)" 'source ~/.bashrc'
```

'

CYAN='\033[0;36m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'

ASCII_ART() {
    echo -e "${ORANGE}"
    clear 2>/dev/null
    cat <<"UNIGRID"
 _   _ _   _ ___ ____ ____  ___ ____
| | | | \ | |_ _/ ___|  _ \|_ _|  _ \
| | | |  \| || | |  _| |_) || || | | |
| |_| | |\  || | |_| |  _ < | || |_| |
 \___/|_| \_|___\____|_| \_\___|____/

Copyright © 2021-2022 The Unigrid Foundation, UGD Software AB 

UNIGRID
}

ASCII_ART

if [[ "${ASCII_ART}" ]]; then
    ${ASCII_ART}
fi

echo -e "${CYAN}Running Docker cleanup script..."

CONFIRM_RUN() {
    while true; do
        echo
        echo
        echo -e "${RED}Warning!"
        echo -e "Running this script will delete all Unigrid containers and volumes on this machine."
        echo -e "${CYAN}"
        read -p "Are you sure you want to run this script?" yn
        echo
        echo
        case $yn in
        [Yy]*)
            break
            continue
            ;;
        [Nn]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
}

FIND_DOCKER_IMAGES() {
    IMAGES=$(docker ps -a --no-trunc --format '{{.Names}}' | tr '\n' ' ')
    sleep 0.1
    declare -a ARR=($IMAGES)
    FILTERED_ARRAY=()
    for s in "${ARR[@]}"; do
        if [[ "${s:0:3}" = 'ugd' ]]; then
            echo -e "Found container name: ${s}"
            FILTERED_ARRAY+=("${s}")
        fi
    done
    echo -e "Remove containers ${FILTERED_ARRAY[@]}"
    docker rm "${FILTERED_ARRAY[@]}" --force
}

FIND_VOLUMES() {
    VOLUMES=$(docker volume ls | tr '\n' ' ')
    sleep 0.1
    declare -a ARR=($VOLUMES)
    FILTERED_ARRAY=()
    for s in "${ARR[@]}"; do
        if [[ "${s:0:11}" = 'data_volume' ]]; then
            echo -e "Found volume name: ${s}"
            FILTERED_ARRAY+=("${s}")
        fi
    done
    echo -e "Remove containers ${FILTERED_ARRAY[@]}"
    docker volume rm "${FILTERED_ARRAY[@]}"
}

CONFIRM_RUN
FIND_DOCKER_IMAGES
FIND_VOLUMES

echo -e "${GREEN}Completed removal of all Unigrid docker containers!"
echo
echo
