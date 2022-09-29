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

stty sane 2>/dev/null

# Chars for spinner.
SP="/-\\|"

if [[ "${DAEMON_NAME}" ]]
then
    echo "passed daemon name " ${DAEMON_NAME}
fi
ASCII_ART

if [[ "${ASCII_ART}" ]]
then
    ${ASCII_ART}
fi

CHECK_SYSTEM () {
  # Only run if user has sudo.
  sudo true >/dev/null 2>&1
  USRNAME_CURRENT=$( whoami )
  CAN_SUDO=0
  CAN_SUDO=$( timeout --foreground --signal=SIGKILL 1s bash -c "sudo -l 2>/dev/null | grep -v '${USRNAME_CURRENT}' | wc -l " )
  if [[ ${CAN_SUDO} =~ ${RE} ]] && [[ "${CAN_SUDO}" -gt 2 ]]
  then
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

  # Make sure sudo will work
  if [[ $( sudo false 2>&1 ) ]]
  then
    echo "$( hostname -I | awk '{print $1}' ) $( hostname )" >> /etc/hosts
  fi

  # Check for systemd
  systemctl --version >/dev/null 2>&1 || { cat /etc/*-release; echo; echo "systemd is required. Are you using a Debian based distro?" >&2; return 1 2>/dev/null || exit 1; }
}

WAIT_FOR_APT_GET () {
  ONCE=0
  while [[ $( sudo lslocks -n -o COMMAND,PID,PATH | grep -c 'apt-get\|dpkg\|unattended-upgrades' ) -ne 0 ]]
  do
    if [[ "${ONCE}" -eq 0 ]]
    then
      while read -r LOCKINFO
      do
        PID=$( echo "${LOCKINFO}" | awk '{print $2}' )
        ps -up "${PID}"
        echo "${LOCKINFO}"
      done <<< "$( sudo lslocks -n -o COMMAND,PID,PATH | grep 'apt-get\|dpkg\|unattended-upgrades' )"
      ONCE=1
      if [[ ${ARG6} == 'y' ]]
      then
        echo "Waiting for apt-get to finish"
      fi
    fi
    if [[ ${ARG6} == 'y' ]]
    then
      printf "."
    else
      echo -e "\\r${SP:i++%${#SP}:1} Waiting for apt-get to finish... \\c"
    fi
    sleep 0.3
  done
  echo
  echo -e "\\r\\c"
  stty sane 2>/dev/null
}

DAEMON_DOWNLOAD_EXTRACT () {
  PROJECT_DIR=${1}
  DAEMON_BIN=${2}
  CONTROLLER_BIN=${3}
  DAEMON_DOWNLOAD_URL=${4}

  UBUNTU_VERSION=$( lsb_release -sr )
  FOUND_DAEMON=0
  FOUND_CLI=0
  while read -r GITHUB_URL
  do
    if [[ -z "${GITHUB_URL}" ]]
    then
      continue
    fi
    BIN_FILENAME=$( basename "${GITHUB_URL}" | tr -d '\r'  )
    echo "URL: ${GITHUB_URL}"
    stty sane 2>/dev/null
    wget -4 "${GITHUB_URL}" -O /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" -q --show-progress --progress=bar:force 2>&1
    sleep 0.6
    echo
    mkdir -p /var/multi-gridnode-data/"${PROJECT_DIR}"/src
    if [[ $( echo "${BIN_FILENAME}" | grep -c '.tar.gz$' ) -eq 1 ]] || [[ $( echo "${BIN_FILENAME}" | grep -c '.tgz$' ) -eq 1 ]]
    then
      echo "Decompressing tar.gz archive."
      if [[ -x "$( command -v pv )" ]]
      then
        pv "/var/multi-gridnode-data/latest-github-releasese/${BIN_FILENAME}" | tar -xz -C /var/multi-gridnode-data/"${PROJECT_DIR}"/src 2>&1
      else
       tar -xzf /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" -C /var/multi-gridnode-data/"${PROJECT_DIR}"/src
      fi

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.tar.xz$' ) -eq 1 ]]
    then
      echo "Decompressing tar.xz archive."
     if [[ -x "$( command -v pv )" ]]
     then
       pv "/var/multi-gridnode-data/latest-github-releasese/${BIN_FILENAME}" | tar -xJ -C /var/multi-gridnode-data/"${PROJECT_DIR}"/src 2>&1
     else
        tar -xJf /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" -C /var/multi-gridnode-data/"${PROJECT_DIR}"/src
     fi

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.zip$' ) -eq 1 ]]
    then
      echo "Unzipping file."
      unzip -o /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" -d /var/multi-gridnode-data/"${PROJECT_DIR}"/src/

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.deb$' ) -eq 1 ]]
    then
      echo "Installing deb package."
      sudo -n dpkg --install /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}"
      echo "Extracting deb package."
      dpkg -x /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" /var/multi-gridnode-data/"${PROJECT_DIR}"/src/

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.gz$' ) -eq 1 ]]
    then
      echo "Decompressing gz archive."
      mv /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" /var/multi-gridnode-data/"${PROJECT_DIR}"/src/"${BIN_FILENAME}"
      gunzip /var/multi-gridnode-data/"${PROJECT_DIR}"/src/"${BIN_FILENAME}"

    else
      echo "Copying over."
      mv /var/multi-gridnode-data/latest-github-releasese/"${BIN_FILENAME}" /var/multi-gridnode-data/"${PROJECT_DIR}"/src/
    fi

    cd ~/ || return 1 2>/dev/null
    find /var/multi-gridnode-data/"${PROJECT_DIR}"/src/ -name "$DAEMON_BIN" -size +128k 2>/dev/null
    find /var/multi-gridnode-data/"${PROJECT_DIR}"/src/ -name "$DAEMON_BIN" -size +128k -exec cp {} /var/multi-gridnode-data/"${PROJECT_DIR}"/src/  \; 2>/dev/null
    find /var/multi-gridnode-data/"${PROJECT_DIR}"/src/ -name "$CONTROLLER_BIN" -size +128k 2>/dev/null
    find /var/multi-gridnode-data/"${PROJECT_DIR}"/src/ -name "$CONTROLLER_BIN" -size +128k -exec cp {} /var/multi-gridnode-data/"${PROJECT_DIR}"/src/  \; 2>/dev/null

    if [[ -s "/var/multi-gridnode-data/${PROJECT_DIR}/src/${BIN_FILENAME}" ]] && \
      [[ "${BIN_FILENAME}" == ${DAEMON_BIN}* ]] && \
      [[ $( ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${BIN_FILENAME}" | grep -ciF 'not a dynamic executable' ) -eq 0 ]]
    then
      echo "Renaming ${BIN_FILENAME} to ${DAEMON_BIN}"
      mv "/var/multi-gridnode-data/${PROJECT_DIR}/src/${BIN_FILENAME}" "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}"
    fi
    if [[ -s "/var/multi-gridnode-data/${PROJECT_DIR}/src/${BIN_FILENAME}" ]] && \
      [[ "${BIN_FILENAME}" == ${CONTROLLER_BIN}* ]] && \
      [[ $( ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${BIN_FILENAME}" | grep -ciF 'not a dynamic executable' ) -eq 0 ]]
    then
      echo "Renaming ${BIN_FILENAME} to ${CONTROLLER_BIN}"
      mv "/var/multi-gridnode-data/${PROJECT_DIR}/src/${BIN_FILENAME}" "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
    fi

    if [[ -s "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}" ]]
    then
      echo "Setting executable bit for daemon ${DAEMON_BIN}"
      echo "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}"
      sudo -n chmod +x "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}" 2>/dev/null
      chmod +x "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}" 2>/dev/null
      if [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}" | wc -l ) -gt 2 ]]
      then
        if [[ "${UBUNTU_VERSION}" == 16.* ]] && \
          [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}" | grep -cE 'libboost.*1.65' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.65"
          rm "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}"
        elif [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}" | grep -cE 'libboost.*1.54' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.54"
          rm "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}"
        else
          echo "Good"
          FOUND_DAEMON=1
        fi
      else
        echo "ldd failed."
        rm "/var/multi-gridnode-data/${PROJECT_DIR}/src/${DAEMON_BIN}"
      fi
    fi
    if [[ -s "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}" ]]
    then
      echo "Setting executable bit for controller ${CONTROLLER_BIN}"
      echo "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
      sudo -n chmod +x "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}" 2>/dev/null
      chmod +x "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}" 2>/dev/null
      if [[ $( timeout --signal=SIGKILL 1s ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}" | wc -l ) -gt 2 ]]
      then
        if [[ "${UBUNTU_VERSION}" == 16.* ]] && \
          [[ $( timeout --signal=SIGKILL 1s ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}" | grep -cE 'libboost.*1.65' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.65"
          rm "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
        elif [[ $( timeout --signal=SIGKILL 1s ldd "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}" | grep -cE 'libboost.*1.54' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.54"
          rm "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
        else
          echo "Good"
          FOUND_CLI=1
        fi
      else
        echo "ldd failed."
        rm "/var/multi-gridnode-data/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
      fi
    fi

    # Break out of loop if we got what we needed.
    if [[ "${FOUND_DAEMON}" -eq 1 ]] && [[ "${FOUND_CLI}" -eq 1 ]]
    then
      break
    fi
  done <<< "${DAEMON_DOWNLOAD_URL}"
}

DAEMON_DOWNLOAD_SUPER () {
  if [ ! -x "$( command -v jq )" ] || \
    [ ! -x "$( command -v curl )" ] || \
    [ ! -x "$( command -v gzip )" ] || \
    [ ! -x "$( command -v tar )" ] || \
    [ ! -x "$( command -v unzip )" ]
  then
    WAIT_FOR_APT_GET
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
      curl \
      gzip \
      unzip \
      xz-utils \
      jq \
      bc \
      html-xml-utils \
      mediainfo
  fi

  REPO=${1}
  BIN_BASE=${2}
  DAEMON_DOWNLOAD_URL=${3}
  FILENAME=$( echo "${REPO}" | tr '/' '_' )
  RELEASE_TAG='latest'
  if [[ ! -z "${4}" ]] && [[ "${4}" != 'force' ]] && [[ "${4}" != 'force_skip_download' ]]
  then
    rm "/var/unigrid/latest-github-releasese/${FILENAME}.json"
    RELEASE_TAG=${4}
  fi

  if [[ -z "${REPO}" ]] || [[ -z "${BIN_BASE}" ]]
  then
    return 1 2>/dev/null
  fi
  echo "Checking ${REPO} for the latest version"
  if [[ ! -d /var/unigrid/latest-github-releasese ]]
  then
    sudo -n mkdir -p /var/unigrid/latest-github-releasese
    sudo -n chmod -R a+rw /var/unigrid/
  fi
  mkdir -p /var/unigrid/latest-github-releasese 2>/dev/null
  chmod -R a+rw /var/unigrid/ 2>/dev/null
  PROJECT_DIR=$( echo "${REPO}" | tr '/' '_' )

  DAEMON_BIN="${BIN_BASE}d"
  DAEMON_GREP="[${DAEMON_BIN:0:1}]${DAEMON_BIN:1}"
  if [[ -z "${CONTROLLER_BIN}" ]]
  then
    CONTROLLER_BIN="${BIN_BASE}-cli"
  fi

  if [[ ! "${DAEMON_DOWNLOAD_URL}" == http* ]]
  then
    DAEMON_DOWNLOAD_URL=''
  fi

  # curl & curl cache.
  if [[ -z "${DAEMON_DOWNLOAD_URL}" ]]
  then
    TIMESTAMP=9999
    if [[ -s "/var/unigrid/latest-github-releasese/${FILENAME}.json" ]]
    then
      # Get timestamp.
      TIMESTAMP=$( stat -c %Y "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    fi
    echo "Downloading ${RELEASE_TAG} release info from github."
    curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" -z "$( date --rfc-2822 -d "@${TIMESTAMP}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

    LATEST=$( cat "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    if [[ $( echo "${LATEST}" | grep -c 'browser_download_url' ) -eq 0 ]]
    then
      echo "Downloading ${RELEASE_TAG} release info from github."
      curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
      LATEST=$( cat "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    fi
    echo "Download links in json from GitHub repo"
    echo "${LATEST}" | grep -c 'browser_download_url'
    if [[ $( echo "${LATEST}" | grep -c 'browser_download_url' ) -eq 0 ]]
    then
      FILENAME_RELEASES=$( echo "${REPO}-releases" | tr '/' '_' )
      TIMESTAMP_RELEASES=9999
      if [[ -s /var/unigrid/latest-github-releasese/"${FILENAME_RELEASES}".json ]]
      then
        # Get timestamp.
        TIMESTAMP_RELEASES=$( stat -c %Y /var/unigrid/latest-github-releasese/"${FILENAME_RELEASES}".json )
      fi
      echo "Downloading all releases from github."
      curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"
      RELEASE_ID=$( jq '.[].id' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
      echo "Downloading latest release info from github."
      curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
      LATEST=$( cat "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    fi

    VERSION_REMOTE=$( echo "${LATEST}" | jq -r '.tag_name' | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' )
    echo "Remote version: ${VERSION_REMOTE}"
    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" ]] && \
      [[ -s "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" ]] && \
      [[ $( echo "${CONTROLLER_BIN}" | grep -cE "cli$" ) -gt 0 ]]
    then
      # Set executable bit.
      if [[ ${CAN_SUDO} =~ ${RE} ]] && [[ "${CAN_SUDO}" -gt 2 ]]
      then
        sudo chmod +x "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
        sudo chmod +x "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
      else
        chmod +x "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
        chmod +x "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
      fi

      VERSION_LOCAL=$( timeout --signal=SIGKILL 9s "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" --help 2>/dev/null | head -n 1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' )
      if [[ -z "${VERSION_LOCAL}" ]]
      then
        VERSION_LOCAL=$( timeout --signal=SIGKILL 9s "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" -version 2>/dev/null | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' )
      fi

      echo "Local version: ${VERSION_LOCAL}"
      if [[ $( echo "${VERSION_LOCAL}" | grep -c "${VERSION_REMOTE}" ) -eq 1 ]] && [[ "${4}" != 'force' ]]
      then
        return 1 2>/dev/null
      fi
    fi

    ALL_DOWNLOADS=$( echo "${LATEST}" | jq -r '.assets[].browser_download_url' )
    # Remove useless files.
    DOWNLOADS=$( echo "${ALL_DOWNLOADS}" | grep -iv 'win' | grep -iv 'arm-RPi' | grep -iv '\-qt' | grep -iv 'raspbian' | grep -v '.dmg$' | grep -v '.exe$' | grep -v '.sh$' | grep -v '.pdf$' | grep -v '.sig$' | grep -v '.asc$' | grep -iv 'MacOS' | grep -iv 'OSX' | grep -iv 'HighSierra' | grep -iv 'arm' | grep -iv 'bootstrap' | grep -iv '14.04' )

    # Try to pick the correct file.
    LINES=$( echo "${DOWNLOADS}" | sed '/^[[:space:]]*$/d' | wc -l )
    if [[ "${LINES}" -eq 0 ]]
    then
      echo "ERROR! Will try all files below."
    elif [[ "${LINES}" -eq 1 ]]
    then
      DAEMON_DOWNLOAD_URL="${DOWNLOADS}"
    else
      # Pick ones that are 64 bit linux.
      DAEMON_DOWNLOAD_URL=$( echo "${DOWNLOADS}" | grep 'x86_64\|linux64\|ubuntu\|daemon\|lin64' )
    fi

    if [[ -z "${DAEMON_DOWNLOAD_URL}" ]]
    then
      # Pick ones that are linux command line.
      DAEMON_DOWNLOAD_URL=$( echo "${DOWNLOADS}" | grep -i 'linux_cli' )
    fi

    if [[ -z "${DAEMON_DOWNLOAD_URL}" ]]
    then
      # Pick ones that are linux.
      DAEMON_DOWNLOAD_URL=$( echo "${DOWNLOADS}" | grep -i 'linux' )
    fi

    # If more than 1 pick the one with 64 in it.
    if [[ $( echo "${DAEMON_DOWNLOAD_URL}" | sed '/^[[:space:]]*$/d' | wc -l ) -gt 1 ]]
    then
      DAEMON_DOWNLOAD_URL_TEST=$( echo "${DAEMON_DOWNLOAD_URL}" | grep -i '64' )
      if [[ ! -z "${DAEMON_DOWNLOAD_URL_TEST}" ]]
      then
        DAEMON_DOWNLOAD_URL=${DAEMON_DOWNLOAD_URL_TEST}
      fi
    fi

    # If more than 1 pick the one without debug in it.
    if [[ $( echo "${DAEMON_DOWNLOAD_URL}" | sed '/^[[:space:]]*$/d' | wc -l ) -gt 1 ]]
    then
      DAEMON_DOWNLOAD_URL=$( echo "${DAEMON_DOWNLOAD_URL}" | grep -vi 'debug' )
    fi
  fi
  if [[ -z "${DAEMON_DOWNLOAD_URL}" ]]
  then
    echo
    echo "Could not find linux wallet from https://api.github.com/repos/${REPO}/releases/latest"
    echo "${DOWNLOADS}"
    echo
  else
    echo "Removing old files."
    rm -rf /var/unigrid/"${PROJECT_DIR}"/src/
    echo "Downloading latest release from github."
    echo "Download URL"
    echo "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}"
    echo "PROJECT_DIR" "${PROJECT_DIR}"
    echo "DAEMON_BIN" "${DAEMON_BIN}"
    echo "CONTROLLER_BIN" "${CONTROLLER_BIN}"
    echo "DAEMON_DOWNLOAD_URL" "${DAEMON_DOWNLOAD_URL}"
    DAEMON_DOWNLOAD_EXTRACT_OUTPUT=$( DAEMON_DOWNLOAD_EXTRACT "${PROJECT_DIR}" "${DAEMON_BIN}" "${CONTROLLER_BIN}" "${DAEMON_DOWNLOAD_URL}" )
    echo "${DAEMON_DOWNLOAD_EXTRACT_OUTPUT}"
  fi

  if [[ -z "${DAEMON_DOWNLOAD_URL}" ]] || \
    [[ ! -f "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" ]] || \
    [[ ! -f "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" ]] || \
    [[ $( echo "${DAEMON_DOWNLOAD_EXTRACT_OUTPUT}" | grep -c "executable bit for daemon" ) -eq 0 ]] || \
    [[ $( echo "${DAEMON_DOWNLOAD_EXTRACT_OUTPUT}" | grep -c "executable bit for controller" ) -eq 0 ]]
  then
    FILENAME_RELEASES=$( echo "${REPO}-releases" | tr '/' '_' )
    TIMESTAMP_RELEASES=9999
    if [[ -s /var/unigrid/latest-github-releasese/"${FILENAME_RELEASES}".json ]]
    then
      # Get timestamp.
      TIMESTAMP_RELEASES=$( stat -c %Y /var/unigrid/latest-github-releasese/"${FILENAME_RELEASES}".json )
    fi
    echo "Downloading all releases from github."
    rm -rf /var/unigrid/"${PROJECT_DIR}"/src/
    curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"

    DAEMON_DOWNLOAD_URL_ALL=$( jq -r '.[].assets[].browser_download_url' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
    DAEMON_DOWNLOAD_URL_ALL_BODY=$( jq -r '.[].body' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
    DAEMON_DOWNLOAD_URL_ALL_BODY=$( echo "${DAEMON_DOWNLOAD_URL_ALL_BODY}" | grep -Eo '(https?://[^ ]+)' | tr -d ')' | tr -d '(' | tr -d '\r' )
    DAEMON_DOWNLOAD_URL=$( echo "${DAEMON_DOWNLOAD_URL_ALL}" | grep -iv 'win' | grep -iv 'arm-RPi' | grep -iv '\-qt' | grep -iv 'raspbian' | grep -v '.dmg$' | grep -v '.exe$' | grep -v '.sh$' | grep -v '.pdf$' | grep -v '.sig$' | grep -v '.asc$' | grep -iv 'MacOS' | grep -iv 'HighSierra' | grep -iv 'arm' )
    if [[ -z "${DAEMON_DOWNLOAD_URL}" ]]
    then
      DAEMON_DOWNLOAD_URL="${DAEMON_DOWNLOAD_URL_ALL}"
    fi
    if [[ -z "${DAEMON_DOWNLOAD_URL}" ]]
    then
      DAEMON_DOWNLOAD_URL="${DAEMON_DOWNLOAD_URL_ALL_BODY}"
    fi

    DAEMON_DOWNLOAD_EXTRACT "${PROJECT_DIR}" "${DAEMON_BIN}" "${CONTROLLER_BIN}" "${DAEMON_DOWNLOAD_URL}"
  fi
  if [[ ${CAN_SUDO} =~ ${RE} ]] && [[ "${CAN_SUDO}" -gt 2 ]]
  then
    sudo -n sh -c "find /var/unigrid/ -type f -exec chmod 666 {} \\;"
    sudo -n sh -c "find /var/unigrid/ -type d -exec chmod 777 {} \\;"
  else
    find "/var/unigrid/" -type f -exec chmod 666 {} \;
    find "/var/unigrid/" -type d -exec chmod 777 {} \;
  fi
}

UNIGRID_SETUP_THREAD () {
    CHECK_SYSTEM
    if [ $? == "1" ]
    then
    return 1 2>/dev/null || exit 1
    fi
    DAEMON_DOWNLOAD_SUPER "${DAEMON_REPO}" "${BIN_BASE}" "${DAEMON_DOWNLOAD}" force
}
stty sane 2>/dev/null
echo "done"
echo
sleep 0.1
# End of setup script.