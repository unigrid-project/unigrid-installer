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

DAEMON_DOWNLOAD_EXTRACT () {
  PROJECT_DIR=${1}
  DAEMON_BIN=${2}
  CONTROLLER_BIN=${3}
  DOWNLOAD_URL=${4}
  if [ "${PROJECT_DIR}" -eq 0 ]
  then
    echo "no project directory supplied"
  else
    echo "$# arguments:"
    for x in "$@"; do
        new_file=$(wget --content-disposition -nv "$x" 2>&1 |cut -d\" -f2)
        mediainfo "$new_file"
    done
  fi
}

UNIGRID_SETUP_THREAD () {
    CHECK_SYSTEM
    if [ $? == "1" ]
    then
    return 1 2>/dev/null || exit 1
    fi
    DAEMON_DOWNLOAD_SUPER "${DAEMON_REPO}" "${BIN_BASE}" "${DAEMON_DOWNLOAD}"
}
stty sane 2>/dev/null
echo "done"
echo
sleep 0.1
# End of setup script.