#!/bin/bash

# Prompt for username
read -p "Enter username: " USERNAME
# Validate the username
if [[ $USERNAME =~ ^ln-(s|f)-[a-z]+-[a-z0-9]+$ ]]; then
    echo "Valid username."
else
    echo "Invalid username. Kindly check the input e.g. ln-s-aiml-123,ln-f-cse-456."
    exit
fi
Folder_send_to_login_user="/home/vips-dgx/Scripts_and_Files/Kubernetes_login_node/script_file_send_to_login_user/"  # Corrected variable assignment

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

# Prompt user for resource hard limits
while true; do
    read -p "Enter CPU (1-112): " CPU
    validate_number "$CPU" 1 112 && break
done

while true; do
    read -p "Enter Memory (in GB, 1-256): " MEMORY
    validate_number "$MEMORY" 1 256 && break
done

while true; do
    read -p "Enter 80GPU (0-9): " GPU_80GB
    validate_number "$GPU_80GB" 0 9 && break
done

while true; do
    read -p "Enter 40GPU (0-9): " GPU_40GB
    validate_number "$GPU_40GB" 0 9 && break
done

while true; do
    read -p "Enter 2g_20GPU (0-9): " GPU_20GB
    validate_number "$GPU_20GB" 0 9 && break
done
 
while true; do
    read -p "Enter 1g_20GPU (1g, 0-9): " GPU_1_20GB
    validate_number "$GPU_1_20GB" 0 9 && break
done

while true; do
    read -p "Enter 10GPU (0-9): " GPU_10GB
    validate_number "$GPU_10GB" 0 9 && break
done

while true; do
    read -p "Enter number of pods (1-10): " PODS
    validate_number "$PODS" 1 10 && break
done

# Ensure the target folder exists
sudo mkdir -p "$Folder_send_to_login_user"  # Create the directory if it doesn't exist
# Check if create_pod_service.sh exists in the target folder, if not, copy it
if [ ! -f "$Folder_send_to_login_user/login_node_create_pod_service.sh" ]; then
    cp login_node_create_pod_service.sh "$Folder_send_to_login_user/"
    echo "login_node_create_pod_service.sh copied to $Folder_send_to_login_user"
else
    echo "login_node_create_pod_service.sh already exists in $Folder_send_to_login_user"
fi
# Save docker images to a particular file so that it can be sent, starting with "nvcr" prefix 
sudo docker images | awk '$1 ~ /^nvcr/ {print $1":"$2}' > "$Folder_send_to_login_user/docker_image_available.txt"  # Corrected output format
# Create and navigate to the user's folder

USER_DIR="login_node_users_directory/$USERNAME"
mkdir -p "$USER_DIR"
cd "$USER_DIR" || exit

# Create namespace for the user
sudo kubectl create namespace "$USERNAME"
# Create a ServiceAccount for the user

cat > serviceaccount.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $USERNAME
  namespace: $USERNAME
EOF

sudo kubectl apply -f serviceaccount.yaml
# Create a Role with dynamic resources and verbs
cat > role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $USERNAME
  namespace: $USERNAME
rules:
- apiGroups: ["","storage.k8s.io"]
  resources:
    - pods
    - pods/log
    - pods/exec
    - pods/attach
    - pods/portforward
    - services
    - endpoints
    - persistentvolumeclaims
    - volumeattachments
    - events
  verbs:
    - get
    - list
    - watch
    - create
    - update
    - patch
    - delete
EOF

sudo kubectl apply -f role.yaml
# Create a RoleBinding for the user

cat > rolebindings.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $USERNAME
  namespace: $USERNAME
subjects:
- kind: ServiceAccount
  name: $USERNAME
  namespace: $USERNAME
roleRef:
  kind: Role
  name: $USERNAME
  apiGroup: rbac.authorization.k8s.io
EOF

sudo kubectl apply -f rolebindings.yaml
# Create a ResourceQuota for the namespace

cat > resourcequota.yaml <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: $USERNAME
spec:
  hard:
    cpu: "$CPU"
    memory: "${MEMORY}Gi"
    requests.nvidia.com/gpu: "$GPU_80GB"
    requests.nvidia.com/mig-3g.40gb: "$GPU_40GB"
    requests.nvidia.com/mig-2g.20gb: "$GPU_20GB"
    requests.nvidia.com/mig-1g.20gb: "$GPU_1_20GB"
    requests.nvidia.com/mig-1g.10gb: "$GPU_10GB"
    pods: "$PODS"
EOF
sudo kubectl apply -f resourcequota.yaml
# Create Persistent Volume (PV)

cat > pv.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $USERNAME
spec:
  capacity:
    storage: 50Gi  
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce  
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual  
  hostPath:
    path: /workspace/login_node_pv/$USERNAME  
EOF
sudo kubectl apply -f pv.yaml
# Create Persistent Volume Claim (PVC)
cat > pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $USERNAME
  namespace: $USERNAME
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi  
  storageClassName: manual 
EOF
sudo kubectl apply -f pvc.yaml
# Extract the CA certificate location and base64 encode it
CA_CERT_LOCATION=$(sudo kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
# Generate the kubeconfig file for the user
TOKEN=$(sudo kubectl create token --duration=87600h "$USERNAME" -n "$USERNAME")
CLUSTER_NAME=$(sudo kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER="https://192.168.14.10:6443"
cat > config_user.yaml <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $CA_CERT_LOCATION
    server: $CLUSTER_SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    namespace: $USERNAME
    user: $USERNAME
  name: $USERNAME-context
current-context: $USERNAME-context
kind: Config
preferences: {}
users:
- name: $USERNAME
  user:
    token: $TOKEN
EOF

sudo kubectl describe ns "$USERNAME" > "$Folder_send_to_login_user/resource_quota.txt"
# Save all generated files in the user's folder
echo "Configuration files created in the folder: ${USER_DIR}"
scp config_user.yaml "$USERNAME"@192.168.14.12:/home/$USERNAME/.kube/config
scp -r "$Folder_send_to_login_user"/* "$USERNAME"@192.168.14.12:/home/$USERNAME/
echo "Transfer the generated kubeconfig file to the user's remote directory Successfully"
