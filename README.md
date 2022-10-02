# unigrid-installer

# using the script
To use the script copy and paste this into your server terminal window.

```
sudo bash -ic "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/unigrid.sh)" ; source ~/.bashrc
```

# alternate username
To use a custom usernam, use the code like this. Replacing `<USERNAME>` with whatever name you wish to use.
```
sudo bash -c "$(wget -4qO- -o- raw.githubusercontent.com/unigrid-project/unigrid-installer/main/unigrid.sh)" 'source ~/.bashrc' <USERNAME>
```

# Removing the service

```
systemctl stop unigrid.service 
systemctl disable unigrid.service  
rm /etc/systemd/system/unigrid.service  
systemctl daemon-reload 
systemctl reset-failed
```

# Remove the user
`TODO turn this into a script that accepts the username as an arg`

```
sudo userdel -r unigrid
```

# To access 
runuser -l  nafo -c 'nafo getinfo'


