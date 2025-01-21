#!/bin/bash

# Function to validate the username (branch/department and ID)
validate_id() {
    local id=$1
    # Trim any leading/trailing spaces and validate the id
    id=$(echo "$id" | xargs)  # Remove any leading/trailing spaces
    if [[ ! "$id" =~ ^[a-z0-9]{1,63}$ ]]; then
        echo "Invalid input. It must include only lowercase letters and numbers, no spaces allowed, and must be between 1 and 63 characters."
        exit 1
    fi
}

validate_branch() {
    local branch1=$1
    # Trim any leading/trailing spaces and validate the branch name
    branch1=$(echo "$branch1" | xargs)  # Remove any leading/trailing spaces
    if [[ ! "$branch1" =~ ^[a-z]{1,63}$ ]]; then
        echo "Invalid input. It must include only lowercase letters and numbers, no spaces allowed, and must be between 1 and 63 characters."
        exit 1
    fi
}

# Function to check if the user already exists
user_exists() {
    local username=$1
    if id "$username" &>/dev/null; then
        return 0  # User exists
    else
        return 1  # User doesn't exist
    fi
}

while true; do
    # Ask the user for their role (s for student, f for faculty)
    echo "Enter role (s for student, f for faculty):"
    read role
    role=$(echo "$role" | tr '[:upper:]' '[:lower:]')  # Convert role to lowercase

    # Validate role input
    if [[ "$role" != "s" && "$role" != "f" ]]; then
        echo "Invalid role. Please enter 's' for student or 'f' for faculty."
        continue
    fi

    # Based on the role, prompt for further information
    if [ "$role" == "s" ]; then
        echo "Enter the branch name (e.g., cs, aiml, etc.):"
        read branch_name
        branch_name=$(echo "$branch_name" | tr '[:upper:]' '[:lower:]')  # Convert branch to lowercase
        validate_branch "$branch_name"
        echo "Enter the student ID:"
        read student_id
        student_id=$(echo "$student_id" | tr '[:upper:]' '[:lower:]')  # Convert student ID to lowercase
        validate_id "$student_id"
        username="ln-${role}-${branch_name}-${student_id}"
    elif [ "$role" == "f" ]; then
        echo "Enter the faculty department name (e.g., cs, aiml, etc.):"
        read faculty_dname
        faculty_dname=$(echo "$faculty_dname" | tr '[:upper:]' '[:lower:]')  # Convert faculty department to lowercase
        validate_branch "$faculty_dname"
        echo "Enter the faculty ID:"
        read faculty_id
        faculty_id=$(echo "$faculty_id" | tr '[:upper:]' '[:lower:]')  # Convert faculty ID to lowercase
        validate_id "$faculty_id"
        username="ln-${role}-${faculty_dname}-${faculty_id}"
    fi

    # Check if the user already exists
    if user_exists "$username"; then
        echo "The username '$username' already exists. Please try again."
        continue  # Prompt for role and username again
    fi

    # Validate the username
    username=$(echo "$username" | tr '[:upper:]' '[:lower:]')  # Convert username to lowercase

    # Display the generated username
    echo "Generated username: $username"

    # Ask for password
    echo "Enter password:"
    read -s password

    # Create the user with the generated username
    sudo useradd -m -s /bin/bash $username

    # Set the password for the created user
    echo "$username:$password" | sudo chpasswd

    # Create the .kube directory in the user's home folder
    sudo mkdir -p /home/$username/.kube
    sudo chown $username:$username /home/$username/.kube

    # Confirm user creation, password setting, and .kube directory creation
    echo "User $username created successfully."
    break  # Exit the loop after successful user creation
done
