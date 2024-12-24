#!/bin/bash

echo "Processing...... please wait"
echo""
echo""
# Create a new directory and move into it
dir_name="kubectl_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir "$dir_name"
cd "$dir_name" || exit

# Store the output of kubectl command
kubectl_output="0_kubectl_pods_output.txt"
sudo kubectl get pods -A > "$kubectl_output"

#describe nodes
describe_nodes="1_describe_nodes.txt"
sudo kubectl describe nodes > "$describe_nodes"

# nvidia-smi
nvidia_smi="2_nvidia_smi.txt"
nvidia-smi > "$nvidia_smi"

# resource usage
top_cmd="3_top_cmd.txt"
sudo top -b -n 1 > "$top_cmd"

# get pods wide
get_pods_wide="4_get_pods_wide.txt"
sudo kubectl get pods -A -o wide > "$get_pods_wide"

# desribe ns
describe_ns="5_describe_ns.txt"
sudo kubectl describe ns -A > "$describe_ns"

# configmap for Kubeflow
get_configmap="6_get_configmap.txt"
sudo kubectl get configmap jupyter-web-app-config-84khm987mh -n kubeflow -o yaml > "$get_configmap"


# Process each pod and store results
while read -r namespace name status rest; do
    if [[ $namespace != "NAMESPACE" ]]; then
        # Create a file for each pod with its details
        pod_file="${namespace}_${name}_details.txt"
        echo "Namespace: $namespace" > "$pod_file"
        echo "Pod Name: $name" >> "$pod_file"
        echo "Status: $status" >> "$pod_file"
        echo "Other Details: $rest" >> "$pod_file"
        sudo kubectl describe pods "$name" -n "$namespace" >> "$pod_file"

        # Store logs for each pod
        log_file="${namespace}_${name}_logs.txt"
        sudo kubectl logs -n "$namespace" "$name" &> "$log_file"

        if [ $? -ne 0 ]; then
            echo "Failed to retrieve logs for $namespace/$name" >> "$log_file"
        fi
    fi
done < "$kubectl_output"



# for collecting storage usage
output_file="storage.txt"

get_df_command_output(){
   df_output=$(df -h)
   echo "df command output" >> "$output_file"
   echo "$df_output" >> "$output_file"
   echo "" >> "$output_file"
}

get_ram_usage() {
    ram_usage=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    echo "RAM Usage: $ram_usage" >> "$output_file"
    echo "" >> "$output_file"
}

get_root_directory_storage() {
    echo "Storage of directories in /:" >> "$output_file"
    for dir in /*; do
        if [ -d "$dir" ]; then
            dir_storage=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
            echo "  $dir: $dir_storage" >> "$output_file"
        fi
    done
    echo "" >> "$output_file"
}

get_user_storage() {
    echo "User Storage Usage:" >> "$output_file"
    for user in $(cut -f1 -d: /etc/passwd); do
        user_storage=$(du -sh /home/$user 2>/dev/null | awk '{print $1}')
        if [ -n "$user_storage" ]; then
            echo "  $user: $user_storage" >> "$output_file"
        fi
    done
    echo "" >> "$output_file"
}

# Execute functions
get_df_command_output
get_ram_usage
get_root_directory_storage
get_user_storage

echo "Storage information saved to $output_file"


# Create a zip file with all results
zip_file="../kubectl_analysis_$(date +%Y%m%d).zip"
zip -r "$zip_file" .
chmod 777 "$zip_file"
echo""
echo""
echo "The report has been successfully generated in the current directory with the name kubectl_analysis. A ZIP file with the same name is also available."
