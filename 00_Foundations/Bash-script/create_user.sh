#!/bin/bash

user=$1
pub_key=$2
role=${3:-} # if not use it empty stirng

# $EUID 0 = root
if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi
# 2 argument or 3 argument only $# numbered argument passed
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: sudo ./create_user.sh <username> \"<public_key>\" [sudo]"
    exit 1
fi
# || return right value if left false  -z mean string lenght zero return true
if [ -z "$user" ] || [ -z "$pub_key" ] ; then 
    echo "Incorrect argument Usage: sudo ./create_user.sh <username> \"<public_key>\""
    exit 1
fi
# return zero if user exist non-zero if not &>/dev/null hides output
if id "$user" &>/dev/null; then 
    echo "Incorrect User already exist"
    exit 1 
fi

useradd -m -s /bin/bash "$user" # -m create home directory -s set default shell = /bin/bash
mkdir -p /home/"$user"/.ssh
chmod 700 /home/"$user"/.ssh
chown "$user":"$user" /home/"$user"/.ssh
echo "$pub_key" > /home/"$user"/.ssh/authorized_keys
chmod 600 /home/"$user"/.ssh/authorized_keys
chown "$user":"$user" /home/"$user"/.ssh/authorized_keys
passwd -l "$user"
if [ "$role" = "sudo" ]; then
    usermod -aG sudo "$user"
fi
echo "User $user created successfully."