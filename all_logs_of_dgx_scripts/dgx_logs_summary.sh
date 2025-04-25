#!/bin/bash

# Call configuartion file 
source /home/jain-dgx/Scripts_and_Files/all_logs_of_dgx_scripts/configuration.sh

FILE_PATH_OF_NOTEBOOK_LOGS="/var/log/calico/cni/cni.log"
FILE_PATH_OF_POWER="$MAIN_PATH/power/$DATE.txt"
FILE_PATH_OF_HEALTH="$MAIN_PATH/health/$DATE.txt"
FILE_PATH_OF_GPU_PROCESS="$MAIN_PATH/gpu/${DATE}process.txt"
FILE_PATH_OF_GPU="$MAIN_PATH/gpu/$DATE.txt"
FILE_PATH_OF_DISK="$MAIN_PATH/disk/$DATE.txt"
FILE_PATH_OF_SSH_ACCESS="/var/log/auth.log /var/log/auth.log.1"
FILE_PATH_OF_RUNNING_NOTEBOOK="$MAIN_PATH/running_notebooks/$DATE.log"
RUNNING_CONTAINER_PATH="$MAIN_PATH/all_running_containers/$DATE.txt"
ROOTLESS_CONTAINER_PATH="$MAIN_PATH/all_rootless_containers/$DATE.txt"

KUBEFLOW_ACCESS_LOG_DIRECTORY_NAME="kubeflow_access_logs"
KUBEFLOW_NOTEBOOK_LOG_DIRECTORY_NAME="kubeflow_notebooks_creations_logs"
RUNNING_NOTEBOOK_LOG_DIRECTORY_NAME="running_notebooks"
RUNNING_DOCKER_CONTAINER_LOG_DIRECTORY_NAME="summary_running_docker_container"
SUMMARY_DIRECTORY_NAME="dgx_logs_summary"
SSH_ACCESS_DIRECTORY_NAME="ssh_users_logs"
ROOTLESS_DOCKER_CONTAINER_LOG_DIRECTORY_NAME="summary_rootless_docker_container"


KUBEFLOW_ACCESS_LOG_FILE_NAME="${MAIN_PATH}/${KUBEFLOW_ACCESS_LOG_DIRECTORY_NAME}/${CURRENT_DATE}.log"
NOTEBOOK_LOG_FILE_NAME="${MAIN_PATH}/${KUBEFLOW_NOTEBOOK_LOG_DIRECTORY_NAME}/${CURRENT_DATE}.log"
ACTIVE_NOTEBOOKS_FILE_NAME="${MAIN_PATH}/${RUNNING_NOTEBOOK_LOG_DIRECTORY_NAME}/${CURRENT_DATE}.log"
SUMMARY_FILE_NAME="${MAIN_PATH}/${SUMMARY_DIRECTORY_NAME}/${CURRENT_DATE}.csv"
SSH_ACCESS_FILE_NAME="${MAIN_PATH}/${SSH_ACCESS_DIRECTORY_NAME}/${CURRENT_DATE}.log"
RUNNING_CONTAINER_FILE_NAME="${MAIN_PATH}/${RUNNING_DOCKER_CONTAINER_LOG_DIRECTORY_NAME}/${CURRENT_DATE}.log"
PROFILE_OUTPUT=$(sudo kubectl get profile)
PODS_OUTPUT=$(sudo kubectl get pods -A)
ROOTLESS_CONTAINER_FILE_NAME="${MAIN_PATH}/${ROOTLESS_DOCKER_CONTAINER_LOG_DIRECTORY_NAME}/${CURRENT_DATE}.log"


