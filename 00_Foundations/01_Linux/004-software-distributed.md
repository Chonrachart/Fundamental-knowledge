# Software and Package Management

# Overview
- **Why it exists** —
- **What it is** —
- **One-liner** —

<!-- Your original notes below — reorganize into subsections -->

- Common package formats:
  - `.deb` → Debian / Ubuntu based systems
  - `.rpm` → Red Hat / CentOS / Fedora based systems

```bash
dpkg [option] <package.deb>
```

- dpkg manage standalone .deb packages (low-level tool).
- Does NOT automatically resolve dependencies.

### Common options:

- `dpkg -i <package.deb>` Install package
- `dpkg -r <package_name>` Remove package (keep config files)
- `dpkg -P <package_name>` Remove package including config files
- `dpkg -s <package_name>` Show package status
- `dpkg -l` List installed packages

# tar

```bash
tar [option] <file>
```

- tar archive and extract files.
- Commonly used for .tar, .tar.gz, .tar.xz packages.
- Does NOT install software automatically.

### Common options

- `tar -xvf <file.tar>` Extract archive
- `tar -xvzf <file.tar.gz>` Extract gzip archive
- `tar -xvJf <file.tar.xz>` Extract xz archive
- `tar -cvf <file_name.tar> <file/dir_to_archive>` Create archive

### Option meaning
- `-c` Create
- `-x` Extract
- `-v` Verbose (show process)
- `-f` File
- `-z` gzip
- `-J` xz

# Advanced Package Tool

```bash
apt 
```

- apt is a high-level package manager for Debian-based systems.
- apt uses dpkg internally and handles dependencies automatically.
- Works with .deb packages.

### Common Commands

- `apt update` Update package list from repositories.
- `apt upgrade` Upgrade all installed packages to latest available version.
- `apt install <package>` Install a package and required dependencies.
- `apt remove <package>` Remove package (keep configuration files).
- `apt purge <package>` Remove package including configuration files.
- `apt autoremove` Remove unused dependencies.
- `apt search <package>` Search for package in repositories.
- `apt show <package>` Show detailed package information.

# wget

```bash
wget <url>
```

- wget download files from the internet.
- Works with HTTP, HTTPS, and FTP.
- Saves file to current directory by default.
- `wget -P <down-load-to> <URL>` to specific path to down load.

### Common Commands

- `wget <url>` Download file from URL.
- `wget -O <new_name> <url>` Download and save with custom filename.
- `wget -P <directory> <url>` Download file to specific directory.
- `wget -c <url>` Continue/resume interrupted download.
- `wget -q <url>` Quiet mode (no output).

# Note

- Device Representation file in `/dev`
- Layer 1 → wget (download)
- Layer 2 → tar (extract)
- Layer 3 → dpkg (low-level install)
- Layer 4 → apt (high-level manager)


# Architecture

# Core Building Blocks

### apt (Debian / Ubuntu)
- **Why it exists** —
- **What it is** —
- **One-liner** —

### dpkg (low-level, Debian / Ubuntu)
- **Why it exists** —
- **What it is** —
- **One-liner** —

### tar (archive extraction)
- **Why it exists** —
- **What it is** —
- **One-liner** —

### wget (download)
- **Why it exists** —
- **What it is** —
- **One-liner** —
