###### only flow not real .sh

# 1. Verify current user information
id <old_name>

# 2. Make sure user is NOT logged in (no running processes)
ps -u <old_name>

# 3. Rename the user (UID stays the same)
usermod -l <new_name> <old_name>

# 4. Rename primary group (if group name = old username)
groupmod -n <new_name> <old_name>

# 5. Ensure primary group is correctly assigned
usermod -g <new_name> <new_name>

# 6. Rename and move home directory
usermod -d /home/<new_name> -m <new_name>

# 7. (Optional) Fix ownership if needed
chown -R <new_name>:<new_name> /home/<new_name>

# 8. Verify everything
id <new_name>
ls -ld /home/<new_name>