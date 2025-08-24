# Grim Ripper - Raspberry Pi Auto CD Ripper

**Turn your Raspberry Pi into an automatic CD ripping station that works as soon as you insert a disc!**

*By Satwant Kumar (Satwant.Dagar@gmail.com)*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi-red.svg)](https://www.raspberrypi.org/)
[![Python](https://img.shields.io/badge/python-3.7+-blue.svg)](https://www.python.org/)

## 🎵 Features

- **Automatic Detection**: Insert any audio CD and it starts ripping immediately
- **High Quality**: Rips to both FLAC (lossless) and MP3 (V0 VBR) formats
- **Metadata Lookup**: Automatically fetches album art and track information
- **Offline Mode**: Works without internet connection when needed
- **Robust Error Handling**: Handles dirty/scratched discs with advanced error correction
- **Multiple Formats**: Supports both audio CDs and data DVDs
- **Network Storage**: Optional automatic copying to network drives
- **Plug & Play**: Works with USB optical drives
- **Smart Detection**: Advanced disc detection with multiple fallback methods

## 🚀 Quick Install

**One-line installation for Raspberry Pi OS:**

```bash
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/install.sh | sudo bash
```

That's it! Insert a CD and watch the magic happen ✨

## 📋 What You Need

### Hardware
- Raspberry Pi (any model, Pi 4 recommended)
- USB optical drive (CD/DVD reader)
- SD card (16GB+ recommended)
- External storage (USB drive, NAS, etc.) for ripped music

### Software
- Raspberry Pi OS (Lite or Desktop)
- Internet connection for initial setup and metadata lookup

## 🔧 Manual Installation

If you prefer to install manually or want to understand what's happening:

### 1. Install Dependencies

```bash
sudo apt update
sudo apt install -y python3 python3-pip abcde cdparanoia cd-discid \
    flac lame normalize-audio eyed3 glyrc imagemagick \
    curl wget git udev
```

### 2. Download and Install

```bash
git clone https://github.com/SatwantKumar/grim_ripper.git
cd grim_ripper
sudo ./install.sh
```

### 3. Configuration

Edit the configuration file:
```bash
sudo nano /opt/auto-ripper/config.json
```

Key settings:
- `output_dir`: Where to save ripped music (default: `/mnt/MUSIC`)
- `formats`: Output formats (default: `["flac", "mp3"]`)
- `eject_after_rip`: Auto-eject when done (default: `true`)

## 📁 Directory Structure

```
/opt/auto-ripper/
├── auto-ripper.py          # Main application
├── config.json             # Configuration file
├── abcde.conf              # Online ripping config
├── abcde-offline.conf      # Offline ripping config
├── trigger-rip.sh          # udev trigger script
├── utils/                  # Utility scripts
│   ├── troubleshoot.sh     # Diagnostics
│   ├── cleanup.sh          # Clean stale processes
│   └── test-detection.sh   # Test CD detection
└── logs/                   # Log files

/etc/udev/rules.d/
└── 99-auto-ripper.rules    # udev rules for auto-detection

/mnt/MUSIC/                 # Default output directory
└── [Artist]/[Album]/       # Ripped music organized by artist/album
```

## 🎛️ Configuration Options

### Basic Configuration (`config.json`)

```json
{
    "output_dir": "/mnt/MUSIC",
    "formats": ["flac", "mp3"],
    "eject_after_rip": true,
    "notification_enabled": false,
    "network_copy": false,
    "network_path": "",
    "max_retries": 3
}
```

### Quality Settings

```json
{
    "cd_quality": {
        "flac_compression": 8,
        "mp3_quality": "V0",
        "normalize_audio": false
    },
    "naming": {
        "cd_format": "${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}",
        "sanitize_filenames": true
    }
}
```

### Network Storage

To automatically copy ripped files to a network location:

```json
{
    "network_copy": true,
    "network_path": "/mnt/nas/music/"
}
```

## 🖥️ Usage

### Normal Operation
1. Insert an audio CD
2. Wait for the drive LED to stop blinking
3. Ripping starts automatically
4. CD ejects when complete
5. Find your music in `/mnt/MUSIC/[Artist]/[Album]/`

### Manual Operation
```bash
# Test if a CD is detected
sudo /opt/auto-ripper/utils/test-detection.sh

# Manually trigger a rip
sudo python3 /opt/auto-ripper/auto-ripper.py --daemon

# Check system status
sudo /opt/auto-ripper/utils/troubleshoot.sh
```

### Monitoring
```bash
# Watch logs in real-time
tail -f /var/log/auto-ripper/auto-ripper.log

# Check recent activity
sudo /opt/auto-ripper/utils/check-status.sh
```

## 📊 Output Quality

| Format | Quality | Typical Size (74min CD) |
|--------|---------|--------------------------|
| FLAC   | Lossless | ~300-400 MB |
| MP3    | V0 VBR (~245 kbps avg) | ~130-160 MB |

## 🔍 Troubleshooting

### CD Not Detected
```bash
# Run the diagnostic script
sudo /opt/auto-ripper/utils/troubleshoot.sh

# Check if drive is recognized
lsusb | grep -i optical
ls -la /dev/sr*

# Test manual detection
sudo /opt/auto-ripper/utils/test-detection.sh
```

### Permission Issues
```bash
# Add user to cdrom group
sudo usermod -a -G cdrom pi
sudo reboot
```

### Stuck Processes
```bash
# Clean up stuck processes
sudo /opt/auto-ripper/utils/cleanup.sh
```

### Drive Issues
```bash
# Reset optical drive
sudo eject /dev/sr0
# Wait 10 seconds, reinsert CD

# Check drive health
dmesg | grep -i sr0
```

## 🔧 Advanced Configuration

### Custom Output Naming
Edit `/opt/auto-ripper/abcde.conf`:
```bash
OUTPUTFORMAT='${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}'
```

### Network Mount Setup
```bash
# Mount NAS automatically
echo "//your-nas-ip/music /mnt/nas cifs username=user,password=pass,uid=pi,gid=pi 0 0" >> /etc/fstab
```

### Notification Setup
Enable notifications in `config.json` and install notification tools:
```bash
sudo apt install -y libnotify-bin
```

## 🚨 System Requirements

### Minimum
- Raspberry Pi 3 or newer
- 1GB RAM
- 8GB SD card
- USB 2.0 optical drive

### Recommended
- Raspberry Pi 4 (4GB RAM)
- 32GB SD card (Class 10)
- External USB drive for music storage
- USB 3.0 optical drive

## 📝 Supported Formats

### Input
- Audio CDs (CD-DA)
- Mixed mode CDs
- Data DVDs (basic support)

### Output
- FLAC (lossless)
- MP3 (various qualities)
- Ogg Vorbis (optional)
- AAC (optional)

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
git clone https://github.com/SatwantKumar/grim_ripper.git
cd grim_ripper
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [abcde](https://abcde.einval.com/) - A Better CD Encoder
- [cdparanoia](https://www.xiph.org/paranoia/) - Paranoid CD ripper
- [FLAC](https://xiph.org/flac/) - Free Lossless Audio Codec
- [LAME](https://lame.sourceforge.io/) - MP3 encoder

## 📞 Support

- 🐛 [Report bugs](https://github.com/SatwantKumar/grim_ripper/issues)
- 💡 [Request features](https://github.com/SatwantKumar/grim_ripper/issues)
- 💬 [Discussions](https://github.com/SatwantKumar/grim_ripper/discussions)

## 📈 Roadmap

- [ ] Web interface for remote monitoring
- [ ] Mobile app for notifications
- [ ] Multi-disc changer support
- [ ] Automatic artwork scanning
- [ ] Integration with music streaming services
- [ ] Docker container support

---

**Made with ❤️ for the Raspberry Pi community by Satwant Kumar**

*Transform your Pi into the ultimate retro-modern jukebox!*

---

*Grim Ripper - Because every CD deserves a proper digital afterlife! 💿➡️💾*