#!/bin/bash


echo "##################################"
echo "##  Use the code with caution!  ##"
echo "##################################"

echo "List of container most likely started by users that may be utilizing GPUs"
echo ""

# identify which processes are actively utilizing GPUs
# Get the GPU process information
gpu_processes_raw=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits)

# Check if there are any GPU processes
if [ -z "$gpu_processes_raw" ]; then
    gpu_processes=()
    echo "No processes currently utilizing GPUs."
else
    # Store the GPU processes in an array
    IFS=$'\n' read -r -d '' -a gpu_processes <<< "$gpu_processes_raw"
fi

#for element in "${gpu_processes[@]}"; do
#    echo $element
#done    

# Get a list of all Docker container IDs
docker_container_ids=$(docker ps -qa)

# Iterate through each container ID
for container_id in $docker_container_ids; do
    # Get the container's labels
    container_labels=$(docker inspect --format '{{json .Config.Labels}}' $container_id)

    # Check if the container has the label indicating it belongs to Kubernetes
    if [[ $container_labels != *"io.kubernetes.container"* ]]; then
        # Get the container name
        container_name=$(docker inspect --format '{{.Name}}' $container_id)

        # Get the start time of the container
        start_time=$(docker inspect --format '{{.State.StartedAt}}' $container_id)

        # Calculate the duration the container has been running
        duration=$(date -d "$(date -u -d "$start_time" +'%Y-%m-%dT%H:%M:%S.%NZ')" +"%Y-%m-%d %H:%M:%S")

        # Check if the container is utilizing NVIDIA GPUs
        gpu_info=$(docker inspect --format '{{.Config.Env}}' $container_id)

        #Get process is from container id
        #container_pid=$(docker inspect --format '{{.State.Pid}}' $container_id)
        #container_pid=$(docker inspect --format '{{.Id}}' --pid="$process_id" "$(docker ps -q --no-trunc)")
        #container_pids=($(docker top $container_id | awk 'NR>1 {print $2}'))
        #for element in "${container_pids[@]}"; do
        #    echo $element
        #done

        # Check if the container is running
        is_running=$(docker inspect --format '{{.State.Running}}' $container_id 2>/dev/null)

        if [ "$is_running" == "true" ]; then
            container_pids=($(docker top $container_id | awk 'NR>1 {print $2}'))
        else
            container_pids=($(docker inspect --format '{{.State.Pid}}' $container_id))
        fi

        for container_pid in "${container_pids[@]}"; do
            found=false
            if [[ $gpu_info == *"NVIDIA"* ]]; then
                for element in "${gpu_processes[@]}"; do
                    if [ "$element" == "$container_pid" ]; then
                        found=true
                        break  # exit the loop if the value is found
                    fi
                done
                if [ "$found" == true ]; then
                    echo "Container ID: $container_id, Container Process ID: $container_pid, Name: $container_name, Running since: $duration, Actively Using NVIDIA GPU"
                else
                    echo "Container ID: $container_id, Container Process ID: $container_pid, Name: $container_name, Running since: $duration, Configured To Utilize NVIDIA GPU But Not Actively Using It"
                fi
            else
                for element in "${gpu_processes[@]}"; do
                    if [ "$element" == "$container_pid" ]; then
                        found=true
                        break  # exit the loop if the value is found
                    fi
                done
                if [ "$found" == true ]; then
                    echo "Container ID: $container_id, Container Process ID: $container_pid, Name: $container_name, Running since: $duration, Not Configured to Utilize NVIDIA GPU But Still Actively Using NVIDIA GPU"
                else
		    if [ "$container_name" != "/etcd1" ] && [ "$container_name" != "/deepops-registry" ]; then
                        echo "Container ID: $container_id, Container Process ID: $container_pid, Name: $container_name, Running since: $duration"
		    fi
                fi
            fi
      done
    fi
done

