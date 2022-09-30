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
DAEMON_BIN=''
CONTROLLER_BIN=''
GROUNDHOG_BIN=''
HEDGEHOD_BIN=''

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
  USER_NAME_CURRENT=$( whoami )
  CAN_SUDO=0
  CAN_SUDO=$( timeout --foreground --signal=SIGKILL 1s bash -c "sudo -l 2>/dev/null | grep -v '${USER_NAME_CURRENT}' | wc -l " )
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
    wget -4 "${GITHUB_URL}" -O /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" -q --show-progress --progress=bar:force 2>&1
    sleep 0.6
    echo
    mkdir -p /var/unigrid/"${PROJECT_DIR}"/src
    if [[ $( echo "${BIN_FILENAME}" | grep -c '.tar.gz$' ) -eq 1 ]] || [[ $( echo "${BIN_FILENAME}" | grep -c '.tgz$' ) -eq 1 ]]
    then
      echo "Decompressing tar.gz archive."
      if [[ -x "$( command -v pv )" ]]
      then
        pv "/var/unigrid/latest-github-releasese/${BIN_FILENAME}" | tar -xz -C /var/unigrid/"${PROJECT_DIR}"/src 2>&1
      else
       tar -xzf /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" -C /var/unigrid/"${PROJECT_DIR}"/src
      fi

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.tar.xz$' ) -eq 1 ]]
    then
      echo "Decompressing tar.xz archive."
     if [[ -x "$( command -v pv )" ]]
     then
       pv "/var/unigrid/latest-github-releasese/${BIN_FILENAME}" | tar -xJ -C /var/unigrid/"${PROJECT_DIR}"/src 2>&1
     else
        tar -xJf /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" -C /var/unigrid/"${PROJECT_DIR}"/src
     fi

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.zip$' ) -eq 1 ]]
    then
      echo "Unzipping file."
      unzip -o /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" -d /var/unigrid/"${PROJECT_DIR}"/src/

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.deb$' ) -eq 1 ]]
    then
      echo "Installing deb package."
      sudo -n dpkg --install /var/unigrid/latest-github-releasese/"${BIN_FILENAME}"
      echo "Extracting deb package."
      dpkg -x /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" /var/unigrid/"${PROJECT_DIR}"/src/

    elif [[ $( echo "${BIN_FILENAME}" | grep -c '.gz$' ) -eq 1 ]]
    then
      echo "Decompressing gz archive."
      mv /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" /var/unigrid/"${PROJECT_DIR}"/src/"${BIN_FILENAME}"
      gunzip /var/unigrid/"${PROJECT_DIR}"/src/"${BIN_FILENAME}"

    else
      echo "Copying over."
      mv /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" /var/unigrid/"${PROJECT_DIR}"/src/
    fi

    cd ~/ || return 1 2>/dev/null
    find /var/unigrid/"${PROJECT_DIR}"/src/ -name "$DAEMON_BIN" -size +128k 2>/dev/null
    find /var/unigrid/"${PROJECT_DIR}"/src/ -name "$DAEMON_BIN" -size +128k -exec cp {} /var/unigrid/"${PROJECT_DIR}"/src/  \; 2>/dev/null
    find /var/unigrid/"${PROJECT_DIR}"/src/ -name "$CONTROLLER_BIN" -size +128k 2>/dev/null
    find /var/unigrid/"${PROJECT_DIR}"/src/ -name "$CONTROLLER_BIN" -size +128k -exec cp {} /var/unigrid/"${PROJECT_DIR}"/src/  \; 2>/dev/null

    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" ]] && \
      [[ "${BIN_FILENAME}" == ${DAEMON_BIN}* ]] && \
      [[ $( ldd "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" | grep -ciF 'not a dynamic executable' ) -eq 0 ]]
    then
      echo "Renaming ${BIN_FILENAME} to ${DAEMON_BIN}"
      mv "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
    fi
    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" ]] && \
      [[ "${BIN_FILENAME}" == ${CONTROLLER_BIN}* ]] && \
      [[ $( ldd "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" | grep -ciF 'not a dynamic executable' ) -eq 0 ]]
    then
      echo "Renaming ${BIN_FILENAME} to ${CONTROLLER_BIN}"
      mv "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
    fi

    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" ]]
    then
      echo "Setting executable bit for daemon ${DAEMON_BIN}"
      echo "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
      sudo -n chmod +x "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" 2>/dev/null
      chmod +x "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" 2>/dev/null
      if [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" | wc -l ) -gt 2 ]]
      then
        if [[ "${UBUNTU_VERSION}" == 16.* ]] && \
          [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" | grep -cE 'libboost.*1.65' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.65"
          rm "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
        elif [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}" | grep -cE 'libboost.*1.54' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.54"
          rm "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
        else
          echo "Good"
          FOUND_DAEMON=1
        fi
      else
        echo "ldd failed."
        rm "/var/unigrid/${PROJECT_DIR}/src/${DAEMON_BIN}"
      fi
    fi
    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" ]]
    then
      echo "Setting executable bit for controller ${CONTROLLER_BIN}"
      echo "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
      sudo -n chmod +x "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" 2>/dev/null
      chmod +x "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" 2>/dev/null
      if [[ $( timeout --signal=SIGKILL 1s ldd "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" | wc -l ) -gt 2 ]]
      then
        if [[ "${UBUNTU_VERSION}" == 16.* ]] && \
          [[ $( timeout --signal=SIGKILL 1s ldd "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" | grep -cE 'libboost.*1.65' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.65"
          rm "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
        elif [[ $( timeout --signal=SIGKILL 1s ldd "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}" | grep -cE 'libboost.*1.54' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.54"
          rm "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
        else
          echo "Good"
          FOUND_CLI=1
        fi
      else
        echo "ldd failed."
        rm "/var/unigrid/${PROJECT_DIR}/src/${CONTROLLER_BIN}"
      fi
    fi

    # Break out of loop if we got what we needed.
    if [[ "${FOUND_DAEMON}" -eq 1 ]] && [[ "${FOUND_CLI}" -eq 1 ]]
    then
      break
    fi
  done <<< "${DAEMON_DOWNLOAD_URL}"
}

JAR_DOWNLOAD_EXTRACT () {
  PROJECT_DIR=${1}
  JAR_BIN=${2}
  JAR_DOWNLOAD_URL=${3}

  UBUNTU_VERSION=$( lsb_release -sr )
  FOUND_JAR=0
  while read -r GITHUB_URL_JAR
  do
    if [[ -z "${GITHUB_URL_JAR}" ]]
    then
      continue
    fi
    BIN_FILENAME=$( basename "${GITHUB_URL_JAR}" | tr -d '\r'  )
    echo "URL: ${GITHUB_URL_JAR}"
    stty sane 2>/dev/null
    wget -4 "${GITHUB_URL_JAR}" -O /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" -q --show-progress --progress=bar:force 2>&1
    sleep 0.6
    echo
    mkdir -p /var/unigrid/"${PROJECT_DIR}"/src
    echo "Copying over ${BIN_FILENAME}."
    mv /var/unigrid/latest-github-releasese/"${BIN_FILENAME}" /var/unigrid/"${PROJECT_DIR}"/src/

    cd ~/ || return 1 2>/dev/null
    find /var/unigrid/"${PROJECT_DIR}"/src/ -name "$JAR_BIN" -size +128k 2>/dev/null
    find /var/unigrid/"${PROJECT_DIR}"/src/ -name "$JAR_BIN" -size +128k -exec cp {} /var/unigrid/"${PROJECT_DIR}"/src/  \; 2>/dev/null

    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" ]] && \
      [[ "${BIN_FILENAME}" == ${JAR_BIN}* ]] && \
      [[ $( ldd "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" | grep -ciF 'not a dynamic executable' ) -eq 0 ]]
    then
      echo "Renaming ${BIN_FILENAME} to ${JAR_BIN}"
      mv "/var/unigrid/${PROJECT_DIR}/src/${BIN_FILENAME}" "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}"
    fi

    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}" ]]
    then
      echo "Setting executable bit for daemon ${JAR_BIN}"
      echo "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}"
      sudo -n chmod +x "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}" 2>/dev/null
      chmod +x "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}" 2>/dev/null
      if [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}" | wc -l ) -gt 2 ]]
      then
        if [[ "${UBUNTU_VERSION}" == 16.* ]] && \
          [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}" | grep -cE 'libboost.*1.65' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.65"
          rm "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}"
        elif [[ $( timeout --foreground --signal=SIGKILL 3s ldd "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}" | grep -cE 'libboost.*1.54' ) -gt 0 ]]
        then
          echo "ldd has wrong libboost version 1.54"
          rm "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}"
        else
          echo "Good"
          FOUND_JAR=1
        fi
      else
        echo "ldd failed."
        rm "/var/unigrid/${PROJECT_DIR}/src/${JAR_BIN}"
      fi
    fi

    # Break out of loop if we got what we needed.
    if [[ "${FOUND_JAR}" -eq 1 ]]
    then
      break
    fi
  done <<< "${JAR_DOWNLOAD_URL}"
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
    #curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" -z "$( date --rfc-2822 -d "@${TIMESTAMP}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
    curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" \
        -z "$( date --rfc-2822 -d "@${TIMESTAMP}" )" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

    LATEST=$( cat "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    if [[ $( echo "${LATEST}" | grep -c 'browser_download_url' ) -eq 0 ]]
    then
      echo "Downloading ${RELEASE_TAG} release info from github."
      curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
      # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
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
      curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" \
        -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"
      # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"
      RELEASE_ID=$( jq '.[].id' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
      echo "Downloading latest release info from github."
      curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

      # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
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
    curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases"  \
        -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"


    # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"

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

GROUNDHOG_DOWNLOAD_SUPER () {
  REPO=${1}
  BIN_BASE=${2}
  GROUNDHOG_DOWNLOAD_URL=${3}
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

  PROJECT_DIR=$( echo "${REPO}" | tr '/' '_' )

  GROUNDHOG_BIN="${BIN_BASE}"
  DAEMON_GREP="[${GROUNDHOG_BIN:0:1}]${GROUNDHOG_BIN:1}"

  if [[ ! "${GROUNDHOG_DOWNLOAD_URL}" == http* ]]
  then
    GROUNDHOG_DOWNLOAD_URL=''
  fi

  # curl & curl cache.
  if [[ -z "${GROUNDHOG_DOWNLOAD_URL}" ]]
  then
    TIMESTAMP=9999
    if [[ -s "/var/unigrid/latest-github-releasese/${FILENAME}.json" ]]
    then
      # Get timestamp.
      TIMESTAMP=$( stat -c %Y "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    fi
    echo "Downloading ${RELEASE_TAG} release info from github."
    curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" \
        -z "$( date --rfc-2822 -d "@${TIMESTAMP}" )" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

    # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" -z "$( date --rfc-2822 -d "@${TIMESTAMP}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

    LATEST=$( cat "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    if [[ $( echo "${LATEST}" | grep -c 'browser_download_url' ) -eq 0 ]]
    then
      echo "Downloading ${RELEASE_TAG} release info from github."
      curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}"  \
        -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

      # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_TAG}" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
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
      curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" \
        -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"

      # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"
      RELEASE_ID=$( jq '.[].id' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
      echo "Downloading latest release info from github."
      curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"

      # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}" -o "/var/unigrid/latest-github-releasese/${FILENAME}.json"
      LATEST=$( cat "/var/unigrid/latest-github-releasese/${FILENAME}.json" )
    fi

    VERSION_REMOTE=$( echo "${LATEST}" | jq -r '.tag_name' | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' )
    echo "Remote version: ${VERSION_REMOTE}"
    echo "JAR: ${GROUNDHOG_BIN}" | grep -cE "jar$" 
    if [[ -s "/var/unigrid/${PROJECT_DIR}/src/${GROUNDHOG_BIN}" ]] && \
      [[ $( echo "${GROUNDHOG_BIN}" | grep -cE "jar$" ) -gt 0 ]]
    then
      # Set executable bit.
      if [[ ${CAN_SUDO} =~ ${RE} ]] && [[ "${CAN_SUDO}" -gt 2 ]]
      then
        sudo chmod +x "/var/unigrid/${PROJECT_DIR}/src/${GROUNDHOG_BIN}"
      else
        chmod +x "/var/unigrid/${PROJECT_DIR}/src/${GROUNDHOG_BIN}"
      fi

      VERSION_LOCAL=$( timeout --signal=SIGKILL 9s "/var/unigrid/${PROJECT_DIR}/src/${GROUNDHOG_BIN}" --help 2>/dev/null | head -n 1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' )
      if [[ -z "${VERSION_LOCAL}" ]]
      then
        VERSION_LOCAL=$( timeout --signal=SIGKILL 9s "/var/unigrid/${PROJECT_DIR}/src/${GROUNDHOG_BIN}" -version 2>/dev/null | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' )
      fi

      echo "Local version: ${VERSION_LOCAL}"
      if [[ $( echo "${VERSION_LOCAL}" | grep -c "${VERSION_REMOTE}" ) -eq 1 ]] && [[ "${4}" != 'force' ]]
      then
        return 1 2>/dev/null
      fi
    fi

    ALL_DOWNLOADS=$( echo "${LATEST}" | jq -r '.assets[].browser_download_url' )
    # Remove useless files.
    # not really necessary for the jars TODO
    DOWNLOADS=$( echo "${ALL_DOWNLOADS}" | grep -iv 'win' | grep -iv 'arm-RPi' | grep -iv '\-qt' | grep -iv 'raspbian' | grep -v '.dmg$' | grep -v '.exe$' | grep -v '.sh$' | grep -v '.pdf$' | grep -v '.sig$' | grep -v '.asc$' | grep -iv 'MacOS' | grep -iv 'OSX' | grep -iv 'HighSierra' | grep -iv 'arm' | grep -iv 'bootstrap' | grep -iv '14.04' )

    # Try to pick the correct file.
    LINES=$( echo "${DOWNLOADS}" | sed '/^[[:space:]]*$/d' | wc -l )
    if [[ "${LINES}" -eq 0 ]]
    then
      echo "ERROR! Will try all files below."
    elif [[ "${LINES}" -eq 1 ]]
    then
      GROUNDHOG_DOWNLOAD_URL="${DOWNLOADS}"
    fi

  fi
  if [[ -z "${GROUNDHOG_DOWNLOAD_URL}" ]]
  then
    echo
    echo "Could not find groundhog from https://api.github.com/repos/${REPO}/releases/latest"
    echo "${DOWNLOADS}"
    echo
  else
    echo "Removing old files."
    rm -rf /var/unigrid/"${PROJECT_DIR}"/src/
    echo "Downloading latest release from github."
    echo "Download URL"
    echo "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}"
    echo "PROJECT_DIR" "${PROJECT_DIR}"
    echo "GROUNDHOG_BIN" "${GROUNDHOG_BIN}"
    echo "GROUNDHOG_DOWNLOAD_URL" "${GROUNDHOG_DOWNLOAD_URL}"
    GROUNDHOG_DOWNLOAD_EXTRACT_OUTPUT=$( JAR_DOWNLOAD_EXTRACT "${PROJECT_DIR}" "${GROUNDHOG_BIN}" "${GROUNDHOG_DOWNLOAD_URL}" )
    echo "${GROUNDHOG_DOWNLOAD_EXTRACT_OUTPUT}"
  fi

  if [[ -z "${GROUNDHOG_DOWNLOAD_URL}" ]] || \
    [[ ! -f "/var/unigrid/${PROJECT_DIR}/src/${GROUNDHOG_BIN}" ]] || \
    [[ $( echo "${GROUNDHOG_DOWNLOAD_EXTRACT_OUTPUT}" | grep -c "executable bit for controller" ) -eq 0 ]]
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
    curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases"  \
        -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" \
        -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"

    # curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases" -z "$( date --rfc-2822 -d "@${TIMESTAMP_RELEASES}" )" -o "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json"

    GROUNDHOG_DOWNLOAD_URL_ALL=$( jq -r '.[].assets[].browser_download_url' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
    GROUNDHOG_DOWNLOAD_URL_ALL_BODY=$( jq -r '.[].body' < "/var/unigrid/latest-github-releasese/${FILENAME_RELEASES}.json" )
    GROUNDHOG_DOWNLOAD_URL_ALL_BODY=$( echo "${GROUNDHOG_DOWNLOAD_URL_ALL_BODY}" | grep -Eo '(https?://[^ ]+)' | tr -d ')' | tr -d '(' | tr -d '\r' )
    GROUNDHOG_DOWNLOAD_URL=$( echo "${GROUNDHOG_DOWNLOAD_URL_ALL}" | grep -iv 'win' | grep -iv 'arm-RPi' | grep -iv '\-qt' | grep -iv 'raspbian' | grep -v '.dmg$' | grep -v '.exe$' | grep -v '.sh$' | grep -v '.pdf$' | grep -v '.sig$' | grep -v '.asc$' | grep -iv 'MacOS' | grep -iv 'HighSierra' | grep -iv 'arm' )
    if [[ -z "${GROUNDHOG_DOWNLOAD_URL}" ]]
    then
      GROUNDHOG_DOWNLOAD_URL="${GROUNDHOG_DOWNLOAD_URL_ALL}"
    fi
    if [[ -z "${GROUNDHOG_DOWNLOAD_URL}" ]]
    then
      GROUNDHOG_DOWNLOAD_URL="${GROUNDHOG_DOWNLOAD_URL_ALL_BODY}"
    fi

    JAR_DOWNLOAD_EXTRACT "${PROJECT_DIR}" "${GROUNDHOG_BIN}" "${GROUNDHOG_DOWNLOAD_URL}"
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

MOVE_FILES_SETOWNER () {
    sudo true >/dev/null 2>&1
    if ! sudo useradd -m "${USER_NAME}" -s /bin/bash 2>/dev/null
    then
        if ! sudo useradd -g "${USER_NAME}" -m "${USER_NAME}" -s /bin/bash 2>/dev/null
        then
            echo
            echo "User ${USER_NAME} exists. Skipping."
            echo
        fi
    fi

    sudo usermod -a -G systemd-journal "${USER_NAME}"
    chsh -s /bin/bash
    DAEMON_DIR='unigrid-project_daemon'
    GROUNDHOG_DIR='unigrid-project_groundhog'
    echo "moving daemon to /home/${USER_NAME}/.local/bin"
    sudo mkdir -p "/home/${USER_NAME}"/.local/bin
    sudo cp "/var/unigrid/${DAEMON_DIR}/src/${DAEMON_BIN}" "/home/${USER_NAME}"/.local/bin/
    sudo chmod +x "/home/${USER_NAME}"/.local/bin/"${DAEMON_BIN}"
    sudo cp "/var/unigrid/${DAEMON_DIR}/src/${CONTROLLER_BIN}" "/home/${USER_NAME}"/.local/bin/
    sudo chmod +x "/home/${USER_NAME}"/.local/bin/"${CONTROLLER_BIN}"
    sudo cp "/var/unigrid/${GROUNDHOG_DIR}/src/${GROUNDHOG_BIN}" "/home/${USER_NAME}"/.local/bin/
    sudo chmod +x "/home/${USER_NAME}"/.local/bin/"${GROUNDHOG_BIN}"
    sudo chown -R "${USER_NAME}":"${USER_NAME}" "/home/${USER_NAME}"
}

SETUP_SYSTEMCTL () {
# Setup systemd to start unigrid on restart.
TIMEOUT='70s'
STARTLIMITINTERVAL='600s'

OOM_SCORE_ADJUST=$( sudo cat /etc/passwd | wc -l )
CPU_SHARES=$(( 1024 - OOM_SCORE_ADJUST ))
STARTUP_CPU_SHARES=$(( 768 - OOM_SCORE_ADJUST  ))
echo "Creating systemd service for ${DAEMON_NAME}"

GN_TEXT="Creating systemd shutdown service."
GN_TEXT1="Shutdown service for unigrid"

cat << SYSTEMD_CONF | sudo tee /etc/systemd/system/"${USER_NAME}".service >/dev/null
[Unit]
Description=${DAEMON_NAME} for user ${USER_NAME}
After=network.target

[Service]
Type=forking
User=${USER_NAME}
WorkingDirectory=${USR_HOME}
#PIDFile=${USR_HOME}/${DIRECTORY}/${DAEMON_BIN}.pid
ExecStart=${USR_HOME}/.local/bin/unigridd --daemon -server
ExecStartPost=/bin/sleep 1
ExecStop=${USR_HOME}/.local/bin/unigrid-cli stop
Restart=always
RestartSec=${TIMEOUT}
TimeoutStartSec=${TIMEOUT}
TimeoutStopSec=240s
StartLimitInterval=${STARTLIMITINTERVAL}
StartLimitBurst=3
OOMScoreAdjust=${OOM_SCORE_ADJUST}
CPUShares=${CPU_SHARES}
StartupCPUShares=${STARTUP_CPU_SHARES}

[Install]
WantedBy=multi-user.target
SYSTEMD_CONF

sudo systemctl daemon-reload
sudo systemctl enable unigrid.service --now

# Use systemctl if it exists.
SYSTEMD_FULLFILE=$( grep -lrE "ExecStart=${FILENAME}.*-daemon" /etc/systemd/system/ | head -n 1 )
if [[ ! -z "${SYSTEMD_FULLFILE}" ]]
then
    SYSTEMD_FILE=$( basename "${SYSTEMD_FULLFILE}" )
fi
if [[ ! -z "${SYSTEMD_FILE}" ]]
then
    systemctl start "${SYSTEMD_FILE}"
    echo systemctl status "${SYSTEMD_FILE}"
fi

}

UNIGRID_SETUP_THREAD () {
    CHECK_SYSTEM
    if [ $? == "1" ]
    then
    return 1 2>/dev/null || exit 1
    fi
    DAEMON_DOWNLOAD_SUPER "${DAEMON_REPO}" "${BIN_BASE}" "${DAEMON_DOWNLOAD}" force
    GROUNDHOG_DOWNLOAD_SUPER "${GROUNDHOG_REPO}" "${GROUNDHOG_BASE}" "${GROUNDHOG_DOWNLOAD}" force
    MOVE_FILES_SETOWNER
    #SETUP_SYSTEMCTL
}



stty sane 2>/dev/null
echo
sleep 0.1
# End of setup script.