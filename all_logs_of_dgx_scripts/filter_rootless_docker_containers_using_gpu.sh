#!/bin/bash

USERNAMES=($(awk -F: '$3 >= 1000 && $1 ~ /^dgx-rls/ { print $1 }' /etc/passwd))

show_tables() {
    echo "Rootless Users Details:"
    echo "==========================================================================================================================================="
    printf "%-5s | %-47s | %-8s | %-13s | %-17s | %-16s | %-15s\n" "S.No" "Username" "User ID" "Docker Images" "Running Container" "Exited Container" "Total Container"
    echo "------+-------------------------------------------------+----------+---------------+-------------------+------------------+----------------"

    i=1
    for USER in "${USERNAMES[@]}"; do
        USER_ID=$(id -u "$USER" 2>/dev/null)
        [ -z "$USER_ID" ] && continue

        SOCK="/run/user/$USER_ID/docker.sock"
        [ ! -S "$SOCK" ] && continue

        export DOCKER_HOST=unix://$SOCK

        IMAGES=$(sudo -u "$USER" docker images -q 2>/dev/null | sort -u | wc -l)
        RUNNING=$(sudo -u "$USER" docker ps -q --filter status=running 2>/dev/null | wc -l)
        EXITED=$(sudo -u "$USER" docker ps -q --filter status=exited 2>/dev/null | wc -l)
        TOTAL=$(sudo -u "$USER" docker ps -aq 2>/dev/null | wc -l)

        printf "%-5s | %-47s | %-8s | %-13s | %-17s | %-16s | %-15s\n" "$i" "$USER" "$USER_ID" "$IMAGES" "$RUNNING" "$EXITED" "$TOTAL"
        ((i++))
    done

    echo "==========================================================================================================================================="
    echo ""
    echo ""
    echo "Running Rootless Containers Details:"
    echo "======================================================================================================================================================================================"
    printf "%-5s | %-47s | %-15s | %-20s | %-20s | %-9s | %-12s | %-9s | %-18s\n" "S.No" "Username" "Container ID" "Container Name" "Created On" "Status" "NVIDIA GPU" "MIG GPU" "Actively Using GPU"
    echo "------+-------------------------------------------------+-----------------+----------------------+----------------------+-----------+--------------+----------+----------------------"

    j=1
    declare -gA CONTAINER_MAP

    # Get all active GPU process PIDs
    GPUPIDS=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null)
    
    for USER in "${USERNAMES[@]}"; do
        USER_ID=$(id -u "$USER" 2>/dev/null)
        [ -z "$USER_ID" ] && continue

        SOCK="/run/user/$USER_ID/docker.sock"
        [ ! -S "$SOCK" ] && continue

        export DOCKER_HOST=unix://$SOCK

        CONTAINERS=$(sudo -u "$USER" docker ps -aq)

        for CID in $CONTAINERS; do
            STATUS=$(sudo -u "$USER" docker inspect -f '{{.State.Status}}' "$CID" 2>/dev/null)
            CNAME=$(sudo -u "$USER" docker inspect -f '{{.Name}}' "$CID" 2>/dev/null | sed 's/^\/\(.*\)/\1/')
            CREATED_RAW=$(sudo -u "$USER" docker inspect -f '{{.Created}}' "$CID" 2>/dev/null)
            CREATED_ON=$(date -d "$CREATED_RAW" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

            GPU="No"
            MIG="No"
            ACTIVE="No"

            if [ "$STATUS" = "running" ]; then
                GPU_INFO=$(sudo -u "$USER" docker exec -u root "$CID" nvidia-smi -L 2>/dev/null)

                if echo "$GPU_INFO" | grep -q "GPU"; then
                    GPU="Yes"
                fi

                MIG=$(echo "$GPU_INFO" | grep MIG | awk '{print $2}' | paste -sd ',' -)
                [ -z "$MIG" ] && MIG="No"

                # Check if container has any GPU processes
                CPIDS=$(sudo -u "$USER" docker top "$CID" -eo pid --no-trunc 2>/dev/null | awk 'NR>1 {print $1}')
                for pid in $CPIDS; do
                    if echo "$GPUPIDS" | grep -q "^$pid$"; then
                        ACTIVE="Yes"
                        break
                    fi
                done
            fi

            printf "%-5s | %-47s | %-15s | %-20s | %-20s | %-9s | %-12s | %-9s | %-18s\n" "$j" "$USER" "$CID" "$CNAME" "$CREATED_ON" "$STATUS" "$GPU" "$MIG" "$ACTIVE"
            CONTAINER_MAP["$j"]="$USER:$CID"
            ((j++))
        done
    done

    echo "======================================================================================================================================================================================"
}

show_tables
