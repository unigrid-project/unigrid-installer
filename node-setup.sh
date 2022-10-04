
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

BASE_NAME='ugd_docker_'
SERVER_NAME=''

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
docker run -it --name="${SERVER_NAME}" --mount source=data-volume_1,destination=/root/.unigrid unigrid/unigrid:beta
else
SERVER_NAME=$(docker ps -a --no-trunc --format '{{.Names}}')
echo ${SERVER_NAME}
A="$(echo ${SERVER_NAME} | cut -d'_' -f3)"
B="$(($A + 1))"
echo ${BASE_NAME}${B}
echo "Copy Volume and run"
docker run --rm \
           -i \
           -d \
           -t \
           -v data-volume:/from \
           -v data-volume4:/to \
           alpine ash -c "cd /from ; cp -av . /to"
echo "Done copying volume"
docker run -it -d --name="${SERVER_NAME}" --mount source=data-volume4,destination=/root/.unigrid unigrid/unigrid:beta
fi

CURRENT_CONTAINER_ID=$( echo `sudo docker ps -aqf name="${SERVER_NAME}"` )
echo "${CURRENT_CONTAINER_ID}"
docker start "${CURRENT_CONTAINER_ID}"
echo "Starting ${CURRENT_CONTAINER_ID}"
docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service start

docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount

# sudo groupadd docker
# CURRENT_USER=$(whoami)
# echo ${CURRENT_USER}
# sudo usermod -a -G docker ${CURRENT_USER}
# sudo chown "$CURRENT_USER":"$CURRENT_USER" /home/"$CURRENT_USER"/.docker -R
# sudo chmod g+rwx "$CURRENT_USER/.docker" -R
echo
echo "Completed Docker Install Script"