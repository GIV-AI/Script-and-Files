#!/bin/bash

# ====== Validation Functions ======
validate_id() {
    local id=$1
    id=$(echo "$id" | xargs)
    if [[ ! "$id" =~ ^[a-z0-9]{1,63}$ ]]; then
        echo "Invalid ID. Use only lowercase letters and numbers (1-63 characters)."
        exit 1
    fi
}

validate_alpha() {
    local input=$1
    input=$(echo "$input" | xargs)
    if [[ ! "$input" =~ ^[a-z]{1,63}$ ]]; then
        echo "Invalid input. Use only lowercase letters (1-63 characters)."
        exit 1
    fi
}

# ====== Remote Info ======
REMOTE_USER="kle-hp-mgmt"
REMOTE_HOST="10.2.0.41"

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
    echo "Remote SSH username or host is empty."
    exit 1
fi

# ====== Gather Info for Username Generation ======
while true; do
    read -p "Enter role (s for student, f for faculty): " role
    role=$(echo "$role" | tr '[:upper:]' '[:lower:]')

    if [[ "$role" != "s" && "$role" != "f" ]]; then
        echo "Invalid role. Use 's' or 'f'."
        continue
    fi

    read -p "Enter institute name: " ins_name
    ins_name=$(echo "$ins_name" | tr '[:upper:]' '[:lower:]')
    validate_alpha "$ins_name"

    read -p "Enter branch/department: " branch
    branch=$(echo "$branch" | tr '[:upper:]' '[:lower:]')
    validate_alpha "$branch"

    read -p "Enter ID: " id
    id=$(echo "$id" | tr '[:upper:]' '[:lower:]')
    validate_id "$id"

    USERNAME="ln-${role}-${ins_name}-${branch}-${id}"
    echo "Generated username: $USERNAME"

    echo "Checking if user exists on remote $REMOTE_HOST..."

    ssh "$REMOTE_USER@$REMOTE_HOST" "id '$USERNAME' &>/dev/null"
    if [ $? -eq 0 ]; then
        echo "User '$USERNAME' already exists on remote. Try again."
        continue
    fi

    read -s -p "Enter password for new user: " PASSWORD
    echo

    echo "Creating user '$USERNAME' on $REMOTE_HOST..."

    ssh -t "$REMOTE_USER@$REMOTE_HOST" bash -c "'
        sudo useradd -m -s /bin/bash \"$USERNAME\" &&
        echo \"$USERNAME:$PASSWORD\" | sudo chpasswd &&
        sudo mkdir -p /home/$USERNAME/.kube &&
        sudo chown $USERNAME:$USERNAME /home/$USERNAME/.kube &&
        echo \"User $USERNAME created successfully.\"
    '"

    echo "Disconnected from remote. Back to local machine."
    break
done

# Validate auto-filled username
if [[ $USERNAME =~ ^ln-(s|f)-[a-z]+-[a-z]+-[a-z0-9]+$ ]]; then
    echo "Valid username format detected: $USERNAME"
else
    echo "Generated username seems invalid. Please double-check format."
    exit 1
fi
Folder_send_to_login_user="/home/kle-dgx/Scripts_and_Files/Kubernetes_login_node/script_file_send_to_login_user/"  # Corrected variable assignment

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
    read -p "Enter 80GB GPU (0-8): " GPU_80GB
    validate_number "$GPU_80GB" 0 8 && break
done

while true; do
    read -p "Enter 40GB GPU (0-8): " GPU_40GB
    validate_number "$GPU_40GB" 0 8 && break
done

while true; do
    read -p "Enter 20GB GPU (0-8): " GPU_20GB
    validate_number "$GPU_20GB" 0 8 && break
done
 
while true; do
    read -p "Enter 10GB GPU (0-8): " GPU_10GB
    validate_number "$GPU_10GB" 0 8 && break
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
CLUSTER_SERVER="https://10.2.0.40:6443"
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
scp config_user.yaml "$USERNAME"@10.2.0.41:/home/$USERNAME/.kube/config
scp -r "$Folder_send_to_login_user"/* "$USERNAME"@10.2.0.41:/home/$USERNAME/
echo "Transfer the generated kubeconfig file to the user's remote directory Successfully"



