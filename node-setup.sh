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
sudo bash -c "$(wget -4qO- -o- https://raw.githubusercontent.com/unigrid-project/unigrid-installer/main/node-setup.sh)" 'source ~/.bashrc'
```
'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BASE_NAME='ugd_docker_'
SERVER_NAME=''
DATA_VOLUME='data_volume_'
NUMBERS_ARRAY=()
NODE_NUMBER=''
SP="/-\\|"
# setting a default name here
NEW_SERVER_NAME='ugd_docker_1'

INSTALL_DOCKER() {
    if [ ! -x "$(command -v docker)" ]; then
        echo -e "${CYAN}Starting Docker Instll Script"
        bash <(wget -qO- https://raw.githubusercontent.com/docker/docker-install/master/install.sh)
        sudo chmod 666 /var/run/docker.sock
        sudo groupadd docker
        CURRENT_USER=$(whoami)
        echo ${CURRENT_USER}
        sudo usermod -a -G docker ${CURRENT_USER}
        echo -e "${CYAN}Completed Docker Install"
    else
        echo -e "${CYAN}Docker already installed"
    fi
}

CHECK_FOR_NODE_INSTALL() {
    CHECK_NODE="$( docker ps -f name=ugd_docker_1 | grep -w ugd_docker_1 )"
    echo "ugd_docker_1: ${CHECK_NODE}"
    if [ -z  "${CHECK_NODE}" ]; then
        echo -e "${GREEN}Clean install docker image"
        docker run -it -d --name="${BASE_NAME}1" \
            --mount source="${DATA_VOLUME}1",destination=/root/.unigrid \
            --restart unless-stopped \
            unigrid/unigrid:beta
    else
        echo -e "${CYAN}1st node already installed"
        INSTALL_NEW_NODE
    fi
    # Get all of the images names
    SERVER_NAME=$(docker ps -a --no-trunc --format '{{.Names}}')
    #DOCKERS=""
    DOCKERS=${SERVER_NAME}
    ARRAY=($(echo ${DOCKERS}))
    eval "ARR=($ARRAY)"

    if [ "${#ARR[@]}" = "0" ]; then
        DOCKERS="${BASE_NAME}0"
        ARRAY=($(echo ${DOCKERS}))
    fi
}


INSTALL_NEW_NODE() {

    #NUMBERS_ARRAY=("ugd_docker_0")

    NUMBERS_ARRAY=($(printf "%s\n" "${NUMBERS_ARRAY[@]}" | sort -n))
    if [ ${#NUMBERS_ARRAY[@]} = "0" ]; then
        ARRAY_LENGTH='1'
    else
        ARRAY_LENGTH="${#NUMBERS_ARRAY[@]}"
    fi
    echo ${ARRAY_LENGTH}
    LAST_DOCKER_NUMBER=${NUMBERS_ARRAY[$((${ARRAY_LENGTH} - 1))]}
    NODE_NUMBER="$(($LAST_DOCKER_NUMBER + 1))"

    ######### GET HIGHEST NUMBER IN THE ARRAY FOR IMAGES ##########

    NEW_SERVER_NAME=${BASE_NAME}${NODE_NUMBER}
    NEW_VOLUME_NAME=${DATA_VOLUME}${NODE_NUMBER}
    echo ${NEW_VOLUME_NAME}

    echo "Copy Volume and run"
    docker run --rm \
        -i \
        -d \
        -t \
        -v ${DATA_VOLUME}1:/from \
        -v ${DATA_VOLUME}${NODE_NUMBER}:/to \
        alpine ash -c "cd /from ; cp -av . /to"
    echo "Done copying volume"
    docker run -it -d --name="${NEW_SERVER_NAME}" \
        --mount source=${NEW_VOLUME_NAME},destination=/root/.unigrid \
        --restart unless-stopped \
        unigrid/unigrid:beta # /usr/local/bin/ugd_service start

}

INSTALL_WATCHTOWER() {
    # Run watchtower if not found
    CHECK_WATCHTOWER="$( docker ps -f name=watchtower | grep -w watchtower )"
     if [ -z  "${CHECK_WATCHTOWER}" ]; then
        echo -e "${GREEN}Installing watchtower"
        docker run -d \
            --name watchtower \
            -v /var/run/docker.sock:/var/run/docker.sock \
            containrrr/watchtower --debug -c \
            --trace --include-restarting --interval 30
    else
        echo -e "${CYAN}Watchtower already intalled... skipping"
    fi
}

INSTALL_COMPLETE() {
    CURRENT_CONTAINER_ID=$(echo $(sudo docker ps -aqf name="${NEW_SERVER_NAME}"))
    echo "${CURRENT_CONTAINER_ID}"
    docker start "${CURRENT_CONTAINER_ID}"
    echo e "${GREEN}Starting ${CURRENT_CONTAINER_ID}"
    #docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service start

    #sleep 1.5

    #docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getinfo
    sleep 1
    # docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount

    # FOR LOOP TO CHECK CHAIN IS SYNCED
    BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount)
    sleep 0.5
    while [[ "$BLOCK_COUNT" = "-1" ]]; do
        BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount)
        sleep 0.1
        BOOT_STRAPPING=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getbootstrappinginfo)
        sleep 0.1
        echo -en "\r${GREEN}${SP:i++%${#SP}:1} Waiting for wallet to sync... ${BOOT_STRAPPING}"
        #seq 1 1000000 | while read i; do echo -en "\r$i"; done
        stty sane 2>/dev/null
        sleep 5
    done
    echo -e "${GREEN}Unigrid daemon fully synced!"
    echo
    echo -e "${CYAN}Completed Docker Install Script."
    echo -e "${CYAN}Docker container ${CURRENT_CONTAINER_ID} has started!"
    echo -e "${CYAN}To call the unigrid daemon use..."
    echo
    echo -e "${GREEN}docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid help"
    echo
    echo -e "${CYAN}To access the container you can type..."
    echo
    echo -e "${GREEN}docker exec -it ${CURRENT_CONTAINER_ID} /bin/bash"
    echo
    echo -e "${CYAN}To see a full list of all containers use..."
    echo
    echo -e "${GREEN}docker ps"
    echo
    echo -e "${CYAN}For help"
    echo
    echo -e "${GREEN}docker --help"
    echo
    echo -e "${CYAN}If you would like to install another node simply run this script again."
    echo
}

#docker exec -i 788d300261d3 ugd_service status
#docker container exec -it 788d300261d3 /bin/bash

INSTALL_DOCKER

CHECK_FOR_NODE_INSTALL

INSTALL_WATCHTOWER

INSTALL_COMPLETE
