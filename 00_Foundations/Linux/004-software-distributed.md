# Software and Package Management

- Linux software is distributed as packages (`.deb` for Debian/Ubuntu, `.rpm` for RHEL/CentOS) or archives (`.tar.gz`).
- High-level managers (`apt`, `yum`/`dnf`) resolve dependencies automatically; low-level tools (`dpkg`, `rpm`) do not.
- The installation layer stack: download → extract → low-level install → high-level manage.


# Package Management Layers

```text
Layer 4 — apt / yum / dnf          (high-level: dependency resolution, repo management)
              ↓
Layer 3 — dpkg / rpm               (low-level: install/remove .deb/.rpm; no dependency resolution)
              ↓
Layer 2 — tar                      (extract archive: .tar, .tar.gz, .tar.xz)
              ↓
Layer 1 — wget / curl              (download from internet)
              ↓
         /dev/sdX                  (disk — device files in /dev)
```


# Mental Model: apt install

```text
apt install nginx
        ↓
Read package lists (apt update fetches these from /etc/apt/sources.list)
        ↓
Resolve dependencies (find all required packages)
        ↓
Download .deb files to /var/cache/apt/archives/
        ↓
Call dpkg to install each .deb
        ↓
Run post-install scripts (create users, enable service, etc.)
        ↓
Package marked as installed in dpkg database (/var/lib/dpkg/status)
```


# Core Building Blocks

### apt (Debian / Ubuntu)

```bash
apt update                      # refresh package list from repositories
apt upgrade                     # upgrade all installed packages
apt install <package>           # install package + dependencies
apt remove <package>            # remove package (keep config files)
apt purge <package>             # remove package + config files
apt autoremove                  # remove unused dependency packages
apt search <keyword>            # search available packages
apt show <package>              # show package details (version, deps, description)
apt list --installed            # list all installed packages
```

- Always run `apt update` before `apt install` on a fresh system.
- `apt purge` + `apt autoremove` for a clean removal.

### dpkg (low-level, Debian / Ubuntu)

```bash
dpkg -i <package.deb>           # install .deb file
dpkg -r <package>               # remove (keep config)
dpkg -P <package>               # purge (remove + config)
dpkg -s <package>               # show package status
dpkg -l                         # list all installed packages
dpkg -l | grep <name>           # search installed packages
```

- Use `dpkg -i` when you have a local `.deb` file not in any repo.
- `dpkg` does NOT resolve dependencies — use `apt install -f` after to fix broken deps.

### tar (archive extraction)

```bash
tar -xvf  <file.tar>            # extract .tar archive
tar -xvzf <file.tar.gz>         # extract gzip-compressed archive
tar -xvJf <file.tar.xz>         # extract xz-compressed archive
tar -cvf  <output.tar> <dir>    # create archive from directory
tar -cvzf <output.tar.gz> <dir> # create gzip archive
tar -tf   <file.tar>            # list contents without extracting
```

Option reference: `-c` create · `-x` extract · `-v` verbose · `-f` file · `-z` gzip · `-J` xz

### wget (download)

```bash
wget <url>                              # download file to current directory
wget -O <filename> <url>               # download with custom filename
wget -P <directory> <url>              # download to specific directory
wget -c <url>                          # resume interrupted download
wget -q <url>                          # quiet mode (no progress output)
wget --no-check-certificate <url>      # skip TLS verification (use carefully)
```

Related notes:
- [05-file-system-mount](./05-file-system-mount.md) — filesystem needed before installing to custom paths
- [09-service-systemctl-socket](./09-service-systemctl-socket.md) — managing services installed by packages

---

# Troubleshooting Guide

### apt install fails with "Unable to locate package"

1. Package lists stale? Run `apt update` to refresh index from repos.
2. Typo in package name? Run `apt search <keyword>`.
3. Package in a missing repo? Check `/etc/apt/sources.list` and `sources.list.d/`.

### dpkg -i fails with dependency errors

1. Auto-install missing deps: `apt install -f`.
2. Still broken? Check: `dpkg --audit`.

### "dpkg was interrupted, run dpkg --configure -a"

1. Run: `dpkg --configure -a`.
2. Still stuck? Run: `apt install -f`.

### Downloaded .tar.gz binary won't run

1. Extracted? `tar -xvzf <file.tar.gz>`.
2. Has execute permission? `chmod +x <binary>`.
3. "command not found"? Binary not in PATH — move to `/usr/local/bin` or add its directory to PATH.


# Quick Facts (Revision)

- `apt update` refreshes the package index; `apt upgrade` installs newer versions — they are different steps.
- `dpkg` installs but does NOT resolve dependencies; `apt` wraps `dpkg` and handles deps.
- After `dpkg -i` with dep errors, run `apt install -f` to automatically fix missing dependencies.
- `apt purge` removes config files; `apt remove` keeps them.
- `apt autoremove` cleans up orphaned dependency packages after removal.
- Always use absolute paths in `tar -f` when creating archives from scripts.
- `wget -c` resumes partial downloads — useful for large files on slow connections.
