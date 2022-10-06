
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
WATCHTOWER_INSTALLED=true

echo "Starting Docker Instll Script"


if [ ! -x "$( command -v docker )" ]
then
bash <(wget -qO- https://raw.githubusercontent.com/docker/docker-install/master/install.sh)
sudo chmod 666 /var/run/docker.sock
sudo groupadd docker
CURRENT_USER=$(whoami)
echo ${CURRENT_USER}
sudo usermod -a -G docker ${CURRENT_USER}
echo "Completed Docker Install"
fi

if [ -x '$( docker ps -a --no-trunc --format "{{.Mounts}}" )' ]
then
echo "${GREEN}Clean install docker image"
SERVER_NAME="${BASE_NAME}1"
docker run -it -d --name="${SERVER_NAME}" --mount source="${DATA_VOLUME}1",destination=/root/.unigrid unigrid/unigrid:beta
else
# Get all of the images names
SERVER_NAME=$(docker ps -a --no-trunc --format '{{.Names}}')
#DOCKERS=""
DOCKERS=${SERVER_NAME}
ARRAY=(`echo ${DOCKERS}`);
eval "ARR=($ARRAY)"

if [ "${#ARR[@]}" = "0" ]; then
DOCKERS="${BASE_NAME}0"
ARRAY=(`echo ${DOCKERS}`);
fi

for s in "${ARR[@]}"; do
    if [[ "$s" = 'watchtower' ]] 
    then
        WATCHTOWER_INSTALLED=true
    else
        WATCHTOWER_INSTALLED=false 
    fi
    ITEM="$(echo ${s} | cut -d'_' -f3)"
    NUMBERS_ARRAY+=( "$ITEM" )
done

# Run watchtower if not found
if [ "$WATCHTOWER_INSTALLED" = true ] ; then
    echo "${GREEN}Installing watchtower"
    docker run -d \
        --name watchtower \
        -v /var/run/docker.sock:/var/run/docker.sock \
        containrrr/watchtower --debug -c \
        --trace --include-restarting --interval 30
fi

#NUMBERS_ARRAY=("ugd_docker_0")

NUMBERS_ARRAY=( $( printf "%s\n" "${NUMBERS_ARRAY[@]}" | sort -n ) )
ARRAY_LENGTH="${#NUMBERS_ARRAY[@]}"
echo ${ARRAY_LENGTH}
LAST_DOCKER_NUMBER=${NUMBERS_ARRAY[$((${ARRAY_LENGTH}-1))]}
B="$(($LAST_DOCKER_NUMBER + 1))"

######### GET HIGHEST NUMBER IN THE ARRAY FOR IMAGES ##########


NEW_SERVER_NAME=${BASE_NAME}${B}
# Get all of the volumes names
VOLUME_NAMES=$(docker ps -a --no-trunc --format '{{.Mounts}}')
VOLUME_ARRAY=(`echo ${VOLUME_NAMES}`);

######### GET HIGHEST NUMBER IN THE ARRAY FOR VOLUMES ##########
eval "ARR=($VOLUME_ARRAY)"
if [ "${#ARR[@]}" = "0" ]; then
VOLUME_NAMES="${BASE_NAME}0"
VOLUME_ARRAY=(`echo ${VOLUME_NAMES}`);
fi


for s in "${ARR[@]}"; do 
    ITEM="$(echo ${s} | cut -d'_' -f3)"
    NUMBERS_ARRAY+=( "$ITEM" )
done
NUMBERS_ARRAY=( $( printf "%s\n" "${NUMBERS_ARRAY[@]}" | sort -n ) )
ARRAY_LENGTH="${#NUMBERS_ARRAY[@]}"
LAST_VOLUME_NUMBER=${NUMBERS_ARRAY[$((${ARRAY_LENGTH}-1))]}

######### GET HIGHEST NUMBER IN THE ARRAY FOR VOLUMES ##########

B="$(($LAST_VOLUME_NUMBER + 1))"
NEW_VOLUME_NAME=${DATA_VOLUME}${B}
echo ${NEW_VOLUME_NAME}

echo "Copy Volume and run"
docker run --rm \
           -i \
           -d \
           -t \
           -v ${DATA_VOLUME}1:/from \
           -v ${DATA_VOLUME}${B}:/to \
           alpine ash -c "cd /from ; cp -av . /to"
echo "Done copying volume"
docker run -it -d --name="${NEW_SERVER_NAME}" \
    --mount source=${NEW_VOLUME_NAME},destination=/root/.unigrid \
    --restart unless-stopped \
    unigrid/unigrid:beta # /usr/local/bin/ugd_service start
fi

CURRENT_CONTAINER_ID=$( echo `sudo docker ps -aqf name="${NEW_SERVER_NAME}"` )
echo "${CURRENT_CONTAINER_ID}"
docker start "${CURRENT_CONTAINER_ID}"
echo "Starting ${CURRENT_CONTAINER_ID}"
docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service start

sleep 1.5

docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getinfo
sleep 1
# docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount

# FOR LOOP TO CHECK CHAIN IS SYNCED
BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount)
sleep 0.5
while [[ "$BLOCK_COUNT" = "-1" ]]
do
    BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount)
    echo "Block count: ${BLOCK_COUNT}"
    sleep 5
done
echo -e "${GREEN}Unigrid daemon fully synced!"

#docker exec -i 788d300261d3 ugd_service status
#docker container exec -it 788d300261d3 /bin/bash

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