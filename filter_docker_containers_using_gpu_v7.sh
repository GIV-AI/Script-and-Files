#!/bin/bash

echo "##################################"
echo "##  Use the code with caution!  ##"
echo "##################################"
echo ""

separatort0="------------------------------------------------------------------------------------------------------------------------------------------"
separatort1="--------------------------+---------------------------------------------------------------------------------------------------------------"

# Displaying the explanation of various fields in a table format
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
echo "$separatort1"
printf "%-26s| %-109s|\n" "GPU MIG Size" "Current MIG GPU Utilise"
echo "$separatort1"
printf "%-26s| %-109s|\n" "Process Count" "Number of processes running in the container."
echo $separatort0

# Abbreviation section for GPU Status
echo ""
echo "Abbreviation used:"
echo "-------------------------------"
echo "NCNA: Not Configured and Not Active"
echo "AG: Actively Using GPU"
echo "CNA: Configured, Not Active"
echo "NCA: Not Configured, But Active"
echo "N/A: Not Available"
echo ""

# List of containers
echo "List of containers most likely started by users that may be utilizing GPUs:"
echo "----------------------------------------------------------------------------"

table_header=$(printf "%-13s| %-24s| %-10s| %-20s| %-12s| %-30s| %-11s| %-13s| %-8s|\n%-13s| %-24s| %-10s| %-20s| %-12s| %-30s| %-11s| %-13s| %-8s|" \
"Container ID" "Container Name" "Status" "Running since" "CPU Usage" "Memory Usage" \
"GPU Status" "GPU MIG Size" "Process" " " " " " " " " " " " " " " "Count")

start=$(echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------")
table_separator=$(echo "-------------+-------------------------+-----------+---------------------+-------------+-------------------------------+------------+--------------+----------")

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
        gpu_status="NCNA"  # Default status

        # Check if the container is running
        if [ "$status" == "running" ]; then
            # Check if the container can run nvidia-smi
            if docker exec "$container_id" nvidia-smi &>/dev/null; then
                # Check if the container is actively using GPU
                container_pids=($(docker top "$container_id" 2>/dev/null | awk 'NR>1 {print $2}'))
                for pid in "${container_pids[@]}"; do
                    if [[ " ${gpu_processes[@]} " =~ " ${pid} " ]]; then
                        gpu_status="AG"  # Actively Using GPU
                        break
                    fi
                done
                if [ "$gpu_status" != "AG" ]; then
                    gpu_status="CNA"  # Configured, Not Active
                fi
            else
                gpu_status="NCA"  # Not Configured, But Active (if any GPU process is found)
                for pid in "${container_pids[@]}"; do
                    if [[ " ${gpu_processes[@]} " =~ " ${pid} " ]]; then
                        gpu_status="NCA"
                        break
                    fi
                done
            fi
        else
            gpu_status="NCNA"  # Not Configured and Not Active if container is not running
        fi

        # Get GPU MIG size
        container_gpu="N/A"
        if [ "$status" == "running" ]; then
            container_gpu=$(docker exec "$container_id" nvidia-smi -L 2>/dev/null)
            if echo "$container_gpu" | grep -q "MIG"; then
                container_gpu=$(echo "$container_gpu" | grep "MIG" | awk '{print $2}')
            elif echo "$container_gpu" | grep -q "GPU"; then
                container_gpu="40gb"
            else
                container_gpu="N/A"
            fi
        fi

        # Get process IDs
        container_pids=($(docker top "$container_id" 2>/dev/null | awk 'NR>1 {print $2}'))
        pids_count=${#container_pids[@]}

        # Skip special containers (etcd1, deepops-registry)
        if [[ "$container_name" != "etcd1" && "$container_name" != "deepops-registry" ]]; then
            table_rows+=("$(printf "%-13s| %-24s| %-10s| %-20s| %-12s| %-30s| %-11s| %-13s| %-8s|" \
            "$container_id" "$container_name" "$status" "$duration" "$cpu_usage" "$mem_usage" \
            "$gpu_status" "$container_gpu" "$pids_count")")
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
