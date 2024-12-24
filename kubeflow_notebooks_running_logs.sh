#!/bin/bash

# Run the commands and store the outputs in variables
PROFILE_OUTPUT=$(sudo kubectl get profile)
PODS_OUTPUT=$(sudo kubectl get pods -A)


# Read profiles.txt from the second line
add_space() {
    str=$1
    w_length=$2
    strlen=${#str}
    num_sp=$((w_length - strlen))
    spaces=$(printf "%${num_sp}s")
    finalstr="${str}${spaces}"
    echo "$finalstr"
}
echo
echo "| $(add_space "Username/Namespace" 35) | $(add_space "POD Name" 55) | $(add_space "Age" 10)"
echo "------------------------------------------------------------------------------------------------------"
echo "$PROFILE_OUTPUT" |tail -n +2 | while IFS= read -r line; do
    namespace=$(echo "$line" | awk '{print $1}')
    echo "$PODS_OUTPUT" | tail -n +2 | grep -v -e "ml-pipeline-visualizationserver" -e "ml-pipeline-ui-artifact" | grep -e "$namespace" | while IFS= read -r detail; do
        username=$(echo "$detail" | awk '{print $1}')
        f_username=$(add_space $username 35)

        pod_name=$(echo "$detail" | awk '{print $2}')
        pod_name=$(add_space $pod_name 55)

        status=$(echo "$detail" | awk '{print $4}')
        age=$(echo "$detail" | awk '{print $NF}')
        f_age=$(add_space $age 10)
        if [[ $status == "Running" ]]; then
            echo "| $f_username | $pod_name | $f_age"
        fi
    done
done

