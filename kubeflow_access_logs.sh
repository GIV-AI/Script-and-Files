#!/bin/bash

DIRECTORY_NAME="kubeflow_access_logs"

if [ ! -d "$DIRECTORY_NAME" ]; then
  mkdir "$DIRECTORY_NAME"
  echo "Directory '$DIRECTORY_NAME' created."
fi

# Define the namespace where your pod is located
NAMESPACE="auth"

# Define the label selector for your pod
LABEL_SELECTOR="app=dex"

# Use kubectl to get the pod name
POD_NAME=$(sudo kubectl get pods -n $NAMESPACE -l $LABEL_SELECTOR -o jsonpath='{.items[0].metadata.name}')

# Get the current date and time in the specified format
CURRENT_DATE_TIME=$(TZ=":Asia/Kolkata" date +"%d-%m-%Y-%H-%M")

# Get the access details and extract required information
ACCESS_DETAILS=$(sudo kubectl logs $POD_NAME -n $NAMESPACE | grep -P "login successful" | awk '{gsub(/\\|"|,/, "", $7); print "Date:", substr($1,7,10), "Time(UTC):", substr($1,18,8), "Username:", substr($7,10)}')

#echo "$ACCESS_DETAILS"
# IST offset in seconds (5 hours and 30 minutes)
offset_seconds=$((5 * 3600 + 30 * 60))

while read -r line; do
  date=$(echo $line | awk '{print $2}')
  time=$(echo $line | awk '{print $4}')
  username=$(echo $line | awk '{print $6}')

  ts_utc=$(date -d "${date} ${time}" +%s)

  ts_ist=$((ts_utc + offset_seconds))
  datetime_ist=$(date -d "@$ts_ist" '+%Y-%m-%d %H:%M:%S')
  date_ist=$(echo $datetime_ist | awk '{print $1}')
  time_ist=$(echo $datetime_ist | awk '{print $2}')
  if [ -z "$username" ] ;then
    echo ""
  else
    echo "Date: $date_ist Time(IST): $time_ist Username: $username" >> "${DIRECTORY_NAME}/${CURRENT_DATE_TIME}.log"
    echo "Date: $date_ist Time(IST): $time_ist Username: $username"
  fi
done <<< "$ACCESS_DETAILS"

