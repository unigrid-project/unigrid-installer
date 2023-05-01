#!/bin/bash

CHECK_OTHER_CONFS() {
    # Get the list of all container names that match the pattern ugd_docker_*
    container_names=$(docker ps -a --filter "name=ugd_docker_*" --format "{{.Names}}")

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

# Call the function
CHECK_OTHER_CONFS
