# Detailed Setup Guide

This guide provides detailed setup instructions for different scenarios and configurations.

## Prerequisites

### Hardware Requirements

**Minimum:**
- Raspberry Pi 3 or newer
- 8GB microSD card (Class 10)
- USB optical drive (CD/DVD)
- Power supply (official recommended)

**Recommended:**
- Raspberry Pi 4 (4GB RAM)
- 32GB microSD card (Class 10 or better)
- USB 3.0 optical drive
- External storage (USB drive, NAS)
- Ethernet connection

### Software Requirements

- Raspberry Pi OS (Lite or Desktop)
- Internet connection for initial setup

## Installation Methods

### Method 1: One-Click Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/install.sh | sudo bash
```

This will:
- Update system packages
- Install all dependencies
- Download and configure the auto-ripper
- Set up udev rules
- Configure user permissions
- Create systemd service

### Method 2: Manual Installation

#### Step 1: Update System
```bash
sudo apt update && sudo apt upgrade -y
```

#### Step 2: Install Dependencies
```bash
sudo apt install -y python3 python3-pip abcde cdparanoia cd-discid \
    flac lame normalize-audio eyed3 glyrc imagemagick \
    curl wget git udev rsync flock
```

#### Step 3: Download Source
```bash
cd /tmp
git clone https://github.com/SatwantKumar/grim_ripper.git
cd grim_ripper
```

#### Step 4: Run Installer
```bash
sudo ./install.sh
```

### Method 3: Development Installation

For developers or advanced users:

```bash
git clone https://github.com/SatwantKumar/grim_ripper.git
cd grim_ripper

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install in development mode
pip install -e .

# Run tests
./tests/test-installation.sh
```

## Post-Installation Configuration

### 1. User Permissions

Ensure the user is in the correct groups:
```bash
sudo usermod -a -G cdrom,audio pi
```

**Important:** You must log out and back in (or reboot) for group changes to take effect.

### 2. External Storage Setup

#### USB Drive
```bash
# Create mount point
sudo mkdir /mnt/usb-music

# Find USB device
lsblk

# Mount manually (replace sdX1 with your device)
sudo mount /dev/sdX1 /mnt/usb-music

# Add to /etc/fstab for automatic mounting
echo "/dev/sdX1 /mnt/usb-music ext4 defaults,user,rw 0 0" | sudo tee -a /etc/fstab

# Update config to use USB storage
sudo nano /opt/auto-ripper/config.json
# Change "output_dir" to "/mnt/usb-music"
```

#### Network Storage (NAS)

**SMB/CIFS:**
```bash
# Install CIFS utilities
sudo apt install cifs-utils

# Create mount point
sudo mkdir /mnt/nas

# Test mount
sudo mount -t cifs //192.168.1.100/music /mnt/nas -o username=youruser,password=yourpass

# Add to /etc/fstab
echo "//192.168.1.100/music /mnt/nas cifs username=youruser,password=yourpass,uid=pi,gid=pi 0 0" | sudo tee -a /etc/fstab
```

**NFS:**
```bash
# Install NFS client
sudo apt install nfs-common

# Create mount point
sudo mkdir /mnt/nas

# Test mount
sudo mount -t nfs 192.168.1.100:/volume1/music /mnt/nas

# Add to /etc/fstab
echo "192.168.1.100:/volume1/music /mnt/nas nfs defaults 0 0" | sudo tee -a /etc/fstab
```

### 3. Configuration Customization

Edit the main configuration file:
```bash
sudo nano /opt/auto-ripper/config.json
```

Key settings to customize:
- `output_dir`: Where to save ripped music
- `formats`: Output formats (flac, mp3, ogg)
- `network_copy`: Enable automatic network copying
- `notification_enabled`: Enable completion notifications

### 4. Quality Settings

Edit ABCDE configuration for quality settings:
```bash
sudo nano /opt/auto-ripper/abcde.conf
```

Common modifications:
- `FLACOPTS`: FLAC compression settings
- `LAMEOPTS`: MP3 quality settings
- `OUTPUTFORMAT`: File naming format

## Advanced Configuration

### Custom File Naming

Edit `/opt/auto-ripper/abcde.conf`:
```bash
# Default format
OUTPUTFORMAT='${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}'

# Year-based format
OUTPUTFORMAT='${YEAR}/${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}'

# Flat format
OUTPUTFORMAT='${ARTISTFILE} - ${ALBUMFILE} - ${TRACKNUM} - ${TRACKFILE}'
```

### Multiple Output Formats

Configure different quality settings in `config.json`:
```json
{
    "formats": ["flac", "mp3", "ogg"],
    "cd_quality": {
        "flac_compression": 8,
        "mp3_quality": "V0",
        "ogg_quality": 6
    }
}
```

### Notification Setup

#### Email Notifications
```bash
# Install mail utilities
sudo apt install msmtp msmtp-mta

