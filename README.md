# Raspberry Pi Auto CD/DVD Ripper

A complete automation solution for converting your CD and DVD collection to high-quality digital formats using a Raspberry Pi 5 and USB optical drive.

## Features

🎵 **Automatic CD Ripping**
- High-quality FLAC + MP3 encoding
- MusicBrainz metadata integration
- Smart folder organization
- Album art download

📀 **DVD Ripping Support**
- H.264/MP4 encoding
- Main feature extraction
- Configurable quality presets

🤖 **Full Automation**
- Auto-detection via udev rules
- Hands-free operation
- Auto-eject when complete
- Comprehensive logging

🌐 **Network Integration**
- Direct output to network shares
- Optional file copying
- Samba/NFS support

## Quick Start

1. **Install dependencies:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

2. **Configure the system:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Insert a CD/DVD and watch the magic happen!**

## File Structure

```
/opt/auto-ripper/
├── auto-ripper.py      # Main automation script
├── trigger-rip.sh      # udev trigger script
└── config.json         # Configuration file

/home/rsd/
├── .abcde.conf         # CD ripping configuration
└── /media/rsd/         # Output directory
   ├── music/           # CD rips (FLAC/MP3)
   └── videos/          # DVD rips (MP4)

/var/log/auto-ripper/   # Log files
```

## Configuration

Edit `/opt/auto-ripper/config.json` to customize:

```json
{
    "output_dir": "/media/rsd",
    "formats": ["flac", "mp3"],
    "eject_after_rip": true,
    "network_copy": true,
    "network_path": "/mnt/nas/media"
}
```

### Network Storage Setup

For NFS mount:
```bash
sudo mkdir /mnt/nas
sudo mount -t nfs 192.168.1.100:/volume1/media /mnt/nas
```

For Samba mount:
```bash
sudo mkdir /mnt/samba
sudo mount -t cifs //192.168.1.100/media /mnt/samba -o username=user,password=pass
```

## Usage Modes

### 1. Automatic Mode (Recommended)
Simply insert a disc - the system will automatically:
- Detect the disc type
- Rip with optimal settings
- Organize files properly
- Eject when complete

### 2. Manual Service Mode
```bash
sudo systemctl start auto-ripper
# Insert discs, they'll be processed automatically
sudo systemctl stop auto-ripper
```

### 3. One-shot Mode
```bash
/opt/auto-ripper/auto-ripper.py --daemon
```

## CD Naming Convention

CDs are organized as:
```
Artist Name/
└── Album Name (Year)/
    ├── 01 - Track Name.flac
    ├── 01 - Track Name.mp3
    ├── 02 - Track Name.flac
    └── folder.jpg (album art)
```

## Quality Settings

**CD Audio:**
- FLAC: Lossless compression level 8
- MP3: Variable bitrate V0 (~245 kbps)
- Metadata from MusicBrainz
- Album art embedded

**DVDs:**
- Container: MP4
- Video: H.264 High Profile
- Audio: AAC stereo
- Main feature only (skips menus/extras)

## Troubleshooting

**Check logs:**
```bash
tail -f /var/log/auto-ripper/auto-ripper.log
tail -f /var/log/auto-ripper/trigger.log
```

**Test disc detection:**
```bash
# Insert a disc, then check
blkid /dev/sr0
cd-discid /dev/sr0  # For audio CDs
```

**Manual rip for testing:**
```bash
# Audio CD
abcde -d /dev/sr0

# DVD
HandBrakeCLI -i /dev/sr0 -o test.mp4 --preset "High Profile"
```

**Restart udev rules:**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Performance Tips

**For Raspberry Pi 5:**
- Use USB 3.0 port for optical drive
- Consider active cooling for long sessions
- Use fast microSD card (Class 10/U3)
- Set `MAXPROCS=4` in abcde.conf for faster encoding

**Network optimization:**
- Use wired connection for large transfers
- Mount network storage with appropriate cache settings
- Consider direct output to network mount vs. local + copy

## Supported Formats

**Input:**
- Audio CDs (Red Book standard)
- DVDs (Video_TS structure)
- Data discs (limited support)

**Output:**
- Audio: FLAC, MP3, OGG Vorbis
- Video: MP4 (H.264/AAC)

## Security Notes

- Scripts run as user `rsd` (not root)
- Network credentials stored in mount commands only
- Log files readable by user only
- No remote access by default

## Hardware Requirements

- Raspberry Pi 4/5 (3B+ may work but slower)
- USB optical drive (most USB 2.0/3.0 drives work)
- microSD card (32GB+ recommended)
- Network connection (for metadata/network storage)

## License

This project is provided as-is for personal use. Ensure you comply with local laws regarding media ripping and backup rights.
