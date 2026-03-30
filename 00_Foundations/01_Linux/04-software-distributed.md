# Software and Package Management

# Overview

- Linux software is distributed as packages (`.deb` for Debian/Ubuntu, `.rpm` for RHEL/CentOS) or archives (`.tar.gz`).
- High-level managers (`apt`, `yum`/`dnf`) resolve dependencies automatically; low-level tools (`dpkg`, `rpm`) do not.
- The installation layer stack: download → extract → low-level install → high-level manage.

# Architecture

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

- Layer 1 → wget (download)
- Layer 2 → tar (extract)
- Layer 3 → dpkg (low-level install)
- Layer 4 → apt (high-level manager)
- Device Representation file in `/dev`

# Core Building Blocks

### apt (Debian / Ubuntu)
- **What it is** — a high-level package manager for Debian-based systems. apt uses dpkg internally and handles dependencies automatically. Works with .deb packages.

```bash
apt
```

#### Common Commands

- `apt update` Update package list from repositories.
- `apt upgrade` Upgrade all installed packages to latest available version.
- `apt install <package>` Install a package and required dependencies.
- `apt remove <package>` Remove package (keep configuration files).
- `apt purge <package>` Remove package including configuration files.
- `apt autoremove` Remove unused dependencies.
- `apt search <package>` Search for package in repositories.
- `apt show <package>` Show detailed package information.

### dpkg (low-level, Debian / Ubuntu)
- **What it is** — manage standalone .deb packages (low-level tool). Does NOT automatically resolve dependencies.

```bash
dpkg [option] <package.deb>
```

#### Common options:

- `dpkg -i <package.deb>` Install package
- `dpkg -r <package_name>` Remove package (keep config files)
- `dpkg -P <package_name>` Remove package including config files
- `dpkg -s <package_name>` Show package status
- `dpkg -l` List installed packages

### tar (archive extraction)
- **What it is** — archive and extract files. Commonly used for .tar, .tar.gz, .tar.xz packages. Does NOT install software automatically.

```bash
tar [option] <file>
```

#### Common options

- `tar -xvf <file.tar>` Extract archive
- `tar -xvzf <file.tar.gz>` Extract gzip archive
- `tar -xvJf <file.tar.xz>` Extract xz archive
- `tar -cvf <file_name.tar> <file/dir_to_archive>` Create archive

#### Option meaning
- `-c` Create
- `-x` Extract
- `-v` Verbose (show process)
- `-f` File
- `-z` gzip
- `-J` xz

### wget (download)

```bash
wget <url>
```

- download files from the internet.
- Works with HTTP, HTTPS, and FTP.
- Saves file to current directory by default.
- `wget -P <download-to> <URL>` to specific path to download.
- `wget -O <new_name> <url>` Download and save with custom filename.
- `wget -c <url>` Continue/resume interrupted download.
- `wget -q <url>` Quiet mode (no output).
