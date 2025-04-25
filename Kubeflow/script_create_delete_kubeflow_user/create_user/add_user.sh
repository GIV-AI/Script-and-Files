#!/bin/bash

create_username() {
  local ins="$1"
  local username="$2"
  local types="$3"
  local id="$4"

  if [ "$types" = "student" ]; then
    result="s-$ins-$username-$id"
  elif [ "$types" = "faculty" ]; then
    result="f-$ins-$username-$id"
  else
    result="Invalid type"
  fi

  echo "$result"
}
# Function to shuffle a string
shuffle_string() {
    echo "$2" | fold -w1 | shuf | tr -d '\n'
}

# Function to modify username
modify_username() {
    local input_username=$1
    local modified_username

    # Check the length of the username
    local length=${#input_username}

    if [ $length -eq 7 ]; then
        # If the length is 7, uppercase two random letters at different positions
        local rand_pos1=$((RANDOM % $length))
        local rand_pos2=$(( (rand_pos1 + (RANDOM % ($length-1)) + 1)  % $length))
        local rand_char1=${input_username:$rand_pos1:1}
        local rand_char2=${input_username:$rand_pos2:1}
        modified_username=${input_username:0:$rand_pos1}${rand_char1^}${input_username:$(($rand_pos1+1))}
        modified_username=${modified_username:0:$rand_pos2}${rand_char2^}${modified_username:$(($rand_pos2+1))}
    elif [ $length -lt 7 ]; then
        local rand_pos1=$((RANDOM % $length))
        local rand_pos2=$(( (rand_pos1 + (RANDOM % ($length-1)) + 1)  % $length))
        local rand_char1=${input_username:$rand_pos1:1}
        local rand_char2=${input_username:$rand_pos2:1}
        modified_username=${input_username:0:$rand_pos1}${rand_char1^}${input_username:$(($rand_pos1+1))}
        modified_username=${modified_username:0:$rand_pos2}${rand_char2^}${modified_username:$(($rand_pos2+1))}
        while [ ${#modified_username} -lt 7 ]; do
            local additional_char=$(head /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c 1)
            modified_username=${modified_username}${additional_char}
        done
    else
        # If the length is greater than 7, extract the first 7 characters and uppercase two random letters at different positions
        modified_username=${input_username:0:7}
        local rand_pos1=$((RANDOM % 7))
        local rand_pos2=$(( (rand_pos1 + (RANDOM % 6) + 1)  % 7))
        local rand_char1=${modified_username:$rand_pos1:1}
        local rand_char2=${modified_username:$rand_pos2:1}
        modified_username=${modified_username:0:$rand_pos1}${rand_char1^}${modified_username:$(($rand_pos1+1))}
        modified_username=${modified_username:0:$rand_pos2}${rand_char2^}${modified_username:$(($rand_pos2+1))}
    fi

    # Generate a random special character and two random digits, then shuffle them
    local special_char=$(head /dev/urandom | tr -dc '!@#$%^&*()?' | head -c 1)
    local digits=$(head /dev/urandom | tr -dc '0-9' | head -c 2)

    local shuffled_chars=$(shuffle_string "${special_char}${digits}")

    modified_username=${modified_username}${shuffled_chars}

    echo "$modified_username"
}

kubeflow_entry() {
  local name="$1"
  local email="$2"
  local cpu="$3"
  local memory="$4"
  local gpu="$5"
  local mig_71="$6"
  local mig_35="$7"
  local mig_18="$8"
  local storage="$9"

  TEMPLATE='''apiVersion: kubeflow.org/v1beta1
kind: Profile
metadata:
  name: %s
spec:
  owner:
    kind: User
    name: %s
  resourceQuotaSpec:
    hard:
      cpu: "%s"
      memory: "%sGi"
      requests.nvidia.com/gpu: "%s"
      requests.nvidia.com/mig-3g.71gb: "%s"
      requests.nvidia.com/mig-2g.35gb: "%s"
      requests.nvidia.com/mig-1g.18gb: "%s"
      requests.storage: "%sGi"
  '''

  output_config=$(printf "$TEMPLATE" "$name" "$email" "$cpu" "$memory" "$gpu" "$mig_71" "$mig_35" "$mig_18" "$storage")

  echo "$output_config" > "$name.yaml"
  #echo "Filled template has been saved to $name.yaml."

}


dex_entry() {
    local file="$1"
    local email="$2"
    local hash_password="$3"

    # Set the word to split the file after
    word="staticClients"

    # Read the file into a variable
    file_contents=$(<"$file")

    # Find the index of the word in the file
    index=$(expr $(echo "$file_contents" | grep -m 1 -n "$word" | cut -d: -f1) - 1)

    # Split the file into two variables
    var1=$(echo "$file_contents" | head -n "$index")

    var2=$(echo "$file_contents" | tail -n +$(($index+1)))

    # Add the lines to the first variable with specified spacing
    var1+="
    - email: $email
      hash: $hash_password
      username: $email"

    # Create a new YAML file with the combined contents
    new_file="dex.yaml"
    echo "$var1" > "$new_file"
    echo "$var2" >> "$new_file"
}
