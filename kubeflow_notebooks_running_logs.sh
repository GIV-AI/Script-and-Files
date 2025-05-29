#!/bin/bash

# Get the outputs of profiles and pods
PROFILE_OUTPUT=$(sudo kubectl get profile)
PODS_OUTPUT=$(sudo kubectl get pods -A)

# Function to pad strings for aligned formatting
add_space() {
    str=$1
    w_length=$2
    strlen=${#str}
    num_sp=$((w_length - strlen))
    spaces=$(printf "%${num_sp}s")
    finalstr="${str}${spaces}"
    echo "$finalstr"
}

# Print header
echo
echo "| $(add_space "Username/Namespace" 35) | $(add_space "Notebook Name" 55) | $(add_space "Age" 10)"
echo "------------------------------------------------------------------------------------------------------"

# Iterate through each profile (namespace)
echo "$PROFILE_OUTPUT" | tail -n +2 | while IFS= read -r line; do
    namespace=$(echo "$line" | awk '{print $1}')

    # Filter namespaces starting with s- or f-
    if [[ "$namespace" != s-* && "$namespace" != f-* ]]; then
        continue
    fi

    echo "$PODS_OUTPUT" | tail -n +2 | \
    grep -v -e "ml-pipeline-visualizationserver" -e "ml-pipeline-ui-artifact" | \
    grep -E "^$namespace[[:space:]]" | while IFS= read -r detail; do

        username=$(echo "$detail" | awk '{print $1}')
        f_username=$(add_space "$username" 35)

        pod_name=$(echo "$detail" | awk '{print $2}')
        pod_name=$(add_space "$pod_name" 55)

        status=$(echo "$detail" | awk '{print $4}')
        age=$(echo "$detail" | awk '{print $NF}')
        f_age=$(add_space "$age" 10)

        if [[ $status == "Running" ]]; then
            echo "| $f_username | $pod_name | $f_age"
	    echo ""
	    echo "Note:- If you need to delete notebook don't add -0 in notebook name"
        fi
    done
done

