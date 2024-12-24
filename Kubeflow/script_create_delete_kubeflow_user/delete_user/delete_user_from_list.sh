# Call scripts
. ./delete_user.sh

# Check if the file exists
if [ -f "$1" ]; then
    echo "Reading file: $1"
else
    echo "File not found."
    exit 1
fi

# Read the file line by line, starting from the second line
awk 'NR>1' "$1" | while IFS=, read -r col1 
do
    result=$(check_valid_namespace "$col1")
    if [ "$result" = "True" ]; then
        sudo kubectl delete ns "$col1"
        sudo kubectl delete profile "$col1"
        sudo kubectl get configmap dex -n auth -o yaml > dex.yaml
        remove_email_lines "$col1" "dex.yaml"
        sudo kubectl apply -f dex.yaml
        sudo kubectl rollout restart deployment dex -n auth
        echo "$col1" >> successfully_deleted_users.csv
    else
        echo $result
	echo "$col1 does not exist." >> successfully_deleted_users.csv
    fi
done
