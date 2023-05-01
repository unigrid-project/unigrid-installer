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

if [[ "${IMAGE_SOURCE}" ]]; then
    echo "IMAGE_SOURCE: ${IMAGE_SOURCE}"
fi
EXPLORER_URL='http://explorer.unigrid.org/'
EXPLORER_RAWTRANSACTION_PATH='api/getrawtransaction?txid='
PATH_SUFFIX='&decrypt=1'
COLLATERAL=3000
COLLATERAL_NEW=2000
SSL_BYPASS=''
CYAN='\033[0;36m'
BLUE="\033[1;34m"
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[0;37m'
NC='\033[0m'
BASE_NAME='ugd_docker_'
SERVER_NAME=''
DATA_VOLUME='data_volume_'
NUMBERS_ARRAY=()
NODE_NUMBER=''
SP="/-\\|"
# setting a default name here
NEW_SERVER_NAME='ugd_docker_1'
CAN_SUDO=0
TXID=()
TX_DETAILS=()
USR_HOME='/root'
DIRECTORY='.unigrid'
CONF='unigrid.conf'
PORTA='0'
PORTB='0'
CURRENT_CONTAINER_ID=''
PRIVATEADDRESS=127.0.0.1
# Regex to check if output is a number.
RE='^[0-9]+$'
GN_KEY=''
DAY_ARRAY=(86400 172800 259200)
DAY_INTERVAL=''
TESTNET=""

ASCII_ART

if [[ "${ASCII_ART}" ]]; then
    ${ASCII_ART}
fi

PRE_INSTALL_CHECK() {
    # Check for sudo
    # Check for bash
    echo -e "${CYAN}Pre-install check"
    # Only run if user has sudo.
    sudo true >/dev/null 2>&1
    USER_NAME_CURRENT=$(whoami)
    CAN_SUDO=$(timeout --foreground --signal=SIGKILL 1s bash -c "sudo -l 2>/dev/null | grep -v '${USER_NAME_CURRENT}' | wc -l ")

    if [[ ${CAN_SUDO} =~ ${RE} ]] && [[ "${CAN_SUDO}" -gt 2 ]]; then
        :
    else
        echo "Script must be run as a user with no password sudo privileges"
        echo "To switch to the root user type"
        echo
        echo "sudo su"
        echo
        echo "And then re-run this command."
        return 1 2>/dev/null || exit 1
    fi

    if [ ! -x "$(command -v jq)" ] ||
        [ ! -x "$(command -v ufw)" ] ||
        [ ! -x "$(command -v dig)" ] ||
        [ ! -x "$(command -v pwgen)" ]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
            jq \
            ufw \
            pwgen \
            dnsutils
    fi

    # Setup UFW
    # Turn on firewall, allow ssh port first; default is 22.
    SSH_PORT=22
    SSH_PORT_SETTING=$(sudo grep -E '^Port [0-9]*' /etc/ssh/ssh_config | grep -o '[0-9]*' | head -n 1)
    if [[ ! -z "${SSH_PORT_SETTING}" ]] && [[ $SSH_PORT_SETTING =~ $RE ]]; then
        sudo ufw allow "${SSH_PORT_SETTING}" >/dev/null 2>&1
    else
        sudo ufw allow "${SSH_PORT}" >/dev/null 2>&1
    fi
    if [[ -f "${HOME}/.ssh/config" ]]; then
        SSH_PORT_SETTING=$(grep -E '^Port [0-9]*' "${HOME}/.ssh/config" | grep -o '[0-9]*' | head -n 1)
        if [[ ! -z "${SSH_PORT_SETTING}" ]] && [[ $SSH_PORT_SETTING =~ $RE ]]; then
            sudo ufw allow "${SSH_PORT_SETTING}" >/dev/null 2>&1
        fi
    fi
    while [[ -z "${PORTB}" || "${PORTB}" = "0" ]]; do
        PORTB=$(FIND_FREE_PORT "${PRIVATEADDRESS}" | tail -n 1)
    done
    while [[ -z "${PORTA}" || "${PORTA}" = "0" ]]; do
        PORTA=$(FIND_FREE_PORT "${PRIVATEADDRESS}" | tail -n 1)
    done
    if [[ "$(sudo ufw status | grep -v '(v6)' | awk '{print $1}' | grep -c "^${PORTB}$")" -eq 0 ]]; then
        sudo ufw allow "${PORTB}"
    fi
    if [[ "$(sudo ufw status | grep -v '(v6)' | awk '{print $1}' | grep -c "^${PORTA}$")" -eq 0 ]]; then
        sudo ufw allow "${PORTA}"
    fi

    echo "y" | sudo ufw enable >/dev/null 2>&1
    sudo ufw reload
}

INSTALL_DOCKER() {
    # check docker info
    if [ ! -x "$(command -v docker)" ]; then
        echo -e "${CYAN}Starting Docker Instll Script"
        CURRENT_USER=$(whoami)
        COUNTER=0
        rm -f ~/install.sh
        while [[ ! -f ~/install.sh ]] || [[ $(grep -Fxc "do_install" ~/install.sh) -eq 0 ]]; do
            rm -f ~/install.sh
            echo "Downloading Docker Setup Script."
            wget -4qo- https://raw.githubusercontent.com/docker/docker-install/master/install.sh -O ~/install.sh
            COUNTER=1
            if [[ "${COUNTER}" -gt 3 ]]; then
                echo
                echo "Download of docker script failed."
                echo
                exit 1
            fi
        done
        (
            # shellcheck disable=SC1091
            # shellcheck source=/home/"${CURRENT_USER}"/install.sh
            . ~/install.sh
        )
        #bash <(wget -qO- https://raw.githubusercontent.com/docker/docker-install/master/install.sh)
        sudo chmod 666 /var/run/docker.sock
        #sudo groupadd docker

        sudo usermod -aG docker "${CURRENT_USER}"
        echo -e "${CYAN}Completed Docker Install"
    else
        echo -e "${CYAN}Docker already installed"
    fi
}

GET_TXID() {
    #get txid and check explorer
    COLLATERAL=3000
    CONFIRMED=0
    MSG='Please enter the txid and output ID for your gridnode \n example: 149448f8c06cda10f1e7a30db5df0911cb7e3e6c1b8e3656c232f3caa3cb7965 0'
    while [[ "${CONFIRMED}" = 0 ]]; do
        echo -e "${CYAN}${MSG}"
        read -p "txid & output ID:" TXID
        TX_DETAILS=($TXID)
        if [[ -z "${TX_DETAILS[0]}" || -z "${TX_DETAILS[1]}" ]]; then
            MSG="${RED}Please enter both a txid and output ID"
            continue
        else
            # Trim extra info.
            TXHASH="$(echo -e "${TX_DETAILS[0]}" | sed 's/\://g' | sed 's/\"//g' | sed 's/,//g' | sed 's/txhash//g' | cut -d '-' -f1 | grep -o -w -E '[[:alnum:]]{64}')"
            TXHASH_LENGTH=$(printf "%s" "${TXHASH}" | wc -m)

            # TXID is not 64 char.
            if [ "${TXHASH_LENGTH}" -ne 64 ]; then
                echo
                MSG="${RED}txid is not 64 characters long: ${TXHASH}."
                echo
                TXHASH=''
                continue
            else
                URL=$(echo "${EXPLORER_URL}${EXPLORER_RAWTRANSACTION_PATH}${TX_DETAILS[0]}${PATH_SUFFIX}" | tr -d '[:space:]')
                OUTPUTIDX_RAW=$(wget -4qO- -T 15 -t 2 -o- "${URL}" "${SSL_BYPASS}")
                echo -e "${CYAN}Checking the explorer for txid ${URL}"
                #echo -e "${OUTPUTIDX_RAW}"
                # OUTPUTIDX_WEB=$(echo "${OUTPUTIDX_RAW}" | tr '[:upper:]' '[:lower:]' | jq ".vout[${TX_DETAILS[1]}] | select( (.value)|tonumber == ${COLLATERAL} ) | .n" 2>/dev/null)
                # echo -e "output from txid in explorer: ${OUTPUTIDX_WEB}"
                # if [[ "${OUTPUTIDX_WEB}" = 0 ]]; then
                #     echo -e "${GREEN}txid has ${COLLATERAL} collateral"
                #     echo -e "${GREEN}confirmed txid and output ID"
                #     CONFIRMED=1
                # else
                #     #MSG="${RED}warning!!! txid does not have exactly ${COLLATERAL} collateral"
                #     echo -e "${RED}warning!!! txid does not have exactly ${COLLATERAL} collateral"
                #     echo -e "${GREEN}Continuing with the install, you can change the txid later."
                #     sleep 1.5
                #     CONFIRMED=1
                # fi
                # TODO ADD COLLATERAL CHECK HERE
                CONFIRMED=1
                continue
            fi
        fi
    done

    MSG='Please enter your generated private key from the wallet.'
    while [[ -z "${GN_KEY}" ]]; do
        echo -e "${CYAN}${MSG}"
        read -p "key:" GN_KEY
        if [[ -z "${GN_KEY}" ]]; then
            MSG="${RED}${MSG}"
            continue
        fi
    done
}

CHECK_FOR_NODE_INSTALL() {
    CHECK_NODE="$(docker ps -a -f name=ugd_docker_1 | grep -w ugd_docker_1)"
    if [ -z "${CHECK_NODE}" ]; then
        echo -e "${GREEN}Clean install docker image"
        NEW_SERVER_NAME="${BASE_NAME}1"
        docker run -it -d \
            --name="${NEW_SERVER_NAME}" \
            --mount source="${DATA_VOLUME}1",destination=/root/.unigrid \
            --restart unless-stopped \
            -p "${PORTB}:${PORTB}" \
            -p "${PORTA}:${PORTA}" unigrid/unigrid:"${IMAGE_SOURCE}"
    else
        echo -e "${CYAN}1st node already installed"
        INSTALL_NEW_NODE
    fi

}

IS_PORT_OPEN() {
    PRIVIPADDRESS=${1}
    PORT_TO_TEST=${2}
    BIND=${3}
    VERBOSE=${4}
    INET=${5}
    PUB_IPADDRESS=${6}

    if [[ -z "${BIND}" ]]; then
        if [[ ${PRIVIPADDRESS} =~ .*:.* ]]; then
            PRIVIPADDRESS_SHORT=$(sipcalc "${PRIVIPADDRESS}" | grep -iF 'Compressed address' | cut -d '-' -f2 | awk '{print $1}')
            BIND="\[${PRIVIPADDRESS_SHORT}\]:${PORT_TO_TEST}"
        else
            BIND="${PRIVIPADDRESS}:${PORT_TO_TEST}"
        fi
    fi
    # see if port is used.
    PORTS_USED=$(sudo -n ss -lpn 2>/dev/null | grep -P "${BIND} ")
    # see if netcat can bind to port.
    # shellcheck disable=SC2009
    NETCAT_PIDS=$(ps -aux | grep -E '[n]etcat.*\-p.*\-l' | awk '{print $2}')
    # Clean start for netcat test.
    while read -r NETCAT_PID; do
        kill -9 "${NETCAT_PID}" >/dev/null 2>&1
    done <<<"${NETCAT_PIDS}"
    NETCAT_TEST=$(sudo -n timeout --signal=SIGKILL 0.3s netcat -p "${PORT_TO_TEST}" -l "${PRIVIPADDRESS}" 2>&1)
    NETCAT_PID=$!
    kill -9 "${NETCAT_PID}" >/dev/null 2>&1
    sleep 0.1
    # Clean up after.
    # shellcheck disable=SC2009
    NETCAT_PIDS=$(ps -aux | grep -E '[n]etcat.*\-p.*\-l' | awk '{print $2}')
    while read -r NETCAT_PID; do
        kill -9 "${NETCAT_PID}" >/dev/null 2>&1
    done <<<"${NETCAT_PIDS}"
    #if [[ "${VERBOSE}" -eq 1 ]]
    #then
    echo
    echo "${INET} ${PUB_IPADDRESS} ${PRIVIPADDRESS}:${PORT_TO_TEST}"
    echo "netcat test"
    echo "${NETCAT_TEST}"
    echo "ports in use test"
    echo "${PORTS_USED}"
    # echo 0 if port is not open.
    if [[ "${#PORTS_USED}" -gt 10 ]] || [[ $(echo "${NETCAT_TEST}" | grep -ci 'in use') -gt 0 ]]; then
        echo "0"
    else
        echo "${PORT_TO_TEST}"
    fi
}

FIND_FREE_PORT() {
    PRIVIPADDRESS=${1}
    if [[ -r /proc/sys/net/ipv4/ip_local_port_range ]]; then
        read -r LOWERPORT UPPERPORT </proc/sys/net/ipv4/ip_local_port_range
    fi
    if [[ ! $LOWERPORT =~ $RE ]] || [[ ! $UPPERPORT =~ $RE ]]; then
        read -r LOWERPORT UPPERPORT <<<"$(sudo sysctl net.ipv4.ip_local_port_range | cut -d '=' -f2)"
    fi
    if [[ ! $LOWERPORT =~ $RE ]] || [[ ! $UPPERPORT =~ $RE ]]; then
        LOWERPORT=32769
        UPPERPORT=60998
    fi
    #IS_PORT_OPEN ${PRIVIPADDRESS} ${PORT_TO_TEST}
    LAST_PORT=0
    while :; do
        PORT_TO_TEST=$(shuf -i "${LOWERPORT}"-"${UPPERPORT}" -n 1)
        while [[ "${LAST_PORT}" == "${PORT_TO_TEST}" ]]; do
            PORT_TO_TEST=$(shuf -i "${LOWERPORT}"-"${UPPERPORT}" -n 1)
            sleep 0.3
        done
        LAST_PORT="${PORT_TO_TEST}"
        IS_PORT_OPEN ${PRIVIPADDRESS} ${PORT_TO_TEST}
        if [[ $(IS_PORT_OPEN "${PRIVIPADDRESS}" "${PORT_TO_TEST}" | tail -n 1) -eq 0 ]]; then
            continue
        fi
        if [[ $(IS_PORT_OPEN "127.0.0.1" "${PORT_TO_TEST}" | tail -n 1) -eq 0 ]]; then
            continue
        fi
        if [[ $(IS_PORT_OPEN "0.0.0.0" "${PORT_TO_TEST}" | tail -n 1) -eq 0 ]]; then
            continue
        fi
        if [[ $(IS_PORT_OPEN "::" "${PORT_TO_TEST}" "\[::.*\]:${PORT_TO_TEST}" | tail -n 1) -eq 0 ]]; then
            continue
        fi
        break
    done
    #PORTB=$PORT_TO_TEST
    echo "${PORT_TO_TEST}"
}

INSTALL_NEW_NODE() {
    # Get all of the images names
    SERVER_NAME=$(docker ps -a --no-trunc --format '{{.Names}}' | tr '\n' ' ')
    sleep 0.1
    declare -a ARR=($SERVER_NAME)

    for s in "${ARR[@]}"; do
        if [[ "$s" != 'watchtower' ]]; then
            ITEM="$(echo ${s} | cut -d'_' -f3)"
            NUMBERS_ARRAY+=("$ITEM")
        fi
    done
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

    while [[ -z "${PORTB}" || "${PORTB}" = "0" ]]; do
        PORTB=$(FIND_FREE_PORT "${PRIVATEADDRESS}" | tail -n 1)
    done
    while [[ -z "${PORTA}" || "${PORTA}" = "0" ]]; do
        PORTA=$(FIND_FREE_PORT "${PRIVATEADDRESS}" | tail -n 1)
    done

    echo -e "PORT: ${PORTB}"

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
        -p "${PORTB}:${PORTB}" \
        -p "${PORTA}:${PORTA}" \
        --mount source=${NEW_VOLUME_NAME},destination=/root/.unigrid \
        --restart unless-stopped \
        unigrid/unigrid:"${IMAGE_SOURCE}"
}

SET_RANDOM_UPDATE_TIME() {
    # sets interval for watchtower to check for updates
    # either 1, 2, or 3 days
    RANDOM_NUMBER=$(((RANDOM % 3)))
    DAY_INTERVAL="${DAY_ARRAY[RANDOM_NUMBER]}"
    #echo "${RANDOM_NUMBER}"
    echo "watchtower check for update interval: ${DAY_INTERVAL}"
}

INSTALL_WATCHTOWER() {
    # Run watchtower if not found
    CHECK_WATCHTOWER="$(docker ps -f name=watchtower | grep -w watchtower)"
    sleep 0.1
    if [ -z "${CHECK_WATCHTOWER}" ]; then
        SET_RANDOM_UPDATE_TIME
        echo -e "${GREEN}Installing watchtower"
        # TODO add random intervals for watchtower check
        docker run -d \
            --name watchtower \
            -v /var/run/docker.sock:/var/run/docker.sock \
            containrrr/watchtower -c \
            --trace --include-restarting --interval "${DAY_INTERVAL}"
    else
        echo -e "${CYAN}Watchtower already intalled... skipping"
    fi
}

CREATE_CONF_FILE() {
    echo -e "Generating the unigrid.conf file"
    # Generate random password.
    if ! [ -x "$(command -v pwgen)" ]; then
        PWA="$(openssl rand -hex 44)"
    else
        PWA="$(pwgen -1 -s 44)"
    fi
    echo - "generated rpc password: ${PWA}"ugd_docker_1 getblockcount
    PUBIPADDRESS=$(dig +short txt ch whoami.cloudflare @1.0.0.1)
    PUBIPADDRESS=$(echo "$PUBIPADDRESS" | tr -d '"')
    echo -e "Public IP Address: ${PUBIPADDRESS}"

    EXTERNALIP="${PUBIPADDRESS}:${PORTA}"
    echo -e "EXTERNALIP: ${EXTERNALIP}"
    BIND="0.0.0.0"
    # :${PORTB}"
    if [[ "${IMAGE_SOURCE}" = "testnet" ]]; then
        PRIV_KEY="gridnodeprivkey=${GN_KEY}"
        NODE_NAME="gridnode=1"
    else
        PRIV_KEY="gridnodeprivkey=${GN_KEY}"
        NODE_NAME="gridnode=1"
    fi
    touch "${HOME}/${CONF}"
    cat <<COIN_CONF | sudo tee "${HOME}/${CONF}" >/dev/null
rpcuser=${NEW_SERVER_NAME}_rpc
rpcpassword=${PWA}
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
rpcport=${PORTB}
port=${PORTA}
externalip=${EXTERNALIP}
maxconnections=250
server=1
daemon=1
logtimestamps=1
listen=1
bind=${BIND}
${PRIV_KEY}
${NODE_NAME}
COIN_CONF
    docker cp "${HOME}/${CONF}" "${CURRENT_CONTAINER_ID}":"${USR_HOME}/${DIRECTORY}/${CONF}"
    rm -f "${HOME}/${CONF}"
}

INSTALL_HELPER() {
    COUNTER=0
    rm -f ~/unigrid
    while [[ ! -f ~/unigrid ]] || [[ $(grep -Fxc "# End of script." ~/unigrid) -eq 0 ]]; do
        rm -f ~/unigrid
        echo "Downloading Unigrid Helper Script."
        wget -4qo- https://raw.githubusercontent.com/unigrid-project/unigrid-installer/main/scripts/unigrid -O ~/unigrid
        COUNTER=1
        if [[ "${COUNTER}" -gt 3 ]]; then
            echo
            echo "Download of unigrid helper script failed."
            echo
            exit 1
        fi
    done
    sudo mv ~/unigrid /usr/bin/
    sudo chmod +x /usr/bin/unigrid
}

CHECK_OTHER_CONFS() {
    # Get the list of all container names that match the pattern ugd_docker_*
    container_names=$(docker ps -a --filter "name=ugd_docker_*" --format "{{.Names}}")
     echo "Performing an automatic repair of olders installs."
    # Iterate over each container name and modify the file if it contains masternodeprivkey and masternode
    for container_name in $container_names
    do
        echo "Checking if file in container $container_name contains masternodeprivkey and masternode"
        # Create a temporary directory to store the modified file
        mkdir tmp

        # Copy the file from the container to the temporary directory
        docker cp $container_name:/root/.unigrid/unigrid.conf tmp/unigrid.conf

        # Check if the file contains masternodeprivkey and masternode
        if grep -q -e 'masternodeprivkey' -e 'masternode' tmp/unigrid.conf; then
            echo "Modifying file in container $container_name"
            # Make a backup copy of the original file
            cp tmp/unigrid.conf tmp/unigrid.conf.bak

            # Replace "masternodeprivkey" with "gridnodeprivkey" in the file
            sed -i 's/masternodeprivkey/gridnodeprivkey/g' tmp/unigrid.conf

            # Replace "masternode" with "gridnode" in the file
            sed -i 's/masternode/gridnode/g' tmp/unigrid.conf

            # Copy the modified file back into the container
            docker cp tmp/unigrid.conf $container_name:/root/.unigrid/unigrid.conf

            # Restart the container
            docker restart $container_name
        else
            echo "File in container $container_name does not contain masternodeprivkey and masternode"
        fi

        # Remove the temporary directory and its contents
        rm -rf tmp
    done
}

INSTALL_COMPLETE() {
    CHECK_OTHER_CONFS
    CURRENT_CONTAINER_ID=$(echo $(docker ps -aqf name="${NEW_SERVER_NAME}"))
    CREATE_CONF_FILE
    sleep 0.5
    echo
    echo -e "${GREEN}Starting Unigrid docker container: ${CURRENT_CONTAINER_ID}"
    echo
    echo -e "New container name: ${NEW_SERVER_NAME}"

    ASCII_ART

    if [[ "${ASCII_ART}" ]]; then
        ${ASCII_ART}
    fi
    # Add commands to .bash_aliases
    BASH_ALIASES="$HOME/.bash_aliases"
    SINGLE_QUOTE="'"

    if [[ "${IMAGE_SOURCE}" = "testnet" ]]; then
        TESTNET="-${IMAGE_SOURCE}"
    else
        TESTNET=""
    fi

    COMMAND="alias ${NEW_SERVER_NAME}=${SINGLE_QUOTE}${NEW_SERVER_NAME}(){ docker exec -i ${NEW_SERVER_NAME} ugd_service unigrid ${TESTNET} \$@;}; ${NEW_SERVER_NAME}${SINGLE_QUOTE}"

    if [ "$COMMAND" != "" ]; then
        echo $COMMAND >>$BASH_ALIASES
        . $BASH_ALIASES
        . $HOME/.bashrc
    fi
    # Add helper commands to /usr/bin
    INSTALL_HELPER
    # Add gridnode details to a txt file
    FILENAME='gridnodes.txt'
    OUTPUT="${NEW_SERVER_NAME} ${EXTERNALIP} ${GN_KEY} ${TX_DETAILS[0]} ${TX_DETAILS[1]}"
    if [ "$OUTPUT" != "" ]; then
        echo $OUTPUT >>~/$FILENAME
    fi
    echo -e "${CYAN}Restarting the docker container with the updated configuration."
    docker restart "${CURRENT_CONTAINER_ID}"

    # we only need to do this for the first node as the rest copy this nodes volume
    if [ "${NEW_SERVER_NAME}" = 'ugd_docker_1' ]; then
        echo -e "Clean volume install for ${NEW_SERVER_NAME}"
        # FOR LOOP TO CHECK CHAIN IS SYNCED
        BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount 2>&1)
        echo -e "Checking if the container has started."
        i=0

        while [[ "${BLOCK_COUNT}" = '' ]] || [[ "${BLOCK_COUNT}" =~ "error: couldn't connect to server" ]]; do
            if [[ "${BLOCK_COUNT}" =~ "error: couldn't connect to server" ]]; then
                while [[ "${BLOCK_COUNT}" =~ "error: couldn't connect to server" ]]; do
                    echo -en "\r${GREEN}${SP:i++%${#SP}:1}${NC} Waiting for connection... (${SECONDS} s)\e[K"
                    sleep 1
                    BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount 2>&1)
                done
            else
                sleep 1
                BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount 2>&1)
            fi
        done

        echo -e "\r${GREEN}Connected!${NC}                                    "

        sleep 0.5
        touch data.json
        PROGRESS=''
        TASK=''
        STATUS=''
        i=0
        while [[ "$BLOCK_COUNT" = "-1" ]]; do
            BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid ${TESTNET} getblockcount)
            sleep 0.1
            BOOT_STRAPPING=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid ${TESTNET} getbootstrappinginfo)
            sleep 0.1
            echo "${BOOT_STRAPPING}" >>data.json
            PROGRESS=$(jq -r '.progress' data.json)
            TASK=$(jq -r '.status' data.json)
            STATUS=$(jq -r '.walletstatus' data.json)
            echo -en "\\r${GREEN}${SP:i++%${#SP}:1} Unigrid sync status... Task: ${TASK} Progress: ${PROGRESS} \\c/r\033[K"
            sleep 0.3
            if [[ "$TASK" = "complete" && "${PROGRESS}" = 100 ]]; then
                echo
                break
            fi
            true >data.json
        done

        rm -f data.json
    fi
    # Restart the service
    RESTART_SERVICE=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service restart)
    echo "$RESTART_SERVICE"
    i=0
    COUNTER=0
    BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount 2>&1)

    while [[ "${BLOCK_COUNT}" = "-1" ]] || [[ "${BLOCK_COUNT}" =~ "error: couldn't connect to server" ]]; do
        echo -en "\\r${ORANGE}${SP:i++%${#SP}:1}Loading the Unigrid backend... ${COUNTER} \\c/r\033[K"
        sleep 1
        COUNTER=$((COUNTER + 1))
        BLOCK_COUNT=$(docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount 2>&1)
        #echo "DEBUG: BLOCK_COUNT=${BLOCK_COUNT}" # Debug message
    done

    . ${HOME}/.bashrc
    echo -e "${GREEN}Current block"
    docker exec -i "${CURRENT_CONTAINER_ID}" ugd_service unigrid getblockcount
    echo
    echo -e "${CYAN}Completed Docker Install Script."
    echo -e "${CYAN}Docker container ${NEW_SERVER_NAME} has started!"
    echo -e "${CYAN}To call the unigrid daemon use..."
    echo -e "${GREEN}${NEW_SERVER_NAME} getblockcount"
    echo -e "${ORANGE}Once you have started your gridnode from your local wallet"
    echo -e "${GREEN}${NEW_SERVER_NAME} gridnodedebug"
    echo -e "${CYAN}Some commands may not work immediately until the wallet fully syncs."
    echo
    echo -e "${CYAN}To access the container you can type..."
    echo -e "${GREEN}docker exec -it ${NEW_SERVER_NAME} /bin/bash"
    echo
    echo -e "${BLUE}There are also a set of helper commands for all containers."
    echo -e "For a list of commands type..."
    echo -e "${GREEN}unigrid help"
    echo
    echo -e "${CYAN}If you would like to install another node simply run this script again."
    echo
    echo -e "${GREEN}Add the below info to your gridnode.conf file."
    echo -e "The info is also stored in a file ~/$FILENAME"
    echo -e
    echo -e "${NEW_SERVER_NAME} ${EXTERNALIP} ${GN_KEY} ${TX_DETAILS[0]} ${TX_DETAILS[1]}"
    echo
    echo -e "${CYAN}Install complete!${NC}"
    echo
    stty sane 2>/dev/null
}

START_INSTALL() {
    PRE_INSTALL_CHECK

    INSTALL_DOCKER

    GET_TXID

    CHECK_FOR_NODE_INSTALL

    INSTALL_WATCHTOWER

    INSTALL_COMPLETE

    rm -f ~/___gn.sh install.sh

    source ~/.bashrc

}
# End of gridnode setup script.
