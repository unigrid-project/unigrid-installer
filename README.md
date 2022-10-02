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