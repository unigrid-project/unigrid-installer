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
sudo bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/node_installer.sh)" ; source ~/.bashrc
```

'

cd ~/ || exit
COUNTER=0
rm -f ~/___ugd.sh
while [[ ! -f ~/___ugd.sh ]] || [[ $( grep -Fxc "# End of setup script." ~/___ugd.sh ) -eq 0 ]]
do
  rm -f ~/___ugd.sh
  echo "Downloading Unigrid Setup Script."
  wget -4qo- https://raw.githubusercontent.com/unigrid-project/unigrid-installer/main/node-setup.sh -O ~/___ugd.sh
  COUNTER=1
  if [[ "${COUNTER}" -gt 3 ]]
  then
    echo
    echo "Download of setup script failed."
    echo
    exit 1
  fi
done

(
# shellcheck disable=SC1091
# shellcheck source=/root/___ugd.sh
. ~/___ugd.sh
)