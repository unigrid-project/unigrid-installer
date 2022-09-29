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

if [[ -z "${DAEMON_NAME}" ]]
then
    echo "passed daemon name " ${DAEMON_NAME}
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

UNIGRID_SETUP_THREAD () {
CHECK_SYSTEM
if [ $? == "1" ]
then
  return 1 2>/dev/null || exit 1
fi
}
stty sane 2>/dev/null
echo "done"
echo
sleep 0.1
# End of setup script.