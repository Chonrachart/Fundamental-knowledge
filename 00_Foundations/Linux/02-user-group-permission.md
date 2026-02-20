# User

```bash
whoami
useradd <user_name>
userdel <user_name>
passwd
su <user_name>
```

- `whoami` show current user.
- `useradd -m <user_name>` create user and home directory.
- `useradd -s /bin/bash <user_name>` create user and set login shell.
- `userdel -r <user_name>` remove user and home directory.
- `passwd` change password.
- `passwd -e <user_name>` password expire force a user to change their 
  password upon next login.
- `passwd -S <user_name>` show password status
  - `L` Locked
  - `P` Password set (usable)
  - `NP` No password
- `su <user_name>` change to specific user.
  
### See create-user.sh to see more flow 
[create-user.sh](../Shell-script/create_user.sh)


# Group

```bash
groups
getent group
groupadd <group_name>
groupdel <group_name>
```

- `groups` Show group of current user.
- `getent group` show all groups and group information in fromat <br>
  `group_name:password:GID:user1,user2,user3`

### Primary Group

- Every Linux user has:
    - 1 Primary Group use when create file ownership become primary group.
    - 0 or more Supplementary Groups


# User Mod and Group Mod

```bash
usermod [option] <user_name>
groupmod [option] <group_name>
```

- `usermod -aG <group_name> <user_name>` Add user to a supplementary group.
  Must use `-a` (append) with `-G` (supplementary group.) or it will overwrite existing groups.
- `usermod -g <group_name> <user_name>` Change primary group. User can have only 
  ONE primary group.
- `usermod -l <new_name> <old_name>` Change username.
- `usermod -d /new/home <user_name>` Change home directory path.
- `usermod -d /new/home -m <user_name>` Change home directory and move
  existing files to new location.
- `usermod -s /bin/bash <user_name>` Change login shell.
- `usermod -L <user_name>` Lock user account (disable password login).
- `usermod -U <user_name>` Unlock user account.
- `groupmod -n <new_name> <old_name>` Change group name.
- `groupmod -g <GID> <group_name>` Change group ID (GID).

### See change-username.sh to see more flow 

[change-username.sh](../Shell-script/change-username.sh)


# Permission

```bash
chmod <mode> <file>
chown <new_own>:<new_own> <file>
```

- see permissoin use `ls -l`
- basic permission
  - Read (4)
  - Write (2)
  - Execute (1)
  - No permission (0)
- 

