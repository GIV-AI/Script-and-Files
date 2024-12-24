#!/bin/bash

# Directory to store the log file
output_dir="login_node_running_pods_logs"
mkdir -p "$output_dir"

# Log file name with current date and time
log_file="$output_dir/pod_details_$(date +'%Y-%m-%d_%H-%M-%S').log"

# Initialize the log file with headers
printf "%-6s | %-25s | %-25s | %-10s\n" "S.No." "Namespace" "Pod Name" "Age" > "$log_file"
printf "%s\n" "------------------------------------------------------------------------------------------------" >> "$log_file"

# Get all namespaces and filter ones starting with 'ln-' using grep
namespaces=$(sudo kubectl get namespaces --no-headers | awk '{print $1}' | grep '^ln-')

# Counter for S. No.
serial=1

# Iterate over each namespace
for ns in $namespaces; do
    # Get running pods with their AGE in the namespace
    pod_details=$(sudo kubectl get pods -n "$ns" --no-headers 2>/dev/null| grep 'Running')

    if [[ -n "$pod_details" ]]; then
       while IFS= read -r line; do
        pod_name=$(echo "$line" | awk '{print $1}')
        pod_age=$(echo "$line" | awk '{print $5}')

        # Write the details into the log file with formatting
        printf "%-6s | %-25s | %-25s | %-10s\n" "$serial" "$ns" "$pod_name" "$pod_age" >> "$log_file"
        serial=$((serial + 1))
    done <<< "$pod_details"
    fi
done


# Final line for table format
printf "%s\n" "------------------------------------------------------------------------------------------------" >> "$log_file"

# Notify the user
cat "$log_file"

echo "Log saved at $log_file"

