# Systemd 
- systemd is the service manager and initialization system used by most modern Linux distributions.
- When Linux boots, the kernel starts systemd as `PID 1`.
- It is responsible for:
  - starting the system during boot
  - managing background services
  - controlling system processes
  - handling logging and system states
- `systemctl` is the main command used to interact with systemd.

# Service

- A service is a background process that runs on a system to provide functionality.
- Services usually start automatically during system boot.
- They run continuously and wait for requests from users, applications, or other systems.
- Examples of services include:
  - web servers
  - database servers
  - SSH remote access
  - monitoring agents

```bash
systemctl status <service>
systemctl start <service>
systemctl stop <service>
systemctl restart <service>
systemctl reload <service>
systemctl enable <service>
systemctl disable <service>
systemctl list-unit --type=service
systemctl --failed
systemcl reboot
systemctl poweroff
systemctl suspend
```

- `enable` run this service on boot.
- `systemctl --failed` this check only failed service
- `systemctl list-unit --type=service` this list all service

### Common locations
```bash
# Priority order (highest → lowest):
/etc/systemd/system/        (custom / admin)
/usr/lib/systemd/system/    (package default)
/lib/systemd/system/        (distribution)
```
- These files define:
  - how the service starts
  - what program it runs
  - restart policies.
  - example to create service
    - [install-openvswitch-create-service.sh](../Shell-script/Install/openvswitch/install-openvswitch-create-service.sh)

# App Armor

- AppArmor (Application Armor) is a Linux security framework that restricts what a program (service or application) is allowed to access on the system.

- It implements Mandatory Access Control (MAC).
This means the system enforces security rules even if a process has normal permissions to access something.

- AppArmor works by applying profiles to programs.
A profile defines what the program is allowed or not allowed to do.

- Typical restrictions include:
  - Which files the program can read or write
  - Which directories it can access
  - Which network operations it can perform
  - Which capabilities it can use
  
# Socket

- A socket is a communication endpoint used for data exchange between processes.
- It allows two programs to communicate either:
  - over a network
  - within the same system
- Sockets are widely used in client–server architecture, where one program provides a service and another program connects to it.

### type of socket
- Network sockets(TCP/UDP)
  - Used for communication between different machines over a network.
- Unix domain socket
  - Used for communication between processes on the same machine.
  - Instead of an IP and port, they use a file path.
  
```bash
ss -lntpu
```
- Option	
  - `-t` TCP sockets
  - `-u` UDP sockets
  - `-l` listening sockets
  - `-n` numeric addresses
  - `-p` show process using the socket