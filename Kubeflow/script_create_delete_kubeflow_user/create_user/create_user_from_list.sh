#call scipts
. ./add_user.sh
# Check if the file exists
if [ -f "$1" ]; then
    echo "Reading file: $1"
else
    echo "File not found."
    exit 1
fi
# Check if the directory exists
if [ -d "generated_tmp_files" ]; then
    echo "Directory already exists."
else
    # Create the directory if it doesn't exist
    mkdir -p "generated_tmp_files"
    echo "Directory created."
fi
# Function to convert uppercase to lowercase
convert_to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Read the file line by line, starting from the second line
awk 'NR>1' "$1" | while IFS=, read -r col1 col2 col3 col4 col5 col6 col7 col8 col9 col10 col11 col12
do
    # Convert col1 and col4 to lowercase
    col1_lowercase=$(convert_to_lowercase "$col1")
    col4_lowercase=$(convert_to_lowercase "$col4")
    col3_lowercase=$(convert_to_lowercase "$col3")
    # Check if column values contain only lowercase alphabetic characters and numbers
    if [[ ! "$col1_lowercase" =~ ^[a-z]+$ ]] || [[ ! "$col3_lowercase" =~ ^[a-z0-9]+$ ]] || [[ ! "$col4_lowercase" =~ ^[a-z]+$ ]]; then
        echo "Please check the input file"
        exit
    fi
    # Execute the script for each line
    username=$(create_username "$col1_lowercase" "$col4_lowercase" "$col3_lowercase")

    # Check if the namespace already exists
    if sudo kubectl get ns "$username" 2>/dev/null; then
        echo "Namespace $username already exists. Skipping commands for this line."
    else
	# Convert variables to integers
        col5=$(awk 'BEGIN {print int('$col5')}')
        col6=$(awk 'BEGIN {print int('$col6')}')
        col7=$(awk 'BEGIN {print int('$col7')}')
        col8=$(awk 'BEGIN {print int('$col8')}')
        col9=$(awk 'BEGIN {print int('$col9')}')
        col10=$(awk 'BEGIN {print int('$col10')}')
        col11=$(awk 'BEGIN {print int('$col11')}')
	col12=$(awk 'BEGIN {print int('$col12')}')

        # Check if variables are within specified range
        if [ "$col5" -gt 0 ] && [ "$col5" -lt 64 ] &&
           [ "$col6" -gt 0 ] && [ "$col6" -lt 128 ] &&
           [ "$col7" -gt 0 ] && [ "$col7" -lt 8 ] &&
           [ "$col8" -gt 0 ] && [ "$col8" -lt 8 ] &&
           [ "$col9" -gt 0 ] && [ "$col9" -lt 8 ] &&
	   [ "$col10" -gt 0 ] && [ "$col10" -lt 8 ] &&
	   [ "$col11" -gt 0 ] && [ "$col11" -lt 8 ] &&
           [ "$col12" -gt 0 ] && [ "$col12" -lt 51 ]; then
           
           echo "$username"
           password=$(modify_username "$col1")
           echo "$password"
           hashed_password=$(python3 encryption.py $password)
           echo "$hashed_password"
	   cd generated_tmp_files
           yamlfile=$(kubeflow_entry "$username" "$username" "$col5" "$col6" "$col7" "$col8" "$col9" "$col10" "$col11" "$col12")
           sudo kubectl apply -f "$username".yaml
	   cd ..
           sudo kubectl get configmap dex -n auth -o yaml > dex.yaml
           dex_entry=$(dex_entry "dex.yaml" "$username" "$hashed_password")
           sudo kubectl apply -f dex.yaml
           sudo kubectl rollout restart deployment dex -n auth
           # File path for the CSV file
           csv_file="successfully_created_users.csv"

           # Check if the CSV file exists
           if [ ! -e "$csv_file" ]; then
           # Create the CSV file with column headers
           echo "name,username,password,hashed_password" > "$csv_file"
           fi

           # Append the entry to the CSV file
           echo "$col2,$username,$password,$hashed_password" >> "$csv_file"

           echo "Entry saved to $csv_file"
        else
            echo "Values are not within the specified range. Please Check the input file."
        fi

    fi
done
