#/bin/bash
#Script for deletion of user

#Check the name space exists or not
check_valid_namespace() {
    local NAMESPACE="$1"
    NAMESPACE_VALID=$(sudo kubectl get ns)
    NAMESPACE_VALID_FIRST_COL=$(echo "$NAMESPACE_VALID" | cut -f 1 -d " ")
    if echo "$NAMESPACE_VALID_FIRST_COL" | grep "^$NAMESPACE$" > /dev/null; then
        echo True
    else
        echo "$1" "does not exist."
    fi
}

#Remove the user details from the dex configmap file
remove_email_lines() {
    profile_name=$1
    input_file=$2
    # Search and remove lines containing the specified email address and the next two lines
    sed -i "/- email: $profile_name\$/ {N; N; d;}" "$input_file"
    echo "Lines removed successfully."
}
