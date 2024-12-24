#!/bin/bash

echo "##################################"
echo "##  Use the code with caution!  ##"
echo "##################################"
echo ""

# Displaying the explanation of various fields in a table format
#!/bin/bash

# Displaying the explanation of various fields in a table format
# echo "Explanation of the Fields Present in the Table"
# echo "-----------------------------------------------"
# echo "Container ID: Unique identifier for the container"
# echo "Container Name: Name of the container"
# echo "Status: Current status of the container"
# echo "        - Created: Container has been created"
# echo "        - Running: Container is currently running"
# echo "        - Exited: Container has stopped running"
# echo "Running Since: Timestamp indicating when the container started running"
# echo "CPU Usage: CPU Usage represents the percentage of CPU resources utilized by the container. In a multi-core system, this value can exceed 100%, reflecting the cumulative usage across all cores."
# echo "Memory Usage: Amount of memory being used by the container"
# echo "GPU Status: Current GPU utilization status"
# echo "            - Not Configured and Not Active"
# echo "                Not Configured to Utilize NVIDIA GPU and Not Actively Using It"
# echo "            - Actively Using GPU" 
# echo "                Configured To Utilize NVIDIA GPU and Actively Using NVIDIA GPU"
# echo "            - Configured, Not Active"
# echo "                Configured To Utilize NVIDIA GPU But Not Actively Using It"
# echo "            - Not Configured, But Active"
# echo "                Not Configured to Utilize NVIDIA GPU But Still Actively"
# echo "            (for more refer to abbreviation section)"
# echo "Process Count: Number of processes running in the container"
# echo "PIDs: Process IDs associated with the running processes"

separatort0="------------------------------------------------------------------------------------------------------------------------------------------"
separatort1="--------------------------+---------------------------------------------------------------------------------------------------------------"

echo "Explanation of the Fields Present in the Table"
echo $separatort0
printf "%-26s| %-109s|\n" "Fields" "Description"
echo $separatort1
printf "%-26s| %-109s|\n" "Container ID" "Unique identifier for the container."
echo "$separatort1"
printf "%-26s| %-109s|\n" "Container Name" "Name of the container."
echo "$separatort1"
printf "%-26s| %-109s|\n" "Status" "Current status of the container:"
printf "%-26s| %-109s|\n" " " "- Created: The container has been created. If the container fails to execute the task, it is also in a"
printf "%-26s| %-109s|\n" " " "           created status."
printf "%-26s| %-109s|\n" " " "- Running: Container is currently running."
printf "%-26s| %-109s|\n" " " "- Exited: Container has stopped running."
echo "$separatort1"
printf "%-26s| %-109s|\n" "Running Since" "Timestamp indicating when the container started running."
echo "$separatort1"
printf "%-26s| %-109s|\n" "CPU Usage" "Represents the percentage of CPU resources utilized by the container. In a multi-core system, this value"
printf "%-26s| %-109s|\n" " " "can exceed 100%."
echo "$separatort1"
printf "%-26s| %-109s|\n" "Memory Usage" "Amount of memory being used by the container."
echo "$separatort1"
printf "%-26s| %-109s|\n" "GPU Status" "Current GPU utilization status:"
printf "%-26s| %-109s|\n" " " "- Not Configured and Not Active: Not Configured to Utilize NVIDIA GPU and Not Actively Using It."
printf "%-26s| %-109s|\n" " " "- Actively Using GPU: Configured to Utilize NVIDIA GPU and Actively Using NVIDIA GPU."
printf "%-26s| %-109s|\n" " " "- Configured, Not Active: Configured to Utilize NVIDIA GPU But Not Actively Using It."
printf "%-26s| %-109s|\n" " " "- Not Configured, But Active: Not Configured to Utilize NVIDIA GPU But Still Actively."
printf "%-26s| %-109s|\n" " " "(For more information, please refer to the abbreviation section given below)"
echo "$separatort1"
printf "%-26s| %-109s|\n" "Process Count" "Number of processes running in the container."

echo $separatort0
# echo "| PIDs                    | Process IDs associated with the running processes.                                                           |"
# echo "------------------------------------------------------------------------------------------------------------------------------------------"

# Abbreviation section for GPU Status
echo ""
echo "Abbreviation for GPU Status as"
echo "-------------------------------"
echo "NCNA: Not Configured and Not Active"
echo "AG: Actively Using GPU"
echo "CNA: Configured, Not Active"
echo "NCA: Not Configured, But Active"
echo ""

# List of containers
echo "List of containers most likely started by users that may be utilizing GPUs:"
echo "----------------------------------------------------------------------------"

