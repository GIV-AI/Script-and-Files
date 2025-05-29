#!/bin/bash

echo "Please check your quotas before proceeding with this script!"

# Function to validate pod name
validate_pod_name() {
  local pod_name="$1"
  if [[ ! "$pod_name" =~ ^[a-z][a-z0-9-]{0,63}[a-z0-9]$ ]]; then
    echo "Invalid Pod Name. It must start with a lowercase letter, contain lowercase alphanumeric characters and hyphens, and be between 1 and 63 characters long, with no spaces."
    return 1
  fi
  return 0
}

# Function to validate image name
validate_image_name() {
  local image="$1"
  if [[ ! "$image" =~ ^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._/-]+$ ]]; then
    echo "Invalid image name. The format should be '<image_name>:<tag>', with no spaces and exactly one ':'."
    return 1
  fi
  return 0
}

# Function to validate input as a number within a specific range
validate_number() {
    local input=$1
    local min=$2
    local max=$3
    if ! [[ $input =~ ^[0-9]+$ ]] || [ "$input" -lt "$min" ] || [ "$input" -gt "$max" ]; then
        echo "Invalid input: $input is not a valid number in the range $min-$max. Please try again."
        return 1
    fi
    return 0
}

# Function to validate port number within the valid range (1024-65535)
validate_port_number() {
    local port=$1
    local min=1025
    local max=65535
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt "$min" ] || [ "$port" -gt "$max" ]; then
        echo "Invalid input: $port is not a valid port number in the range $min-$max. Please try again."
        return 1
    fi
    return 0
}

# Prompt user for pod name with validation
while true; do
    echo "Enter Pod Name (no spaces):"
    read -r POD_NAME
    if validate_pod_name "$POD_NAME"; then
        break
    fi
done

# Prompt user for Docker image name with validation
while true; do
    echo "Enter Docker Image (e.g., nvcr.io/nvidia/pytorch:23.12-py3):"
    read -r IMAGE
    if validate_image_name "$IMAGE"; then
        break
    fi
done

# Prompt user for CPU request with validation
while true; do
    echo "Enter CPU request (e.g., 1 to 112):"
    read -r CPU_REQUEST
    if validate_number "$CPU_REQUEST" 1 112; then
        break
    fi
done

# Prompt user for memory request with validation
while true; do
    echo "Enter memory request (e.g., 1 to 256 Gi):"
    read -r MEMORY_REQUEST
    if validate_number "$MEMORY_REQUEST" 1 256; then
        break
    fi
done

# Prompt user for GPU memory partition with validation
while true; do
    echo "Choose GPU memory partition:"
    echo "1) 80GB (nvidia.com/gpu)"
    echo "2) 40GB (nvidia.com/mig-3g.40gb)"
    echo "3) 20GB (nvidia.com/mig-2g.20gb)"
    echo "4) 10GB (nvidia.com/mig-1g.10gb)"
    read -p "Enter your choice (1/2/3/4): " GPU_CHOICE
    case $GPU_CHOICE in
        1) GPU_RESOURCE_KEY="nvidia.com/gpu"; break ;;
        2) GPU_RESOURCE_KEY="nvidia.com/mig-3g.40gb"; break ;;
        3) GPU_RESOURCE_KEY="nvidia.com/mig-2g.20gb"; break ;;
        4) GPU_RESOURCE_KEY="nvidia.com/mig-1g.10gb"; break ;;
        *) echo "Invalid choice, please try again." ;;
    esac
done

# Prompt user for GPU resource count with validation
while true; do
    echo "Enter Number of GPU request (1 to 8):"
    read -r GPU_RESOURCE_VALUE
    if validate_number "$GPU_RESOURCE_VALUE" 1 8; then
        break
    fi
done

# Conditional prompt for port number
while true; do
    echo "Do you want to create a service? (yes/no):"
    read -r SPECIFY_PORT
    if [[ "$SPECIFY_PORT" =~ ^[Yy][Ee][Ss]$|^[Nn][Oo]$ ]]; then
        if [[ "$SPECIFY_PORT" =~ ^[Yy][Ee][Ss]$ ]]; then
            while true; do
                echo "Enter Port Number (range: 1024-65535):"
                read -r PORT
                if validate_port_number "$PORT"; then
                    break
                fi
            done
        else
            PORT=""
        fi
        break
    else
        echo "Invalid input. Please answer with 'yes' or 'no'."
    fi
done

# Generate YAML dynamically
cat <<EOF > pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $USER
  labels:
    app: $POD_NAME
spec:
  containers:
  - name: $POD_NAME
    image: $IMAGE
    command: [ "sh", "-c", "while true; do sleep 1000; done" ]  # Infinite run (keeps container alive)
    resources:
      requests:
        cpu: "$CPU_REQUEST"
        memory: "${MEMORY_REQUEST}Gi"
        $GPU_RESOURCE_KEY: "$GPU_RESOURCE_VALUE"
      limits:
        cpu: "$CPU_REQUEST"
        memory: "${MEMORY_REQUEST}Gi"
        $GPU_RESOURCE_KEY: "$GPU_RESOURCE_VALUE"
    volumeMounts:
      - name: $POD_NAME
        mountPath: /data
  volumes:
    - name: $POD_NAME
      persistentVolumeClaim:
        claimName: $USER
EOF

echo "Pod YAML has been created in pod.yaml"

# Apply the pod.yaml
kubectl apply -f pod.yaml
if [ $? -ne 0 ]; then
  echo "Error applying pod.yaml. Exiting."
  exit 1
fi


# Check if pod is running before creating the service
if [[ -n "$PORT" ]]; then
  # checking pod status
  echo "Please wait ....."
  sleep 30
  POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}')
  if [[ "$POD_STATUS" != "Running" ]]; then
    echo "The service will not be created due to pod is in a pending state. Re-check the status of the pod using the command 'kubectl get pod'."
    echo "If it shows 'Pending', follow the guide provided by the system administrator."
    exit 1
  fi
else
  echo "Please wait for a minute and check the status of the pod using the command 'kubectl get pod'."
  echo "If it shows 'Pending', follow the guide provided by the system administrator."
fi



# If port is specified, create the service
if [[ -n "$PORT" ]]; then
  cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: $POD_NAME
  namespace: $USER
spec:
  type: NodePort
  ports:
   - name: application
     port: 8000
     targetPort: $PORT
  selector:
    app: $POD_NAME
EOF

  echo "Service YAML has been created in service.yaml"

  # Apply the service.yaml
  kubectl apply -f service.yaml
  if [ $? -ne 0 ]; then
    echo "Error applying service.yaml. Exiting."
    exit 1
  fi
fi

