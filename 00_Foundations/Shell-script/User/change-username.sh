#!/bin/bash

set -e

###### only flow not real .sh

verify_old_user() {
    # 1. Verify current user information
    id <old_name>
}

check_user_not_logged_in() {
    # 2. Make sure user is NOT logged in (no running processes)
    ps -u <old_name>
}

rename_user() {
    # 3. Rename the user (UID stays the same)
    usermod -l <new_name> <old_name>
}

rename_primary_group() {
    # 4. Rename primary group (if group name = old username)
    groupmod -n <new_name> <old_name>
}

ensure_primary_group() {
    # 5. Ensure primary group is correctly assigned
    usermod -g <new_name> <new_name>
}

move_home_directory() {
    # 6. Rename and move home directory
    usermod -d /home/<new_name> -m <new_name>
}

fix_ownership() {
    # 7. (Optional) Fix ownership if needed
    chown -R <new_name>:<new_name> /home/<new_name>
}

verify_result() {
    # 8. Verify everything
    id <new_name>
    ls -ld /home/<new_name>
}

main() {
    verify_old_user
    check_user_not_logged_in
    rename_user
    rename_primary_group
    ensure_primary_group
    move_home_directory
    fix_ownership
    verify_result
}

main "$@"