#!/usr/bin/env bash

# Function to start or stop an instance
manage_instance() {
    local action="$1"
    gcloud compute instances "$action" cks-master &
    gcloud compute instances "$action" cks-worker &
}

# Check for the correct number of arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <start|stop>"
    exit 1
fi

# Extract the action argument
action="$1"

# Manage both instances based on the provided action
manage_instance "$action"

# Wait for all background processes to finish
wait

echo "Instances ${action}ed successfully."