# # Print the table header with column titles with pids col
# table_header=$(printf "%-13s| %-21s| %-10s| %-20s| %-15s| %-25s| %-11s| %-14s| %-10s" \
# "Container ID" "Name" "Status" "Running since" "CPU Usage" "Memory Usage" \
# "GPU Status" "Process Count" "PIDs")

table_header=$(printf "%-13s| %-24s| %-10s| %-20s| %-12s| %-30s| %-11s| %-8s|\n\
%-13s| %-24s| %-10s| %-20s| %-12s| %-30s| %-11s| %-8s|" \
"Container ID" "Container Name" "Status" "Running since" "CPU Usage" "Memory Usage" \
"GPU Status" "Process" " " " " " " " " " " " " " " "Count")

# Print a separator line
start=$(echo "-----------------------------------------------------------------------------------------------------------------------------------------------")
table_separator=$(echo "-------------+-------------------------+-----------+---------------------+-------------+-------------------------------+------------+----------")

# Array to store the rows
table_rows=()

# Identify which processes are actively utilizing GPUs
gpu_processes_raw=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits)

# Store the GPU processes in an array if there are any
if [ -n "$gpu_processes_raw" ]; then
    IFS=$'\n' read -r -d '' -a gpu_processes <<< "$gpu_processes_raw"
else
    gpu_processes=()
    echo "No processes currently utilizing GPUs."
fi

echo ""
echo -n "Please wait until the report is being generated..."

# Get a list of all Docker container IDs
docker_container_ids=$(docker ps -qa)

# Iterate through each container ID
for container_id in $docker_container_ids; do
    # Get the container's labels
    container_labels=$(docker inspect --format '{{json .Config.Labels}}' "$container_id" 2>/dev/null)

    # Skip containers belonging to Kubernetes
    if [[ $container_labels != *"io.kubernetes.container"* ]]; then
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null | sed 's/^//')

        # Remove the leading slash and truncate the name if necessary
        container_name="${container_name#/}"
        if [ "${#container_name}" -gt 20 ]; then
            container_name="${container_name:0:20}..."
        fi

        start_time=$(docker inspect --format '{{.State.StartedAt}}' "$container_id" 2>/dev/null)
        duration=$(date -d "$(date -u -d "$start_time" +'%Y-%m-%dT%H:%M:%S.%NZ')" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
        status=$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null)

        # Fetch CPU and memory usage
        stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container_id" 2>/dev/null)
        if [[ -z "$stats" ]]; then
            cpu_usage="N/A"
            mem_usage="N/A"
        else
            cpu_usage=$(echo "$stats" | cut -d',' -f1)
            mem_usage=$(echo "$stats" | cut -d',' -f2)
        fi

        # Check GPU configuration
        gpu_info=$(docker inspect --format '{{.Config.Env}}' "$container_id" 2>/dev/null)
        gpu_status="NCNA"

        # Determine GPU usage
        if [[ "$status" == "running" ]]; then
            if [[ "$gpu_info" == *"NVIDIA_VISIBLE_DEVICES"* ]]; then
                gpu_status="AG"
            else
                gpu_status="NCA"
            fi
        else
            if [[ "$gpu_info" == *"NVIDIA_VISIBLE_DEVICES"* ]]; then
                gpu_status="CNA"
            fi
        fi

        # Get process IDs
        container_pids=($(docker top "$container_id" 2>/dev/null | awk 'NR>1 {print $2}'))
        pids_list=""
        pids_count=${#container_pids[@]}

        # Prepare PIDs list with truncation
        # if [ "$pids_count" -gt 2 ]; then
        #     pids_list="${container_pids[0]}, ${container_pids[1]}, ..."
        # else
        #     pids_list=$(IFS=,; echo "${container_pids[*]}")
        # fi

        # Skip special containers (etcd1, deepops-registry)
        if [[ "$container_name" != "etcd1" && "$container_name" != "deepops-registry" ]]; then
            # table_rows+=("$(printf "%-13s| %-21s| %-10s| %-20s| %-15s| %-25s| %-11s| %-14s| %-20s" \
            table_rows+=("$(printf "%-13s| %-24s| %-10s| %-20s| %-12s| %-30s| %-11s| %-8s|" \
            "$container_id" "$container_name" "$status" "$duration" "$cpu_usage" "$mem_usage" \
            "$gpu_status" "$pids_count" \
            # "$pids_list" \
            )")
        fi
    fi
done

# Print the table
echo ""
echo "$start"
echo "$table_header"
for row in "${table_rows[@]}"; do
    echo "$table_separator"
    echo "$row"
done
echo "$start"
