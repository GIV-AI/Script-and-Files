#!/bin/bash

# List all system users that match the pattern dgx-rls-*
echo "Checking for rootless Docker users"
MATCHING_USERS=$(getent passwd | cut -d: -f1 | grep '^dgx-rls-')

if [[ -z "$MATCHING_USERS" ]]; then
    echo "No rootless Docker users found."
    exit 0
else
    echo "Available rootless Docker users:"
    echo "$MATCHING_USERS"
    echo
fi

# Prompt for username
echo -n "Enter rootless docker username: "
read USERNAME

# Check if the user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: No such user '$USERNAME' found."
    exit 1
fi

# Check if username starts with "dgx-rls-"
if [[ "$USERNAME" != dgx-rls-* ]]; then
    echo "Warning: '$USERNAME' does not appear to be a rootless Docker user (expected prefix: 'dgx-rls-')."
fi

read -p "Are you sure you want to delete this user? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
	echo "Aborted. User '$USERNAME' was not deleted."
        exit 1
fi

# Disable lingering for the user
sudo loginctl disable-linger "$USERNAME" 2>/dev/null

# Kill user processes
sudo killall -u "$USERNAME" 2>/dev/null
sleep 2
sudo killall -u "$USERNAME" 2>/dev/null

# Delete the user and suppress warnings
sudo userdel -r "$USERNAME" 2>/dev/null

# Confirmation message
echo "User '$USERNAME' has been deleted."
