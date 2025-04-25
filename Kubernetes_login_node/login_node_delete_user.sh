#!/bin/bash

# Prompt for username
read -p "Enter username to delete: " USERNAME
USER_DIR=/home/jain-dgx/Scripts_and_Files/Kubernetes_login_node/login_node_users_directory/"$USERNAME"
USER_FILE="$USER_DIR/config_user.yaml"

# Check if namespace exists
if sudo kubectl get ns "$USERNAME" >/dev/null 2>&1; then
    # Namespace deletion with suppressed warning
    sudo kubectl delete namespace "$USERNAME" --force --grace-period=0 2>/dev/null
    sudo kubectl delete pv "$USERNAME"
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

# === Step 3: Delete user on remote server ===
REMOTE_USER=jain-hp-trg
REMOTE_HOST=192.168.1.250

# Check if user exists remotely
echo "Checking if '$USERNAME' exists on $REMOTE_HOST..."
ssh "$REMOTE_USER@$REMOTE_HOST" "id '$USERNAME'" &>/dev/null

if [[ $? -ne 0 ]]; then
    echo "User '$USERNAME' does not exist on the remote server."
else
    read -p "Do you want to delete '$USERNAME' from the remote server as well? [y/N]: " confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

    if [[ "$confirm" == "y" ]]; then
        echo "Connecting to remote server to delete user '$USERNAME'..."
        ssh -t "$REMOTE_USER@$REMOTE_HOST" bash -c "'
            echo \"Stopping all processes for user '$USERNAME'...\"
            USER_PROCS=\$(pgrep -u \"$USERNAME\")
            if [[ -n \"\$USER_PROCS\" ]]; then
                echo \"Killing user processes: \$USER_PROCS\"
                sudo kill -9 \$USER_PROCS
            fi

            echo \"Cleaning up lingering processes...\"
            sudo pkill -u \"$USERNAME\" &>/dev/null
            sudo killall -u \"$USERNAME\" &>/dev/null

            echo \"Deleting user '$USERNAME'...\"
            sudo userdel -r \"$USERNAME\" 2>/dev/null && echo \"User '$USERNAME' deleted.\"

            echo \"Exiting remote server...\"
            exit
        '"
    else
        echo "Remote deletion skipped."
    fi
fi

echo "All operations completed. Back on local machine."
