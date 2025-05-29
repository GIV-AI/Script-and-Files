# This shell script send the mail 
# Created by: DevOps Team, Global Infoventures
# Date: 26/06/2024

#!/bin/bash

# Get current date, year, and month
DATE=$(date +%d)
YEAR=$(date +%Y)
MONTH=$(date +%B)
CURRENT_DATE=$(date +'%Y-%m-%d')
CURRENT_DATE_TIME=$(date +"%d-%m-%Y-%H-%M")
CURRENT_TIME=$(date '+%-I:%M %P')
CURRENT_DATE_FOLDER=$(date +'%d-%m-%Y')
YESTERDAY_DATE=$(date -d "yesterday" +'%Y-%m-%d')
# Define the base path
MAIN_PATH="/home/kle-dgx/Scripts_and_Files/all_logs_of_dgx_scripts/dgx_summary/$YEAR/$MONTH/$CURRENT_DATE_FOLDER"

