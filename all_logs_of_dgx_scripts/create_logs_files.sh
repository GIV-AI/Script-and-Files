#!/bin/bash

echo "Processing..... please wait for 10 mintues"
# Call configuartion file 
source /home/kle-dgx/Scripts_and_Files/all_logs_of_dgx_scripts/configuration.sh

# multiple execution

if [ -d "$MAIN_PATH" ]
then
        mv "$MAIN_PATH" "${MAIN_PATH}_${CURRENT_TIME}"
fi

mkdir -p "$MAIN_PATH"

# Create directories if they don't exist
mkdir -p "$MAIN_PATH/health"
mkdir -p "$MAIN_PATH/power"
mkdir -p "$MAIN_PATH/gpu"
mkdir -p "$MAIN_PATH/network"
mkdir -p "$MAIN_PATH/disk"
mkdir -p "$MAIN_PATH/all_running_containers"
mkdir -p "$MAIN_PATH/all_rootless_containers"
mkdir -p "$MAIN_PATH/login_node_running_pods_logs"

# Redirect health information
sudo nvsm show health > "$MAIN_PATH/health/$DATE.txt"

# Redirect power information
sudo nvsm show power > "$MAIN_PATH/power/$DATE.txt"

# Redirect GPU information
sudo nvsm show gpu > "$MAIN_PATH/gpu/$DATE.txt"
sudo nvidia-smi > "$MAIN_PATH/gpu/${DATE}process.txt"

# Redirect network information
sudo netstat -tulpen > "$MAIN_PATH/network/$DATE.txt"

# Redirect disk information
sudo df -h > "$MAIN_PATH/disk/$DATE.txt"

# Call the next script
/home/kle-dgx/Scripts_and_Files/all_logs_of_dgx_scripts/filter_docker_containers_using_gpu.sh > "$MAIN_PATH/all_running_containers/$DATE.txt"
/home/kle-dgx/Scripts_and_Files/all_logs_of_dgx_scripts/filter_rootless_docker_containers_using_gpu.sh > "$MAIN_PATH/all_rootless_containers/$DATE.txt"

sleep 300
# Call the next script
/home/kle-dgx/Scripts_and_Files/all_logs_of_dgx_scripts/dgx_logs_summary.sh

# Exit script
exit

