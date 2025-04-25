#!/bin/bash

echo "##################################"
echo "##  Use the code with caution!  ##"
echo "##################################"

echo "List of containers most likely started by users that may be utilizing GPUs"
echo ""

# Identify processes actively utilizing GPUs
gpu_processes_raw=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits)

# Store GPU processes in an array
gpu_processes=()
if [ -n "$gpu_processes_raw" ]; then
    IFS=$'\n' read -r -d '' -a gpu_processes <<< "$gpu_processes_raw"
fi

# Get all Docker container IDs
docker_container_ids=$(docker ps -qa)

# Iterate through each container ID
for container_id in $docker_container_ids; do
    # Get the container's labels to check if it belongs to Kubernetes
    container_labels=$(docker inspect --format '{{json .Config.Labels}}' $container_id)
    if [[ $container_labels == *"io.kubernetes.container"* ]]; then
        continue
    fi

    # Get container metadata
    container_name=$(docker inspect --format '{{.Name}}' $container_id)
    start_time=$(docker inspect --format '{{.State.StartedAt}}' $container_id)
    duration=$(date -d "$(date -u -d "$start_time" +'%Y-%m-%dT%H:%M:%S.%NZ')" +"%Y-%m-%d %H:%M:%S")
    gpu_info=$(docker inspect --format '{{.Config.Env}}' $container_id)
    is_running=$(docker inspect --format '{{.State.Running}}' $container_id 2>/dev/null)

    # Get container processes
    if [ "$is_running" == "true" ]; then
        container_pids=($(docker top $container_id | awk 'NR>1 {print $2}'))
    else
        container_pids=($(docker inspect --format '{{.State.Pid}}' $container_id))
    fi

    # Check if any process in the container is using the GPU
    actively_using_gpu=false
    for container_pid in "${container_pids[@]}"; do
        for gpu_pid in "${gpu_processes[@]}"; do
            if [ "$container_pid" == "$gpu_pid" ]; then
                actively_using_gpu=true
                break 2  # Exit both loops if found
            fi
        done
    done

    # Determine output based on GPU configuration and usage
    if [[ $gpu_info == *"NVIDIA"* ]]; then
        if [ "$actively_using_gpu" == true ]; then
            echo "Container ID: $container_id, Name: $container_name, Running since: $duration, Actively Using NVIDIA GPU"
        else
            echo "Container ID: $container_id, Name: $container_name, Running since: $duration, Configured To Utilize NVIDIA GPU But Not Actively Using It"
        fi
    else
        if [ "$actively_using_gpu" == true ]; then
            echo "Container ID: $container_id, Name: $container_name, Running since: $duration, Not Configured to Utilize NVIDIA GPU But Still Actively Using NVIDIA GPU"
        else
            if [ "$container_name" != "/etcd1" ] && [ "$container_name" != "/deepops-registry" ]; then
                echo "Container ID: $container_id, Name: $container_name, Running since: $duration"
            fi
        fi
    fi
done

