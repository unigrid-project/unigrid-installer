
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


BASE_NAME='ugd_docker_'
SERVER_NAME=''
DATA_VOLUME='data_volume_'

echo "Starting Docker Instll Script"

if [ ! -x "$( command -v docker )" ]
then
bash <(wget -qO- https://raw.githubusercontent.com/docker/docker-install/master/install.sh)
sudo chmod 666 /var/run/docker.sock
sudo groupadd docker
CURRENT_USER=$(whoami)
echo ${CURRENT_USER}
sudo usermod -a -G docker ${CURRENT_USER}
echo "Complete Docker Install"
fi

if [ ! -x '$( docker ps -a --no-trunc --format "{{.Mounts}}" )' ]
then
SERVER_NAME="${BASE_NAME}1"
docker run -it -d --name="${SERVER_NAME}" --mount source="${DATA_VOLUME}1",destination=/root/.unigrid unigrid/unigrid:beta
else
# Get all of the images names
SERVER_NAME=$(docker ps -a --no-trunc --format '{{.Names}}')
# array from string
# DOCKERS="ugd_docker_1 ugd_docker_2 ugd_docker_3"
DOCKERS=${SERVER_NAME}
ARRAY=(`echo ${DOCKERS}`);
echo ${#ARRAY[@]}
ARRAY_LENGTH="$(echo ${#ARRAY[@]})"
LAST_DOCKER_NAME=${ARRAY[$((${ARRAY_LENGTH}-1))]}
echo ${LAST_DOCKER_NAME}
# split the string by _ and get the #
A="$(echo ${LAST_DOCKER_NAME} | cut -d'_' -f3)"
B="$(($A + 1))"
NEW_SERVER_NAME=${BASE_NAME}${B}

# Get all of the volumes names
VOLUME_NAMES=$(docker ps -a --no-trunc --format '{{.Mounts}}')
VOLUME_ARRAY=(`echo ${VOLUME_NAMES}`);
echo ${VOLUME_ARRAY}
ARRAY_LENGTH="$(echo ${#VOLUME_ARRAY[@]})"
LAST_VOLUME_NAME=${VOLUME_ARRAY[$((${ARRAY_LENGTH}-1))]}
echo ${LAST_VOLUME_NAME}
# split the string by _ and get the #
A="$(echo ${LAST_DOCKER_NAME} | cut -d'_' -f3)"
B="$(($A + 1))"
NEW_VOLUME_NAME=${DATA_VOLUME}${B}

echo "Copy Volume and run"
docker run --rm \
           -i \
           -d \
           -t \
           -v data-volume:/from \
           -v data-volume4:/to \
           alpine ash -c "cd /from ; cp -av . /to"
echo "Done copying volume"
docker run -it -d --name="${NEW_SERVER_NAME}" --mount source=${NEW_VOLUME_NAME},destination=/root/.unigrid unigrid/unigrid:beta
fi

CURRENT_CONTAINER_ID=$( echo `sudo docker ps -aqf name="${SERVER_NAME}"` )
echo "${CURRENT_CONTAINER_ID}"
docker start "${CURRENT_CONTAINER_ID}"
echo "Starting ${CURRENT_CONTAINER_ID}"
docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service start

sleep 1.5

docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getinfo
sleep 1
docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount

# sudo groupadd docker
# CURRENT_USER=$(whoami)
# echo ${CURRENT_USER}
# sudo usermod -a -G docker ${CURRENT_USER}
# sudo chown "$CURRENT_USER":"$CURRENT_USER" /home/"$CURRENT_USER"/.docker -R
# sudo chmod g+rwx "$CURRENT_USER/.docker" -R
echo
echo "Completed Docker Install Script."
echo "Docker container ${CURRENT_CONTAINER_ID} has started!"
echo "To call the unigrid daemon use..."
echo "docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid help"
echo "To access the container you can type..."
echo "docker exec -it ${CURRENT_CONTAINER_ID} /bin/bash"
echo "To see a full list of all containers use..."
echo "docker ps"
echo "For help"
echo "docker --help"
echo "If you would like to install another node simply run this script again."
echo