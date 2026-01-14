#!/bin/bash

set -euo pipefail

EXISTING_USER="olduser"

function create_user_if_not_exists() {
    if id "$EXISTING_USER" &>/dev/null; then
        echo "User $EXISTING_USER already exists."
    else
        echo "Creating user $EXISTING_USER ..."
        useradd -m -s /bin/bash "$EXISTING_USER"
        echo "User $EXISTING_USER created."
    fi

    # Verify if the user was created successfully
    if id "$EXISTING_USER" &>/dev/null; then
        echo "Verification successful: User $EXISTING_USER exists."
    else
        echo "Verification failed: User $EXISTING_USER does not exist." >&2
        exit 1
    fi
}

create_user_if_not_exists