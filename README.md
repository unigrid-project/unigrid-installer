# Unigrid Gridnode Installer Script

# Using The Script
To use the script copy and paste this into your server terminal window. You will need sudo installed and root privileges.

```
bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/node_installer.sh)" ; source ~/.bashrc
```
# BETA
```
bash -c "$(wget -qO - raw.githubusercontent.com/unigrid-project/unigrid-installer/main/node_installer.sh)" '' beta ; source ~/.bashrc
 ```
# Commands

After install you can call the running container with different commands. On the first install the container name will be `ugd_docker_1`. To call check the current block you can use `ugd_docker_1 getblockcount`.

Another set of convenience commands that run on all containers are under `unigrid help`.
