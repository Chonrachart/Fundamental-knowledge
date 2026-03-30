# Users, Groups, and Permissions

# Overview

- Every Linux process runs as a user (UID); every file has an owner (UID) and a group (GID).
- The kernel enforces access by comparing the process's UID/GID against the file's permission bits.
- Permission bits define read/write/execute for three classes: owner, group, others.

# Architecture

```text
Process (running as UID=1001, GID=1001) opens file
        |
        v
Kernel checks: is process UID == file owner UID?
  → yes: apply owner bits
  → no: is process GID in file's group?
        → yes: apply group bits
        → no: apply others bits
        |
        v
Does the matched bit class allow the requested operation?
  → yes: allow
  → no: EACCES (Permission denied)
```

Note: root (UID=0) bypasses permission checks entirely.

# Core Building Blocks

### User Management

```bash
whoami                              # show current username
id                                  # show UID, GID, and supplementary groups

useradd -m <user>                   # create user + home directory
useradd -m -s /bin/bash <user>      # create user with bash shell
useradd -r <user>                   # system account (no human login, no home)
userdel -r <user>                   # remove user and home directory

passwd <user>                       # set/change password
passwd -e <user>                    # expire password (force change on next login)
passwd -L <user>                    # lock account
passwd -S <user>                    # show password status (L=locked, P=set, NP=none)

su <user>                           # switch to user (requires password)
sudo <command>                      # run command as root (requires sudoers entry)
```

### Group Management

```bash
groups                              # show groups of current user
getent group                        # list all groups (name:password:GID:members)

groupadd <group>                    # create group
groupdel <group>                    # delete group

usermod -aG <group> <user>          # add user to supplementary group (-a = append; never omit -a)
usermod -g <group> <user>           # change primary group
```

Every user has exactly **one primary group** (used for new file ownership) and zero or more supplementary groups.

- `usermod -aG` — **always use `-a`** (append); omitting it replaces all supplementary groups.
- Group membership changes only take effect after the user logs out and back in.

### Modifying Users and Groups

```bash
usermod -l <new> <old>              # rename user
usermod -d /new/home -m <user>      # move home directory
usermod -s /bin/bash <user>         # change login shell
usermod -L <user>                   # lock account
usermod -U <user>                   # unlock account

groupmod -n <new> <old>             # rename group
groupmod -g <GID> <group>           # change GID
```

### Permissions

```bash
ls -l <file>                        # view permission bits + owner + group

chmod 755 <file>                    # set mode numerically
chmod u+x <file>                    # add execute for owner (symbolic)
chmod g-w <file>                    # remove write for group
chmod o+r <file>                    # add read for others
chmod -R 755 <dir>                  # apply recursively

chown <user>:<group> <file>         # change owner and group
chown -R <user>:<group> <dir>       # apply recursively
```

- Without `x` on a directory, you cannot `cd` into it.
- Only root can change file ownership (`chown`).
- Permission check order: owner → group → others; **first match wins**, not most permissive.
- Root (UID=0) bypasses all DAC permission checks.

Related notes:

- [01-Basic-file-and-text-manipulation](./01-Basic-file-and-text-manipulation.md) — file type characters in `ls -l`

### umask

- **Why it exists** — without umask, every new file would be world-readable/writable. umask ensures safe defaults without you running chmod after every file creation.
- **What it is** — Linux starts with base permissions: 666 (files) / 777 (directories) umask subtracts bits from that base
- **One-liner** — default permission when create file or directory

```bash
umask                   # show current mask
umask 022               # files → 644, directories → 755
umask 027               # files → 640, directories → 750
```

- `umask` subtracts bits from default permissions (666 for files, 777 for directories).
- Set persistently in `~/.bashrc` or `/etc/profile`.
- `umask 022` → new files get `644`; `umask 027` → new files get `640`.

### Special Permissions

```bash
chmod 4755 <file>   # setuid  (4) — executable runs as file owner's UID
chmod 2755 <dir>    # setgid  (2) — new files in dir inherit dir's group
chmod 1777 <dir>    # sticky  (1) — only owner/root can delete own files in dir
```

| Bit        | On file            | On directory                      |
| ---------- | ------------------ | --------------------------------- |
| setuid (4) | runs as file owner | (rarely used)                     |
| setgid (2) | runs as file group | new files inherit group           |
| sticky (1) | (ignored)          | only owner can delete their files |


- `setuid` The s in the owner execute position means: "run as the file's owner, not the user who launched it."
```bash
  ls -l /usr/bin/passwd
  # -rwsr-xr-x 1 root root ...
  #    ^
  #    's' = setuid — this program runs as root no matter who calls it
```
``` text
  Normal: when you run a program, it runs as your user.

  Problem: passwd command needs to write to /etc/shadow — but only root can write there. How can a normal user change their own password? w

  You (UID 1001) run passwd
          |
          v
  Without setuid: runs as YOU → can't write /etc/shadow → denied
  With setuid:    runs as ROOT (file owner) → can write /etc/shadow → works
```

- `setgid` Every new file inherits the directory's group instead of the creator's group.
```text
Normal: when you create a file, it gets your primary group.

Problem: you have a shared folder /shared/project for a team. Alice creates a file — it gets group alice. Bob creates a file — it gets group bob. Now they can't edit each other's files.          
                  
  Without setgid:                                                                                                                                                                                    
  /shared/project/
    ├── report.txt     owner:alice  group:alice   ← bob can't edit                                                                                                                                   
    └── data.csv       owner:bob    group:bob     ← alice can't edit                                                                                                                                 
                                                                                                                                                                                          
  With setgid on directory:                                                                                                                                                                          
  /shared/project/    (group: devteam, setgid set)
    ├── report.txt     owner:alice  group:devteam  ← bob can edit                                                                                                                                    
    └── data.csv       owner:bob    group:devteam  ← alice can edit                                                                                                                                                                                               
  ls -ld /shared/project                                                                                                                                                                             
  # drwxrwsr-x 2 root devteam ...
  #       ^                                                                                                                                                                                          
  #       's' in group execute = setgid
```

- `sticky bit` on `/tmp` prevents users from deleting each other's files.
  - permission in tmp will be --- --- --t the t replace the x in others position so
    this directory has rule that only file owners can delete their own files

### ACL (Access Control List)

```bash
getfacl <path>                      # show ACL entries
setfacl -m u:alice:rwx <path>       # grant alice rwx
setfacl -m g:dev:r-x <path>         # grant group dev r-x
setfacl -x u:alice <path>           # remove alice's ACL entry
setfacl -b <path>                   # remove all ACL entries
```

- ACL extends permissions beyond owner/group/others — use when multiple users need different access on the same path.
- If `ls -l` shows `+` at end of permission string, an ACL is set.
- ACL entry presence is shown by `+` at the end of `ls -l` permission string.