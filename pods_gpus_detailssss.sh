#!/bin/bash


pods=$(sudo kubectl get pods -A | grep -E '^(s-|f-|gi-).*' | awk '$2 !~ /^ml-/')

counter=1

temp_file=$(mktemp)

host_gpu_info=$(nvidia-smi -L)

while IFS= read -r pod; do
  namespace=$(echo "$pod" | awk '{print $1}')
  pod_name=$(echo "$pod" | awk '{print $2}')

  gpu_info=$(sudo kubectl exec "$pod_name" -n "$namespace" -- nvidia-smi -L 2>/dev/null)

  if [ -z "$gpu_info" ]; then
    continue
  fi

  gpu_uuid=""
  host_gpu_id=""
  mig_device_id=""

  while IFS= read -r line; do
    if [[ $line == *"GPU 0"* ]]; then
      gpu_uuid=$(echo "$line" | awk '{print $NF}' | tr -d ')')
    elif [[ $line == *"MIG"* ]]; then
      mig_uuid=$(echo "$line" | grep -oP 'UUID: \K[^)]+')
      while IFS= read -r host_line; do
        if [[ $host_line == *"$mig_uuid"* ]]; then
          mig_device_id=$(echo "$host_line" | awk '{print $4}' | tr -d ':')
          break
        fi
      done <<< "$(echo "$host_gpu_info" | grep "MIG")"
    fi
  done <<< "$gpu_info"

  while IFS= read -r host_line; do
    if [[ $host_line == *"$gpu_uuid"* ]]; then
      host_gpu_id=$(echo "$host_line" | awk '{print $2}' | tr -d ':')
      break
    fi
  done <<< "$host_gpu_info"

  if [ -n "$mig_device_id" ]; then
    printf "%-6d | %-30s | %-30s | %-6s | %-15s\n" "$counter" "$namespace" "$pod_name" "$host_gpu_id" "$mig_device_id" >> "$temp_file"
  else
    printf "%-6d | %-30s | %-30s | %-6s | %-15s\n" "$counter" "$namespace" "$pod_name" "$host_gpu_id" "N/A" >> "$temp_file"
  fi

  ((counter++))

done <<< "$pods"

# Print table header with separator
echo "---------------------------------------------------------------------------------------------------"
printf "%-6s | %-30s | %-30s | %-6s | %-15s\n" "S.No" "Namespace" "Pod" "GPU" "MIG Device ID"
echo "-------+--------------------------------+--------------------------------+--------+----------------"
cat "$temp_file"
echo "---------------------------------------------------------------------------------------------------"

rm "$temp_file"
