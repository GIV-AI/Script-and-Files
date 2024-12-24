#!/bin/bash

# Prompt for username
read -p "Enter username to delete: " USERNAME
USER_DIR=/home/vips-dgx/Scripts_and_Files/Kubernetes_login_node/login_node_users_directory/"$USERNAME"
USER_FILE="$USER_DIR/config_user.yaml"

# Check if namespace exists
if sudo kubectl get ns "$USERNAME" >/dev/null 2>&1; then
    # Namespace deletion with suppressed warning
    sudo kubectl delete namespace "$USERNAME" --force --grace-period=0 2>/dev/null

    # Check if the config_user.yaml file exists
    if [[ -f "$USER_FILE" ]]; then
        # File exists; proceed with deletion
        sudo rm -rf "$USER_DIR"

        CHECK_FOLDER=/workspace/login_node_pv/"$USERNAME"
        if [[ -d "$CHECK_FOLDER" ]]; then
            # Folder exists; proceed with deletion
            sudo rm -rf "$CHECK_FOLDER"
        else
            echo "User '$USERNAME' does not have persistent data."
        fi

        echo "User '$USERNAME' and associated resources have been deleted."
    else
        # File does not exist
        echo "File does not exist. No action taken for file deletion."
    fi
else
    # Namespace does not exist
    echo "Namespace '$USERNAME' does not exist. No action taken."
fi