if [ ! -d "$MAIN_PATH/$KUBEFLOW_ACCESS_LOG_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$KUBEFLOW_ACCESS_LOG_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$KUBEFLOW_ACCESS_LOG_DIRECTORY_NAME' created."
fi

if [ ! -d "$MAIN_PATH/$KUBEFLOW_NOTEBOOK_LOG_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$KUBEFLOW_NOTEBOOK_LOG_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$KUBEFLOW_NOTEBOOK_LOG_DIRECTORY_NAME' created."
fi
if [ ! -d "$MAIN_PATH/$SUMMARY_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$SUMMARY_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$SUMMARY_DIRECTORY_NAME' created."
fi
if [ ! -d "$MAIN_PATH/$SSH_ACCESS_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$SSH_ACCESS_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$SSH_ACCESS_DIRECTORY_NAME' created."
fi
if [ ! -d "$MAIN_PATH/$RUNNING_NOTEBOOK_LOG_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$RUNNING_NOTEBOOK_LOG_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$RUNNING_NOTEBOOK_LOG_DIRECTORY_NAME' created."
fi
if [ ! -d "$MAIN_PATH/$RUNNING_DOCKER_CONTAINER_LOG_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$RUNNING_DOCKER_CONTAINER_LOG_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$RUNNING_DOCKER_CONTAINER_LOG_DIRECTORY_NAME' created."
fi
if [ ! -d "$MAIN_PATH/$ROOTLESS_DOCKER_CONTAINER_LOG_DIRECTORY_NAME" ]; then
  mkdir "$MAIN_PATH/$ROOTLESS_DOCKER_CONTAINER_LOG_DIRECTORY_NAME"
  echo "Directory '$MAIN_PATH/$ROOTLESS_DOCKER_CONTAINER_LOG_DIRECTORY_NAME' created."
fi



add_space() {
    str=$1
    w_length=$2
    strlen=${#str}
    num_sp=$((w_length - strlen))
    spaces=$(printf "%${num_sp}s")
    finalstr="${str}${spaces}"
    echo "$finalstr"
}


check_reboot(){
        last_reboot_output=$(last reboot | head -n 1)

        if [ -z "$last_reboot_output" ]; then
                echo "$CURRENT_DATE,Reboot = No" >> $SUMMARY_FILE_NAME
                echo "Reboot = No"
                return
        else
        last_reboot_date=$(last reboot | head -n 1 | awk '{print $5 " " $6 " " $7 " " $8}')
        last_reboot_timestamp=$(date -d "$last_reboot_date" +%s)
        current_timestamp=$(date +%s)
        time_diff=$((current_timestamp - last_reboot_timestamp))
        if [ $time_diff -le 86400 ]; then
                echo "$CURRENT_DATE,Reboot = Yes" >> $SUMMARY_FILE_NAME
                echo "Reboot = Yes"
        else
                echo "$CURRENT_DATE,Reboot = No" >> $SUMMARY_FILE_NAME
                echo "Reboot = No" 
        fi
        fi
}

count_kubeflow_users(){
	users_yesterday=$(grep "$YESTERDAY_DATE" "$KUBEFLOW_ACCESS_LOG_FILE_NAME" | grep -oP 'Username: \K\w+[-\w]*' | sort | uniq | wc -l)
	users_today=$(grep "$CURRENT_DATE" "$KUBEFLOW_ACCESS_LOG_FILE_NAME" | grep -oP 'Username: \K\w+[-\w]*' | sort | uniq | wc -l)	
	echo "Yesterday's count: $users_yesterday, Today's count: $users_today"
	total_users=$(($users_yesterday + $users_today))
	echo "$CURRENT_DATE,Login Kubeflow Users,No of Users = $total_users" >> $SUMMARY_FILE_NAME 
	echo "$CURRENT_DATE,Login Kubeflow Users,No of Users = $total_users"
}

system_update_status(){
	update_path="/var/log/apt/history.log"
	if [ ! -s "$update_path" ]; then
		echo "$CURRENT_DATE,System Updates,No"
		echo "$CURRENT_DATE,Any Command running on DGX with "APT" System Updates,No" >> $SUMMARY_FILE_NAME
	else
		echo "$CURRENT_DATE,System Updates,Yes"
		echo "$CURRENT_DATE,System Updates = Yes" >>$SUMMARY_FILE_NAME
	fi
}


get_pods() {
    declare -A user_pods
    declare -A namespace_pod_details
    declare -A seen_summary_keys
    count_keys=()
    details_keys=()
    total_pod=0

    getFields() {
        local log_entry="$1"    
        local date=$(echo "$log_entry" | awk '{print $1}')
        local time_string=$(echo "$log_entry" | awk '{print $2}')
        local time="${time_string%%.*}" # remove milliseconds
        local Pod=$(echo "$log_entry" | grep -o 'Pod="[^\"]*' | cut -d'"' -f2)
        local Namespace=$(echo "$log_entry" | grep -oE 'Namespace="(s|f|gi)-[^\"]*' | cut -d'"' -f2)

        if [ -n "$Namespace" ]; then
            echo "$date, $time, $Namespace, $Pod"
        fi
    }

    echo "Processing..."

    while IFS= read -r line; do
        fields=$(getFields "$line")
        IFS=',' read -r -a field_array <<< "$fields"
        date="${field_array[0]}"
        if [[ "$date" == "$YESTERDAY_DATE" || "$date" == "$CURRENT_DATE" ]]; then
            if [[ -n "${field_array[2]}" && -n "${field_array[3]}" ]]; then
                user="${field_array[2]}"
                pod="${field_array[3]}"

                if [[ ! "${user_pods[$date,$user]}" ]]; then
                    user_pods[$date,$user]=""
                fi

                if ! [[ "${user_pods[$date,$user]}" =~ "$pod" ]]; then
                    c_key="$date,$user"
                    user_pods[$date,$user]+="$pod "
                    d_key="$date,$user,$pod"
                    count_keys+=("$c_key")
                    details_keys+=("$d_key")
                    namespace_pod_details["$date,$user,$pod"]=$fields
                fi
            fi
        fi
    done < <(grep -v -e "ml-pipeline-visualizationserver" -e "ml-pipeline-ui-artifact" "$FILE_PATH_OF_NOTEBOOK_LOGS" | grep "Populated endpoint")

    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Detailed Description <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo "+ ----------------------------------------------------------------------------------------------------------------------------- +" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo -e "| $(add_space 'Date' 14) | $(add_space 'Time' 14) | $(add_space 'Namespace' 40) | $(add_space 'Pod Name' 50)|" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo "| ------------------------------------------------------------------------------------------------------------------------------ |" >> "$NOTEBOOK_LOG_FILE_NAME"

    for key in "${details_keys[@]}"; do
        IFS=',' read -r date user pod <<< "$key"
        IFS=',' read -r d t ns p <<< "${namespace_pod_details[$key]}"
        formatted_namespace=$(add_space "$ns" 40)
        formatted_pod=$(add_space "$p" 50)
        echo -e "| $(add_space "$d" 14) | $(add_space "$t" 14) | $formatted_namespace | $formatted_pod|" >> "$NOTEBOOK_LOG_FILE_NAME"
    done

    echo -e "+ ------------------------------------------------------------------------------------------------------------------------------ +\n" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Summary <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo "+ ---------------------------------------------------------------------- +" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo -e "| $(add_space 'Date' 14) | $(add_space 'Namespace' 40) | $(add_space 'Pod Count' 10) |" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo "| ---------------------------------------------------------------------- |" >> "$NOTEBOOK_LOG_FILE_NAME"

    for user in "${count_keys[@]}"; do
        if [[ -n "${seen_summary_keys[$user]}" ]]; then
            continue
        fi
        seen_summary_keys[$user]=1

        IFS=',' read -r date username <<< "$user" 
        pod_count=$(echo "${user_pods[$user]}" | wc -w)
        ((total_pod+=pod_count))
        formatted_namespace=$(add_space "$username" 40)
        echo -e "| $(add_space "$date" 14) | $formatted_namespace | $(add_space "$pod_count" 10) |" >> "$NOTEBOOK_LOG_FILE_NAME"
    done

    echo "+ ---------------------------------------------------------------------- +" >> "$NOTEBOOK_LOG_FILE_NAME"
    echo "$CURRENT_DATE,Notebook Created by users, No. of notebook = $total_pod" >> "$SUMMARY_FILE_NAME"
    echo "(List of Notebook saved to '$NOTEBOOK_LOG_FILE_NAME')*"
}

power_check(){
    power=$(grep "PowerConsumedWatts = " "$FILE_PATH_OF_POWER" | tac | grep -m 1 "PowerConsumedWatts = ")
    power_consumed=$(echo $power | awk '{print $3}')
    echo "Total Power consumed in watts = $power_consumed"
    echo "$CURRENT_DATE,Power Consumption of DGX,Current Total Power consumed in watts = $power_consumed" >> $SUMMARY_FILE_NAME
}
disk_health() {
    local sys_health=""
    matching_line=$(grep -E ".* out of .* checks are healthy" "$FILE_PATH_OF_HEALTH")
    h_check=$(echo $matching_line | awk '{print $1}' )
    t_check=$(echo $matching_line | awk '{print $4}' )
    if [ "$h_check" == "$t_check" ];then
        sys_health="OK"
        echo "System is healthy."
    else
        sys_health="NOT OK"
        echo "$matching_line"
        echo "System is Unhealthy"
    fi
    echo "$CURRENT_DATE,Current Health Status of DGX = $sys_health"  >> $SUMMARY_FILE_NAME
}

gpu_status(){
    local gpu=""

    last_health=$(grep -B 1 "Health =" "$FILE_PATH_OF_GPU" | tac | grep -m 1 "Health =")
    status=$(echo "$last_health" | awk '{print $3}')
    # echo "$status"
    if [ "$status" == "OK" ]; then
        gpu="OK"
        echo "GPU is healthy."
    else
        gpu="NOT OK"
        echo "GPU is not healthy."
    fi  
    echo "$CURRENT_DATE,Current Status of GPUs = $gpu" >> $SUMMARY_FILE_NAME
}

gpu_process_count(){
    reading=false
    pattern=false
    declare -A gpu_counts
    local total_process=0

    while IFS= read -r line; do
        if [[ $line =~ ^\|=*=*\|=*$ ]]; then
            reading=true
            pattern=true
            continue
        fi
        if [[ $line =~ ^\+-*-\+$ ]] && $pattern; then
            reading=false
            break
        fi

        if $reading; then
            gpu=$(echo $line | awk '{print $2}')
            if [[ $gpu =~ ^[0-9]+$ ]]; then
                ((total_process++))
                ((gpu_counts["$gpu"]++))
            else
                echo "No running Process"
            fi
        fi
    done < "$FILE_PATH_OF_GPU_PROCESS"

    for gpu in "${!gpu_counts[@]}"; do
        echo -e "GPU Id: $gpu Processes: ${gpu_counts[$gpu]}"
    done
    echo "Total running processes : $total_process"
    echo "$CURRENT_DATE,Current Status of GPUs Processing = $total_process" >> $SUMMARY_FILE_NAME

}

disk_status(){
    local used=""
    local aailable=""
    while IFS= read -r line; do
        if [[ "${line: -1}" == "/" ]];then
            filesys=$(echo "$line" | awk '{print $1}') 
            used=$(echo "$line" | awk '{print $(NF-3)}') 
            available=$(echo "$line" | awk '{print $(NF-2)}') 
            usage=$(echo "$line" | awk '{print $(NF-1)}') 
            echo -e "Used Memory : $used \tAvailable: $available \tTotal Usage:$usage \tFile System:$filesys" 
        fi
    done < $FILE_PATH_OF_DISK
    echo "$CURRENT_DATE,Current Disk Storage status Used = $used, Available = $available" >> $SUMMARY_FILE_NAME
}

ssh_access_func(){
    declare -A user_counts
    declare -A access_list

    total_user=0

    if [ ! -f "$SSH_ACCESS_FILE_NAME" ]; then
        echo "Date,Time,User,IP,Port" >> $SSH_ACCESS_FILE_NAME
    fi

    getAuthFields(){
        local log_entry="$1"
        local date=$(echo $log_entry | awk '{print $1" "$2}')
        local time=$(echo $log_entry | awk '{print $3}')
        local user=$(echo $log_entry | awk '{print $9}')
        local ip=$(echo $log_entry | awk '{print $11}')
        local port=$(echo $log_entry | awk '{print $13}')
        local formatted_date=$(date -d "$date" "+%Y-%m-%d")
        # Ensure fields are not empty and do not contain only semicolons
        if [[ -z "$formatted_date" || -z "$time" || -z "$user" || -z "$ip" || -z "$port" || "$user" == ";" || "$ip" == ";" || "$port" == ";" ]]; then
           return
        fi
        echo "$formatted_date, $time, $user, $ip, $port"
    }
    echo "Processing..."
    for logfile in $FILE_PATH_OF_SSH_ACCESS; do
        file=$(sudo grep "Accepted password for .* from .* port .* ssh2$" "$logfile")
    	while IFS= read -r line; do
        	fields=$(getAuthFields "$line")
        	IFS=',' read -r -a field_array <<<  "$fields"
        	date="${field_array[0]}"
        	username="${field_array[2]}"
        	ip="${field_array[3]}"
        	if [[ "$date" == "$CURRENT_DATE" || "$date" == "$YESTERDAY_DATE" ]]; then
        	  if [[ ! "${user_counts["$date,$ip,$username"]}" ]]; then
            	  	((user_counts["$date,$ip,$username"]++))
            		access_list["$date,$ip,$username"]=$fields
        	  fi
		fi
    	done <<< $file
    done
    for user in "${!user_counts[@]}"; do
        IFS=',' read -r date ip username <<< "$user"
        ((total_user++))
        echo "${access_list[$user]}" >> $SSH_ACCESS_FILE_NAME
	echo "${access_list[$user]}"
    done
    echo "$CURRENT_DATE,DGX/System/Docker user login details,How many no. of users login using ssh = $total_user" >> $SUMMARY_FILE_NAME
    echo "(User access list saved to '$SSH_ACCESS_FILE_NAME')*"
}


filter_docker_container(){
    total_containers=$(grep -c "Container ID:" "$RUNNING_CONTAINER_PATH")
    actively_using_gpu=$(grep -c "Actively Using NVIDIA GPU" "$RUNNING_CONTAINER_PATH")
    configured_but_not_using_gpu=$(grep -c "Configured To Utilize NVIDIA GPU But Not Actively Using It" "$RUNNING_CONTAINER_PATH")
    other_containers=$((total_containers - actively_using_gpu - configured_but_not_using_gpu))

    echo -e "$CURRENT_DATE,Total Containers,$total_containers\n$CURRENT_DATE,Containers Actively Using NVIDIA GPU,$actively_using_gpu\n$CURRENT_DATE,Containers Configured To Utilize NVIDIA GPU But Not Actively Using It,$configured_but_not_using_gpu\n$CURRENT_DATE,Other Containers,$other_containers" >> $SUMMARY_FILE_NAME
    echo -e "Total Containers: $total_containers\nContainers Actively Using NVIDIA GPU: $actively_using_gpu\nContainers Configured To Utilize NVIDIA GPU But Not Actively Using It: $configured_but_not_using_gpu\nOther Containers: $other_containers" >> $RUNNING_CONTAINER_FILE_NAME
}


filter_rootless_docker_container() {
    local total_containers
    local running_containers
    local exited_containers
    local gpu_containers

    # Parse total container count from the first table (user summary)
    total_containers=$(awk -F'|' '
        BEGIN { sum=0 }
        /^ *[0-9]+/ && NF >= 7 {
            gsub(/ /, "", $7)
            sum += $7
        }
        END { print sum }
    ' "$ROOTLESS_CONTAINER_PATH")

    # Parse container details (2nd table)
    # Count running containers
    running_containers=$(awk -F'|' '
        /^ *[0-9]+/ && NF >= 6 {
            status = tolower($6)
            gsub(/ /, "", status)
            if (status == "running") count++
        }
        END { print count+0 }
    ' "$ROOTLESS_CONTAINER_PATH")

    # Count exited containers
    exited_containers=$(awk -F'|' '
        /^ *[0-9]+/ && NF >= 6 {
            status = tolower($6)
            gsub(/ /, "", status)
            if (status == "exited") count++
        }
        END { print count+0 }
    ' "$ROOTLESS_CONTAINER_PATH")

    # Count GPU containers
    gpu_containers=$(awk -F'|' '
        /^ *[0-9]+/ && NF >= 7 {
            gpu = tolower($7)
            gsub(/ /, "", gpu)
            if (gpu == "yes") count++
        }
        END { print count+0 }
    ' "$ROOTLESS_CONTAINER_PATH")

    # Output to files
    echo "$CURRENT_DATE,total rootless container: $total_containers,total running rootless container: $running_containers" >> "$ROOTLESS_CONTAINER_FILE_NAME"
    echo "$CURRENT_DATE,total running rootless container with gpu: $gpu_containers,total exiting rootless container: $exited_containers" >> "$ROOTLESS_CONTAINER_FILE_NAME"

    echo "$CURRENT_DATE,total rootless container: $total_containers,total running rootless container: $running_containers" >> "$SUMMARY_FILE_NAME"
    echo "$CURRENT_DATE,total running rootless container with gpu: $gpu_containers,total exiting rootless container: $exited_containers" >> "$SUMMARY_FILE_NAME"
}


kubeflow_running_pods(){

 echo "| $(add_space "Username/Namespace" 35) | $(add_space "POD Name" 55) | $(add_space "Age" 10)"
    echo "------------------------------------------------------------------------------------------------------" 

    echo "| $(add_space "Username/Namespace" 35) | $(add_space "POD Name" 55) | $(add_space "Age" 10)" > $ACTIVE_NOTEBOOKS_FILE_NAME
    echo "------------------------------------------------------------------------------------------------------" >> $ACTIVE_NOTEBOOKS_FILE_NAME

    TMP_OUTPUT=$(mktemp)

    echo "$PROFILE_OUTPUT" | tail -n +2 | while IFS= read -r line; do
        namespace=$(echo "$line" | awk '{print $1}')
        echo "$PODS_OUTPUT" | tail -n +2 | grep -v -e "ml-pipeline-visualizationserver" -e "ml-pipeline-ui-artifact" | grep -e "$namespace" | while IFS= read -r detail; do
            username=$(echo "$detail" | awk '{print $1}')
            f_username=$(add_space "$username" 35)

            pod_name=$(echo "$detail" | awk '{print $2}')
            pod_name=$(add_space "$pod_name" 55)

            status=$(echo "$detail" | awk '{print $4}')
            age=$(echo "$detail" | awk '{print $NF}')
            f_age=$(add_space "$age" 10)

            if [[ $status == "Running" ]]; then
                echo "| $f_username | $pod_name | $f_age" >> "$TMP_OUTPUT"
            fi
        done
    done

    # Remove duplicates, then append to file and print
    sort "$TMP_OUTPUT" | uniq | tee -a "$ACTIVE_NOTEBOOKS_FILE_NAME"
    rm "$TMP_OUTPUT"

    running_pod_count=$(tail -n +3 "$ACTIVE_NOTEBOOKS_FILE_NAME" | wc -l)
    echo "$CURRENT_DATE,Total running pods = $running_pod_count" >> $SUMMARY_FILE_NAME

}

# Function to fetch and log access details
fetch_kubeflow_access_logs() {

  local namespace="auth"
  local label_selector="app=dex"

  local pod_name
  pod_name=$(sudo kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}')

  local current_date_time
  #current_date_time=$(TZ=":Asia/Kolkata" date +"%d-%m-%Y-%H-%M")
  date=$(date +%d)

  local access_details
  access_details=$(sudo kubectl logs "$pod_name" -n "$namespace" | grep -P "login successful" | awk '{gsub(/\\|"|,/, "", $7); print "Date:", substr($1,7,10), "Time(UTC):", substr($1,18,8), "Username:", substr($7,10)}')

  local offset_seconds
  offset_seconds=$((5 * 3600 + 30 * 60))

  while IFS= read -r line; do
    local date
    date=$(echo "$line" | awk '{print $2}')

    local time
    time=$(echo "$line" | awk '{print $4}')

    local username
    username=$(echo "$line" | awk '{print $6}')

    if [ -n "$username" ]; then
      local ts_utc
      ts_utc=$(date -d "${date} ${time}" +%s)

      local ts_ist
      ts_ist=$((ts_utc + offset_seconds))

      local datetime_ist
      datetime_ist=$(date -d "@$ts_ist" '+%Y-%m-%d %H:%M:%S')

      local date_ist
      date_ist=$(echo "$datetime_ist" | awk '{print $1}')

      local time_ist
      time_ist=$(echo "$datetime_ist" | awk '{print $2}')

      echo "Date: $date_ist Time(IST): $time_ist Username: $username" >> "${KUBEFLOW_ACCESS_LOG_FILE_NAME}"
    elif [ ! -f "${KUBEFLOW_ACCESS_LOG_FILE_NAME}" ]; then
      touch "${KUBEFLOW_ACCESS_LOG_FILE_NAME}"
    
    fi
  done <<< "$access_details"
}

# Call the function
fetch_kubeflow_access_logs

echo -e "\n-------------------------------------- User access to DGX -------------------------------------\n"
ssh_access_func
echo -e "\n--------------------------------- Evaluating Power Consumption --------------------------------\n"
power_check
echo -e "\n------------------------------------ Health Check Running -------------------------------------\n"
disk_health
echo -e "\n-------------------------------------- GPU Health Status --------------------------------------\n"
gpu_status
echo -e "\n------------------------------ Evaluating Runing Processes on GPU -----------------------------\n"
gpu_process_count
echo -e "\n------------------------------------ Evaluating Disk Usage ------------------------------------\n"
system_update_status
echo
check_reboot
echo
disk_status
echo -e "\n----------------------------------- Evaluating Pod Creation -----------------------------------\n"
count_kubeflow_users
echo
kubeflow_running_pods
echo
get_pods
echo
filter_docker_container
echo
filter_rootless_docker_container
echo -e "\n-----------------------------------Kubeflow Users Logs-----------------------------------------\n"
fetch_kubeflow_access_logs
echo -e "\n-----------------------------------------------------------------------------------------------\n"
echo "(Summary of the log files saved to '$SUMMARY_FILE_NAME')*"
echo 
