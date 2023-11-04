#!/bin/bash

set -euo pipefail
function main() {
	# Start of the script execution
	echo "Detecting Operating System..."
	detect_os

	# Call function to setup Podman pod
	setup_pod

	# Call function to setup SSH on FastAPI container
	setup_ssh
}

# Function to setup the Podman pod
setup_pod() {
    echo "Loading Podfile and creating the pod..."
    podman play kube podfile.yaml
    echo "Pod has been set up."
}

# Function to install and setup SSH on FastAPI container
setup_ssh() {
    echo "Setting up SSH in the FastAPI container..."

    # Get the 'fastapi-app' container ID
    FASTAPI_CONTAINER=$(podman ps --filter name=fastapi-app --format "{{.ID}}")

    # Install SSH server
    podman exec $FASTAPI_CONTAINER apt-get update
    podman exec $FASTAPI_CONTAINER apt-get install -y openssh-server

    # Set up SSH server
    podman exec $FASTAPI_CONTAINER bash -c "echo 'root:password' | chpasswd"
    podman exec $FASTAPI_CONTAINER sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    podman exec $FASTAPI_CONTAINER rm -f /etc/ssh/ssh_host_*
    podman exec $FASTAPI_CONTAINER dpkg-reconfigure openssh-server
    podman exec $FASTAPI_CONTAINER service ssh restart

    echo "SSH setup complete."
    echo "You can access FastAPI at http://localhost:8000"
    echo "You can SSH into the FastAPI container using 'ssh root@localhost -p 2222'. The password is 'password'."
}

# Function to detect the Operating System
detect_os() {
    case "$(uname -s)" in
       Darwin)
         echo 'Mac OS Detected'
         ;;
       Linux)
         echo 'Linux OS Detected'
         if [ -f /etc/lsb-release ]; then
           . /etc/lsb-release
           if [ "$DISTRIB_ID" == "Ubuntu" ]; then
             echo "Ubuntu Detected"
           else
             echo "Non-Ubuntu Linux detected"
           fi
         else
           echo "Non-Ubuntu, non-LSB Linux detected"
         fi
         ;;
       CYGWIN*|MINGW32*|MSYS*|MINGW*)
         echo 'Windows Detected'
         ;;
       *)
         echo 'Unknown Operating System'
         read -p "Please enter your operating system (mac/linux/windows): " os
         if [ "$os" == "mac" ]; then
             echo 'Mac OS Detected'
         elif [ "$os" == "linux" ]; then
             echo 'Linux OS Detected'
         elif [ "$os" == "windows" ]; then
             echo 'Windows Detected'
         else
             echo 'Unsupported Operating System'
             exit 1
         fi
         ;;
    esac
}

main
