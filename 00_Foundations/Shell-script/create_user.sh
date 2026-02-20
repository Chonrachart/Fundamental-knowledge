#!/bin/bash

create_user() {
    useradd -m -s /bin/bash "$user"
    passwd -l "$user"
}

add_pubkey() {
    mkdir -p /home/"$user"/.ssh
    chmod 700 /home/"$user"/.ssh
    chown "$user":"$user" /home/"$user"/.ssh
    echo "$pub_key" > /home/"$user"/.ssh/authorized_keys
    chmod 600 /home/"$user"/.ssh/authorized_keys
    chown "$user":"$user" /home/"$user"/.ssh/authorized_keys
}

grant_sudo() {
    usermod -aG sudo "$user"
    sudo_file="/etc/sudoers.d/${user//[^a-zA-Z0-9_-]/_}"
    echo "$user ALL=(ALL) NOPASSWD:ALL" > "$sudo_file"
    chmod 440 "$sudo_file"
    visudo -cf "$sudo_file"
}

main() {

    # root check
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi

    # argument check
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        echo "ERROR Usage: sudo ./create_user.sh <username> \"<public_key>\" [sudo]"
        exit 1
    fi

    user=$1
    pub_key=$2
    role=${3:-}

    if [ -z "$user" ] || [ -z "$pub_key" ]; then 
        echo "Incorrect argument Usage: sudo ./create_user.sh <username> \"<public_key>\""
        exit 1
    fi

    if id "$user" &>/dev/null; then 
        echo "Incorrect User already exist"
        exit 1 
    fi

    create_user
    add_pubkey

    if [ "$role" = "sudo" ]; then
        grant_sudo
    fi

    echo "User $user created successfully."
}

main "$@"