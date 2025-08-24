# Configuration Examples

Here are some common configuration examples for different use cases.

## Basic Configuration

### Standard Home Setup
```json
{
    "output_dir": "/mnt/MUSIC",
    "formats": ["flac", "mp3"],
    "eject_after_rip": true,
    "notification_enabled": false,
    "network_copy": false,
    "network_path": "",
    "max_retries": 3,
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

### High Quality Audiophile Setup
```json
{
    "output_dir": "/mnt/AUDIOPHILE",
    "formats": ["flac"],
    "eject_after_rip": true,
    "notification_enabled": true,
    "network_copy": true,
    "network_path": "/mnt/nas/music/",
    "max_retries": 5,
    "cd_quality": {
        "flac_compression": 0,
        "normalize_audio": false
    },
    "naming": {
        "cd_format": "${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}",
        "sanitize_filenames": true
    }
}
```

### Space-Efficient Setup
```json
{
    "output_dir": "/mnt/MUSIC",
    "formats": ["mp3"],
    "eject_after_rip": true,
    "notification_enabled": false,
    "network_copy": false,
    "max_retries": 3,
    "cd_quality": {
        "mp3_quality": "V2",
        "normalize_audio": true
    },
    "naming": {
        "cd_format": "${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}",
        "sanitize_filenames": true
    }
}
```

### Network Storage Setup
```json
{
    "output_dir": "/tmp/ripping",
    "formats": ["flac", "mp3"],
    "eject_after_rip": true,
    "notification_enabled": true,
    "network_copy": true,
    "network_path": "//nas.local/music/",
    "max_retries": 3,
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

## Quality Settings Explained

### FLAC Compression Levels
- `0`: No compression (fastest, largest files)
- `5`: Default compression (good balance)
- `8`: Maximum compression (slowest, smallest files)

### MP3 Quality Options
- `V0`: ~245 kbps average (highest quality VBR)
- `V2`: ~190 kbps average (good quality)
- `V4`: ~165 kbps average (acceptable quality)
- `320`: 320 kbps CBR (constant bitrate)

### Naming Format Variables
- `${ARTISTFILE}`: Artist name (sanitized for filesystem)
- `${ALBUMFILE}`: Album name (sanitized for filesystem)
- `${TRACKNUM}`: Track number (zero-padded)
- `${TRACKFILE}`: Track title (sanitized for filesystem)
- `${YEAR}`: Release year
- `${GENRE}`: Music genre

## Network Mount Examples

### SMB/CIFS Mount
Add to `/etc/fstab`:
```
//192.168.1.100/music /mnt/nas cifs username=pi,password=yourpass,uid=pi,gid=pi 0 0
```

### NFS Mount
Add to `/etc/fstab`:
```
192.168.1.100:/volume1/music /mnt/nas nfs defaults 0 0
```

### USB Drive Mount
```bash
# Create mount point
sudo mkdir /mnt/usb

# Add to /etc/fstab for automatic mounting
/dev/sda1 /mnt/usb ext4 defaults,user,rw 0 0
```

## Advanced Configurations

### Multi-Format with Different Quality
```json
{
    "output_dir": "/mnt/MUSIC",
    "formats": ["flac", "mp3", "ogg"],
    "eject_after_rip": true,
    "cd_quality": {
        "flac_compression": 5,
        "mp3_quality": "V0",
        "ogg_quality": 6,
        "normalize_audio": false
    }
}
```

### Conditional Network Copy
```json
{
    "output_dir": "/mnt/local",
    "formats": ["flac"],
    "network_copy": true,
    "network_path": "/mnt/backup/",
    "network_conditions": {
        "only_when_online": true,
        "retry_attempts": 3,
        "retry_delay": 300
    }
}
```

### Custom Notification Setup
```json
{
    "notification_enabled": true,
    "notification_config": {
        "method": "email",
        "email_to": "user@example.com",
        "email_from": "pi@raspberrypi.local",
        "smtp_server": "smtp.gmail.com",
        "smtp_port": 587
    }
}
```

## Troubleshooting Configurations

### Debug Mode
```json
{
    "debug_mode": true,
    "verbose_logging": true,
    "log_level": "DEBUG",
    "keep_temp_files": true
}
```

### Minimal Offline Configuration
```json
{
    "output_dir": "/mnt/MUSIC",
    "formats": ["mp3"],
    "offline_mode": true,
    "skip_metadata": true,
    "eject_after_rip": true,
    "max_retries": 1
}
```

## Hardware-Specific Settings

### For Raspberry Pi Zero/1
```json
{
    "formats": ["mp3"],
    "cd_quality": {
        "mp3_quality": "V4",
        "encoding_threads": 1
    },
    "max_retries": 2,
    "timeout_multiplier": 2.0
}
```

### For Raspberry Pi 4
```json
{
    "formats": ["flac", "mp3"],
    "cd_quality": {
        "flac_compression": 8,
        "mp3_quality": "V0",
        "encoding_threads": 4
    },
    "parallel_encoding": true,
    "max_retries": 3
}
```

## Output Directory Structures

### Flat Structure
```json
{
    "naming": {
        "cd_format": "${ARTISTFILE} - ${ALBUMFILE} - ${TRACKNUM} - ${TRACKFILE}"
    }
}
```

### Year-Based Structure
```json
{
    "naming": {
        "cd_format": "${YEAR}/${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}"
    }
}
```

### Genre-Based Structure
```json
{
    "naming": {
        "cd_format": "${GENRE}/${ARTISTFILE}/${ALBUMFILE}/${TRACKNUM} - ${TRACKFILE}"
    }
}
```
