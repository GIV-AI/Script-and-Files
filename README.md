This repository contains various scripts, configurations, and utilities related to Kubeflow, Kubernetes login nodes, DGX systems, rootless Docker, and GPU container monitoring.

---

## Folder and File Description

### 1. Kubeflow Folder
Contains templates and scripts related to Kubeflow setup and user management:
- **Creating_Kubeflow_Images template**
  - `Dockerfile` — Dockerfile template for Kubeflow images
  - `Dockerfile-RAPIDS` — Dockerfile template with RAPIDS support
  - `yas.yaml.backup` — Backup YAML configuration file
- **Manual_User_Creation** — Instructions and scripts for manual user creation
- **delete_user** — Script to delete a user

---

### 2. Kubernetes_login_node Folder
Contains logs, user YAML files, and scripts related to managing users and pods on the Kubernetes login node:
- **login_node_running_pods_logs** — Folder containing logs of running pods on the login node
- **login_node_users_directory** — Contains user YAML files
- **script_file_send_to_login_user** — Files sent to users upon creation:
  - `docker_image_available.txt`
  - `login_node_create_pod_service.sh` — Script to create pod service
  - `resource_quota.txt`
- **login_node_create_pod_service.sh** — Script to create pod service (sent to user)
- **login_node_create_user.sh** — Script to create a login user
- **login_node_delete_user.sh** — Script to delete a login user
- **login_node_running_pods.sh** — Script to get login node pods details

---

### 3. all_logs_of_dgx_scripts Folder
Contains scripts run by cronjob to generate and manage DGX system logs:
- `configuration.sh` — Script to change configuration
- `create_logs_files.sh` — Script to generate logs
- `dgx_logs_summary.sh` — Script to generate log summaries
- `filter_docker_containers_using_gpu.sh` — Logs rootful Docker containers using GPUs
- `filter_rootless_docker_containers_using_gpu.sh` — Logs rootless Docker containers using GPUs

---

### 4. dgx_pod_details_v6 Folder
- `pod_details_v6.sh` — Script to collect DGX pod details and generate a report tar file for sharing

---

### 5. kubeflow_access_logs Folder
Contains examples of Kubeflow access log files

---

### 6. rootless-docker Folder
Scripts to manage rootless Docker users and containers:
- `rootless_docker_create_user.sh` — Create a rootless Docker user
- `rootless_docker_delete_user.sh` — Delete a rootless Docker user
- `show_containers_details_rootless_docker_container.sh` — Show running rootless Docker container details
- `show_running_and_delete_rootless_docker_container.sh` — Show and delete running rootless Docker containers

---

### 7. Other Scripts and Files
- `filter_docker_containers_using_gpu_v7.sh` — Get all Docker containers utilizing GPUs and their MIG configuration
- `kubeflow_access_logs.sh` — Get all users logged into Kubeflow
- `kubeflow_notebooks_running_logs.sh` — List all running Kubeflow notebooks
- `pytorch_gpu_example.py` — Example Python script to check if PyTorch container is utilizing GPU

---
