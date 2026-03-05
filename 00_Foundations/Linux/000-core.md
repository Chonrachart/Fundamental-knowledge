1. Linux คืออะไร
Linux is a Unix-like operating system built around the Linux kernel.

The kernel manages system resources such as:

- processes
- memory
- filesystems
- devices
- networking


2. Linux system architecture
     User Applications
       ↓
Shell / CLI
       ↓
System Libraries
       ↓
System Calls
       ↓
Linux Kernel
       ↓
Hardware


3. Kernel responsibilities
   Process scheduling
Memory management
Filesystem management
Device drivers
Networking stack
Security and permissions


4. mapping 
   Filesystem
 → file operations
 → mount
 → disk

Process management
 → processes
 → system statistics

System services
 → systemd
 → sockets

Security
 → users
 → groups
 → permissions

Software management
 → package distribution

Observability
 → logs

5. . Linux mental model
   User runs command
      ↓
Shell interprets command
      ↓
System call
      ↓
Kernel performs operation
      ↓
Filesystem / process / device