# Configure msmtp
sudo nano /etc/msmtprc
```

Example `/etc/msmtprc`:
```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           your-email@gmail.com
user           your-email@gmail.com
password       your-app-password

account default : gmail
```

#### Desktop Notifications
```bash
# Install notification daemon
sudo apt install libnotify-bin

# Enable in config.json
{
    "notification_enabled": true,
    "notification_method": "desktop"
}
```

### Web Monitoring Interface

Set up a simple web interface to monitor ripping progress:

```bash
# Install nginx
sudo apt install nginx

# Copy monitoring configuration
sudo cp examples/nginx-monitoring.conf /etc/nginx/sites-available/auto-ripper-monitor
sudo ln -s /etc/nginx/sites-available/auto-ripper-monitor /etc/nginx/sites-enabled/

# Set up basic authentication
sudo htpasswd -c /etc/nginx/.htpasswd pi

# Reload nginx
sudo systemctl reload nginx
```

Access monitoring at: `http://your-pi-ip/`

## Troubleshooting Setup Issues

### Permission Problems
```bash
# Check user groups
groups pi

# Fix if not in cdrom group
sudo usermod -a -G cdrom pi
sudo reboot
```

### USB Drive Not Detected
```bash
# Check USB devices
lsusb

# Check optical drive detection
ls -la /dev/sr*

# Load USB storage modules
sudo modprobe usb-storage
sudo modprobe sr_mod
```

### Network Mount Issues
```bash
# Test network connectivity
ping your-nas-ip

# Check mount status
mount | grep nas

# Manual mount test
sudo mount -t cifs //nas-ip/share /mnt/test -o username=user,password=pass
```

### Service Not Starting
```bash
# Check service status
sudo systemctl status auto-ripper

# View service logs
sudo journalctl -u auto-ripper -f

# Restart service
sudo systemctl restart auto-ripper
```

## Performance Optimization

### For Raspberry Pi Zero/1
- Use only MP3 format to reduce CPU load
- Lower MP3 quality (V4 instead of V0)
- Disable parallel processing
- Use minimal FLAC compression if needed

### For Raspberry Pi 4
- Enable parallel processing
- Use maximum FLAC compression
- Enable multiple output formats
- Consider RAM disk for temporary files

### Storage Optimization
```bash
# Create RAM disk for temporary files (Pi 4 with 4GB+ RAM)
sudo mkdir /mnt/ramdisk
echo "tmpfs /mnt/ramdisk tmpfs defaults,size=1G 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Update ABCDE config to use RAM disk
# Add to abcde.conf:
# WAVOUTPUTDIR="/mnt/ramdisk"
```

## Security Considerations

### Network Access
- Use strong passwords for network mounts
- Consider VPN for remote access
- Enable firewall if needed

### File Permissions
```bash
# Set restrictive permissions on config files
sudo chmod 600 /opt/auto-ripper/config.json
sudo chown pi:pi /opt/auto-ripper/config.json
```

### Remote Access
```bash
# Enable SSH with key authentication only
sudo raspi-config
# Advanced Options > SSH > Enable

# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no

sudo systemctl restart ssh
```

## Backup and Restore

### Backup Configuration
```bash
# Create backup
sudo tar -czf auto-ripper-backup.tar.gz \
    /opt/auto-ripper/config.json \
    /opt/auto-ripper/abcde.conf \
    /opt/auto-ripper/abcde-offline.conf \
    /etc/udev/rules.d/99-auto-ripper.rules

# Store backup safely
scp auto-ripper-backup.tar.gz user@backup-server:/backups/
```

### Restore Configuration
```bash
# Extract backup
sudo tar -xzf auto-ripper-backup.tar.gz -C /

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Restart services
sudo systemctl restart auto-ripper
```

## Testing Installation

Run the included test suite:
```bash
sudo /opt/auto-ripper/tests/test-installation.sh
```

This will verify:
- All required files are present
- Dependencies are installed
- Permissions are correct
- Configuration is valid
- Optical drive is detected

## Getting Help

If you encounter issues:

1. Check the logs: `tail -f /var/log/auto-ripper/auto-ripper.log`
2. Run diagnostics: `sudo /opt/auto-ripper/utils/troubleshoot.sh`
3. Test CD detection: `sudo /opt/auto-ripper/utils/test-detection.sh`
4. Check system status: `sudo /opt/auto-ripper/utils/check-status.sh`

For more help:
- 🐛 [Report Issues](https://github.com/SatwantKumar/grim_ripper/issues)
- 💬 [Ask Questions](https://github.com/SatwantKumar/grim_ripper/discussions)
- 📖 [Read Documentation](https://github.com/SatwantKumar/grim_ripper/docs)
