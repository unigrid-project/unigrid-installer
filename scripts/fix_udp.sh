#!/bin/bash
# shellcheck disable=SC2034
# Copyright © 2021-2023 The Unigrid Foundation, UGD Software AB

# This program is free software: you can redistribute it and/or modify it under the terms of the
# addended GNU Affero General Public License as published by the Free Software Foundation, version 3
# of the License (see COPYING and COPYING.addendum).

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.

# You should have received an addended copy of the GNU Affero General Public License with this program.
# If not, see <http://www.gnu.org/licenses/> and <https://github.com/unigrid-project/unigrid-installer>.

ORANGE='\033[0;33m'
CYAN='\033[0;36m'
BLUE="\033[1;34m"
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[0;37m'
NC='\033[0m'
PORT_TXT='port.txt'
USR_HOME='/root'
DIRECTORY='.unigrid'
CONF_FILE='unigrid.conf'
DAY_ARRAY=(43200 86400 172800)

ASCII_ART() {
    echo -e "${ORANGE}"
    clear 2>/dev/null
    cat <<"UNIGRID"
 _   _ _   _ ___ ____ ____  ___ ____
| | | | \ | |_ _/ ___|  _ \|_ _|  _ \
| | | |  \| || | |  _| |_) || || | | |
| |_| | |\  || | |_| |  _ < | || |_| |
 \___/|_| \_|___\____|_| \_\___|____/

Copyright © 2021-2023 The Unigrid Foundation, UGD Software AB 

UNIGRID
}

ASCII_ART

if [[ "${ASCII_ART}" ]]; then
    ${ASCII_ART}
fi

echo -e "${NC}"

FIND_FREE_UDP_PORT() {
    # Define the range of ports to check
    LOWERPORT=32769
    UPPERPORT=60998

    # Extract the list of used ports from the UFW rules
    USED_PORTS=$(sudo ufw status verbose | grep '/udp' | awk '{print $1}' | cut -d '/' -f1)

    # Loop until we find an unused port
    while :; do
        # Generate a random port number in the range
        PORT_TO_TEST=$(shuf -i "${LOWERPORT}"-"${UPPERPORT}" -n 1)

        # Check if the port is in the list of used ports
        if ! echo "${USED_PORTS}" | grep -q "^${PORT_TO_TEST}$"; then
            # If the port is not in the list of used ports, add it to UFW rules
            sudo ufw allow "${PORT_TO_TEST}"/udp >/dev/null
            # Print the port number and return
            echo "${PORT_TO_TEST}"
            return
        fi
    done
}

CREATE_PORT_TXT() {
    PORT_UDP=${1}
    NEW_SERVER_NAME=${2}
    echo "Creating port.txt in ${NEW_SERVER_NAME} with port ${PORT_UDP}"
    docker exec "${NEW_SERVER_NAME}" bash -c "echo ${PORT_UDP} > /root/.unigrid/port.txt"
}

REMOVE_RPC_LINES() {
    NEW_SERVER_NAME=${1}
    RPC_FILE="${USR_HOME}/${DIRECTORY}/${CONF_FILE}"
    echo "Removing rpcport and rpcbind lines from ${RPC_FILE} in ${NEW_SERVER_NAME}"
    docker exec "${NEW_SERVER_NAME}" sed -i "/^rpcport=/d" "${RPC_FILE}"
    docker exec "${NEW_SERVER_NAME}" sed -i "/^rpcbind=/d" "${RPC_FILE}"
    docker exec "${NEW_SERVER_NAME}" sed -i "/^rpcallowip=/d" "${RPC_FILE}"
}

# Get a list of all running Docker containers
containers=$(docker ps --format '{{.Names}}')
echo -e "${ORANGE}Searching for containers matching the pattern ugd_docker_*..."

# Loop over the containers
for container in $containers; do
    echo -e "${CYAN}Checking container ${container}..."
    # Check if the container name matches the naming convention
    if [[ $container == ugd_docker_* ]]; then
        REMOVE_RPC_LINES "${container}"
        # Get the image of the container
        image=$(docker inspect -f '{{.Config.Image}}' $container)

        # Get the volumes of the container
        volumes=$(docker inspect -f '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' $container)

        # Get the TCP ports of the container
        ports=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} {{end}}' $container)

        # Build the -v options for docker run
        volumes_opts=""
        for volume in $volumes; do
            volumes_opts="$volumes_opts -v $volume"
        done

        # Build the -p options for docker run
        ports_opts=""
        udp_port_added=false
        for port in $ports; do
            if [[ $port == *"/udp" ]]; then
                # Ignore UDP ports, as we will be adding a new UDP port later
                continue
            fi
            # Extract the TCP port number from the port string
            tcp_port=${port%/*}
            # Add the TCP port to the ports_opts string
            ports_opts="$ports_opts -p $tcp_port"
        done

        # Find a free UDP port and add it to the ports_opts string
        if ! $udp_port_added; then
            PORT_UDP=$(FIND_FREE_UDP_PORT)
            CREATE_PORT_TXT "${PORT_UDP}" "${container}"
            ports_opts="$ports_opts -p ${PORT_UDP}:${PORT_UDP}/udp"
            udp_port_added=true
        fi

        echo -e "${BLUE}ports_opts: $ports_opts"
        echo -e "volumes_opts: $volumes_opts"
        echo -e "image: $image"
        echo -e "container: $container"

        # Stop and remove the container
        echo -e "Stopping container $container"
        docker stop $container
        echo -e "Removing container $container"
        docker rm $container

        # Run a new container with the same settings plus the additional UDP port binding
        docker run -d --name $container $volumes_opts $ports_opts $image

        echo -e "${GREEN}Successfully updated container ${container} to use UDP port ${PORT_UDP}!"
        echo -e "${NC}"
    fi
done

SET_RANDOM_UPDATE_TIME() {
    # sets interval for watchtower to check for updates
    # either 0, 1, or 2 days
    RANDOM_NUMBER=$(((RANDOM % 3)))
    DAY_INTERVAL="${DAY_ARRAY[RANDOM_NUMBER]}"
    #echo "${RANDOM_NUMBER}"
    echo "watchtower check for update interval: ${DAY_INTERVAL}"
}

UPDATE_WATCHTOWER() {
    # Check if watchtower container exists (running or stopped)
    CHECK_WATCHTOWER="$(docker ps -a -f name=watchtower | grep -w watchtower)"
    sleep 0.1
    if [ -n "${CHECK_WATCHTOWER}" ]; then
        echo -e "${CYAN}Watchtower already installed... updating"
        # Stop the existing watchtower container if it's running
        docker stop watchtower
        # Remove the existing watchtower container
        docker rm watchtower
    fi
    SET_RANDOM_UPDATE_TIME
    echo -e "${GREEN}Installing/Updating watchtower"
    # Run a new Watchtower container
    docker run -d \
        --name watchtower \
        -v /var/run/docker.sock:/var/run/docker.sock \
        containrrr/watchtower -c \
        --enable-lifecycle-hooks \
        --trace --include-restarting --interval "${DAY_INTERVAL}"
    echo -e "${GREEN}Successfully installed/updated watchtower!"
    echo -e "${NC}"
}

UPDATE_WATCHTOWER

# End of fix_udp script.
