#!/usr/bin/env python3
"""
Grim Ripper - Raspberry Pi Auto CD Ripper
Automatically rips CDs when inserted into optical drive

Author: Satwant Kumar (Satwant.Dagar@gmail.com)
Date: August 24, 2025
"""

import os
import sys
import time
import json
import logging
import subprocess
import requests
from pathlib import Path

class AutoRipper:
    def __init__(self):
        """Initialize the auto-ripper"""
        self.device = "/dev/sr0"
        self.config = self.load_config()
        self.setup_logging()
        
        # Get current user info
        self.current_user = os.getenv('SUDO_USER') or os.getenv('USER') or 'rsd'
        self.current_uid = os.getuid()
        
        logging.info(f"AutoRipper initialized with device: {self.device}")
        logging.info(f"Running as user: {self.current_user}, UID: {self.current_uid}")
    
    def load_config(self):
        """Load configuration from JSON file"""
        config_path = "/opt/auto-ripper/config.json"
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logging.error(f"Error loading config: {e}")
        
        # Default configuration
        return {
            'output_dir': '/mnt/MUSIC',
            'eject_after_rip': True,
            'unique_artist': 'Unknown_Artist',
            'unique_album': 'Unknown_Album'
        }
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_dir = "/var/log/auto-ripper"
        os.makedirs(log_dir, exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(f"{log_dir}/auto-ripper.log"),
                logging.StreamHandler()
            ]
        )
    
    def is_disc_present(self):
        """Check if a disc is present in the drive"""
        try:
            # Try to read from the device
            result = subprocess.run(['dd', f'if={self.device}', 'of=/dev/null', 'bs=2048', 'count=1'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except Exception as e:
            logging.error(f"Error checking for disc: {e}")
            return False
    
    def get_disc_type(self):
        """Determine if the disc is audio CD or data/DVD with enhanced detection"""
        try:
            logging.info("Determining disc type...")
            
            # Check for audio CD first with cd-discid
            try:
                result = subprocess.run(['cd-discid', self.device], 
                                      capture_output=True, text=True, timeout=15)
                if result.returncode == 0:
                    logging.info(f"Audio CD detected via cd-discid: {result.stdout.strip()}")
                    return 'audio_cd'
                else:
                    logging.warning(f"cd-discid failed: return code {result.returncode}, stderr: {result.stderr[:100]}")
            except subprocess.TimeoutExpired:
                logging.warning("cd-discid timed out")
            except Exception as e:
                logging.warning(f"cd-discid error: {e}")
            
            # Try cdparanoia as alternative audio CD detection
            try:
                result = subprocess.run(['cdparanoia', '-Q', '-d', self.device], 
                                      capture_output=True, text=True, timeout=15)
                if result.returncode == 0:
                    logging.info("Audio CD detected via cdparanoia")
                    return 'audio_cd'
                else:
                    logging.warning(f"cdparanoia failed: return code {result.returncode}, stderr: {result.stderr[:100]}")
            except subprocess.TimeoutExpired:
                logging.warning("cdparanoia timed out")
            except Exception as e:
                logging.warning(f"cdparanoia error: {e}")
            
            # Check for data disc/DVD
            try:
                result = subprocess.run(['file', '-s', self.device], 
                                      capture_output=True, text=True, timeout=10)
                if 'ISO 9660' in result.stdout or 'UDF' in result.stdout:
                    logging.info("Data disc detected")
                    return 'data_disc'
            except Exception as e:
                logging.warning(f"file command error: {e}")
            
            # Try blkid as alternative data disc detection
            try:
                result = subprocess.run(['blkid', self.device], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    logging.info("Data disc detected via blkid")
                    return 'data_disc'
            except Exception as e:
                logging.warning(f"blkid error: {e}")
            
            # Final check - if media is present but type unknown, default to audio_cd
            try:
                result = subprocess.run(['dd', f'if={self.device}', 'of=/dev/null', 'bs=2048', 'count=1'], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    logging.warning("Media detected but type unknown - defaulting to audio_cd")
                    return 'audio_cd'  # Default to audio CD if media is present
            except Exception as e:
                logging.warning(f"dd test failed: {e}")
                
            logging.error("No readable disc detected")
            return 'unknown'
            
        except Exception as e:
            logging.error(f"Error determining disc type: {e}")
            return 'unknown'
    
    def get_disc_metadata(self):
        """Get disc metadata using multiple methods"""
        metadata = {
            'disc_id': None,
            'artist': None,
            'album': None,
            'tracks': []
        }
        
        try:
            # Get disc ID
            result = subprocess.run(['cd-discid', self.device], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                disc_info = result.stdout.strip().split()
                if len(disc_info) > 0:
                    metadata['disc_id'] = disc_info[0]
                    logging.info(f"Disc ID: {metadata['disc_id']}")
            
            # Try MusicBrainz lookup if we have internet
            if metadata['disc_id'] and self.test_internet_connection():
                try:
                    import urllib.request
                    import json
                    
                    url = f"https://musicbrainz.org/ws/2/discid/{metadata['disc_id']}?inc=recordings+artist-credits&fmt=json"
                    logging.info(f"Querying MusicBrainz: {url}")
                    
                    with urllib.request.urlopen(url, timeout=15) as response:
                        data = json.loads(response.read().decode())
                        
                        if 'releases' in data and len(data['releases']) > 0:
                            release = data['releases'][0]
                            
                            # Extract artist
                            if 'artist-credit' in release:
                                artist_names = [ac['name'] for ac in release['artist-credit'] if 'name' in ac]
                                if artist_names:
                                    metadata['artist'] = ', '.join(artist_names)
                            
                            # Extract album
                            if 'title' in release:
                                metadata['album'] = release['title']
                            
                            logging.info(f"MusicBrainz metadata: {metadata['artist']} - {metadata['album']}")
                            
                except Exception as e:
                    logging.warning(f"MusicBrainz lookup failed: {e}")
            
        except Exception as e:
            logging.error(f"Error getting disc metadata: {e}")
        
        return metadata
    
    def check_for_file_collisions(self, disc_id):
        """Check if ripping this disc would overwrite existing files and create unique naming"""
        try:
            output_dir = self.config.get('output_dir', '/mnt/MUSIC')
            
            # Find the next available unique directory name
            unique_artist = "Unknown_Artist"
            unique_album = "Unknown_Album"
            counter = 1
            
            # Check if base names exist and find next available
            base_artist_path = os.path.join(output_dir, unique_artist)
            if os.path.exists(base_artist_path):
                logging.info(f"Base artist directory exists: {base_artist_path}")
                
                # Find next available number
                while os.path.exists(os.path.join(output_dir, f"{unique_artist}_{counter:02d}")):
                    counter += 1
                
                unique_artist = f"{unique_artist}_{counter:02d}"
                unique_album = f"Unknown_Album_{counter:02d}"
                logging.info(f"Using unique naming: {unique_artist}/{unique_album}")
            
            # Update the config to use unique naming
            self.config['unique_artist'] = unique_artist
            self.config['unique_album'] = unique_album
            
            # Check if the specific album directory exists
            album_path = os.path.join(output_dir, unique_artist, unique_album)
            if os.path.exists(album_path):
                logging.warning(f"Album directory exists: {album_path}")
                
                # Find next available album number
                album_counter = 1
                while os.path.exists(os.path.join(output_dir, unique_artist, f"{unique_album}_{album_counter:02d}")):
                    album_counter += 1
                
                unique_album = f"{unique_album}_{album_counter:02d}"
                self.config['unique_album'] = unique_album
                logging.info(f"Using unique album name: {unique_album}")
            
            logging.info(f"No file collisions detected - will use unique naming: {unique_artist}/{unique_album}")
            return True
            
        except Exception as e:
            logging.error(f"Error checking for file collisions: {e}")
            # If we can't check, be safe and abort
            return False
    
    def test_internet_connection(self):
        """Test if internet connection is available"""
        try:
            requests.get("https://www.google.com", timeout=5)
            return True
        except:
            return False
    
    def rip_audio_cd(self):
        """Rip audio CD using abcde with enhanced metadata handling"""
        logging.info("Starting audio CD rip...")
        
        # Pre-fetch metadata for logging and verification
        metadata = self.get_disc_metadata()
        if metadata['disc_id']:
            logging.info(f"Pre-rip metadata check: Disc ID {metadata['disc_id']}")
            if metadata['artist'] and metadata['album']:
                logging.info(f"Expected output: {metadata['artist']} - {metadata['album']}")
        
        # Check if another rip is already in progress
        lockfile = "/tmp/auto-ripper.lock"
        if os.path.exists(lockfile):
            # Check if the process is still running
            try:
                with open(lockfile, 'r') as f:
                    old_pid = f.read().strip()
                if old_pid and os.path.exists(f"/proc/{old_pid}"):
                    logging.warning(f"Another rip process is already running (PID: {old_pid}), skipping")
                    return False
                else:
                    logging.info("Removing stale lock file")
                    os.remove(lockfile)
            except Exception as e:
                logging.warning(f"Error checking lock file: {e}, removing it")
                try:
                    os.remove(lockfile)
                except:
                    pass
        
        # CRITICAL: Check for potential file collisions before ripping
        disc_id = metadata.get('disc_id', 'unknown')
        if not self.check_for_file_collisions(disc_id):
            logging.error("Potential file collision detected - aborting rip to prevent data loss")
            return False
        
        try:
            # Create lock file
            with open(lockfile, 'w') as f:
                f.write(str(os.getpid()))
            
            # Try online metadata first
            logging.info("Attempting online metadata retrieval...")
            result = subprocess.run(['abcde', '-d', self.device, '-c', '/opt/auto-ripper/abcde.conf'], 
                                  capture_output=True, text=True, timeout=3600)  # 1 hour timeout
            
            if result.returncode == 0:
                logging.info("Online rip completed successfully")
                return True
            else:
                logging.warning("Online rip failed, checking for errors...")
                
                # Check if it's a metadata/network error
                stderr_lower = result.stderr.lower()
                if any(error in stderr_lower for error in ['timeout', 'connection', 'network', 'lookup', 'cddb']):
                    logging.warning("Network/metadata error detected, retrying in offline mode")
                    
                    # Try offline mode
                    logging.info("Retry command: abcde -d /dev/sr0 -c /opt/auto-ripper/abcde-offline.conf")
                    result = subprocess.run(['abcde', '-d', self.device, '-c', '/opt/auto-ripper/abcde-offline.conf'], 
                                          capture_output=True, text=True, timeout=3600)
                    
                    if result.returncode == 0:
                        logging.info("Offline rip completed successfully")
                        # Try to fix metadata for offline rips
                        self.fix_offline_metadata()
                        return True
                    else:
                        logging.error("Offline rip also failed")
                        logging.error(f"Full stderr: {result.stderr}")
                        return False
                else:
                    logging.error(f"Error ripping audio CD (return code: {result.returncode})")
                    logging.error(f"Full stderr: {result.stderr}")
                    return False
                    
        except subprocess.TimeoutExpired:
            logging.error("Rip process timed out after 1 hour")
            return False
        except Exception as e:
            logging.error(f"Unexpected error during rip: {e}")
            return False
        finally:
            # Clean up lock file
            try:
                if os.path.exists(lockfile):
                    os.remove(lockfile)
            except:
                pass
    
    def rip_dvd(self):
        """Rip DVD using handbrake-cli"""
        logging.info("Starting DVD rip...")
        
        try:
            # Use handbrake-cli for DVD ripping
            output_file = f"/tmp/dvd_rip_{int(time.time())}.mkv"
            result = subprocess.run(['handbrake-cli', '-i', self.device, '-o', output_file, '--preset', 'Fast 1080p30'], 
                                  capture_output=True, text=True, timeout=7200)  # 2 hour timeout
            
            if result.returncode == 0:
                logging.info("DVD rip completed successfully")
                return True
            else:
                logging.error(f"Error ripping DVD (return code: {result.returncode})")
                logging.error(f"Full stderr: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logging.error("DVD rip process timed out after 2 hours")
            return False
        except Exception as e:
            logging.error(f"Unexpected error during DVD rip: {e}")
            return False
    
    def eject_disc(self):
        """Eject the disc from the drive"""
        try:
            result = subprocess.run(['eject', self.device], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                logging.info("Disc ejected")
            else:
                logging.warning(f"Failed to eject disc: {result.stderr}")
        except Exception as e:
            logging.error(f"Error ejecting disc: {e}")
    
    def send_notification(self, message):
        """Send a notification (placeholder for future implementation)"""
        logging.info(f"Notification: {message}")
    
    def wait_for_disc(self):
        """Wait for a disc to be inserted"""
        logging.info("Waiting for disc insertion...")
        
        while True:
            if self.is_disc_present():
                time.sleep(2)  # Give it a moment to settle
                if self.is_disc_present():  # Double-check
                    return True
            time.sleep(1)
    
    def process_disc(self):
        """Main disc processing function"""
        logging.info("Disc detected, analyzing...")
        
        # Wait a moment for disc to settle
        logging.info("Waiting 3 seconds for disc to settle...")
        time.sleep(3)
        
        logging.info("Starting disc type determination...")
        disc_type = self.get_disc_type()
        logging.info(f"Disc type determination result: {disc_type}")
        
        success = False
        
        if disc_type == 'audio_cd':
            logging.info("Processing as audio CD...")
            success = self.rip_audio_cd()
            if success:
                self.send_notification("Audio CD ripped successfully")
                logging.info("Audio CD rip completed successfully")
            else:
                self.send_notification("Audio CD rip failed")
                logging.error("Audio CD rip failed")
                
        elif disc_type == 'data_disc':
            logging.info("Processing as data disc/DVD...")
            success = self.rip_dvd()
            if success:
                self.send_notification("DVD ripped successfully")
                logging.info("DVD rip completed successfully")
            else:
                self.send_notification("DVD rip failed")
                logging.error("DVD rip failed")
        else:
            logging.warning(f"Unknown disc type detected: {disc_type}")
            logging.warning("This could be due to:")
            logging.warning("1. Disc is damaged or dirty")
            logging.warning("2. Not an audio CD or data disc")
            logging.warning("3. Permission issues reading the disc")
            logging.warning("4. Drive hardware issues")
            logging.warning("Skipping rip process...")
            self.send_notification("Unknown disc type - check logs for details")
        
        # Only eject if configured to do so
        if self.config.get('eject_after_rip', True):
            logging.info("Ejecting disc (eject_after_rip = true)")
            self.eject_disc()
        else:
            logging.info("Not ejecting disc (eject_after_rip = false)")
        
        return success
    
    def run(self):
        """Main run loop"""
        logging.info("Auto-ripper started")
        
        try:
            while True:
                self.wait_for_disc()
                self.process_disc()
                
                # Wait a moment before checking for next disc
                time.sleep(5)
                
        except KeyboardInterrupt:
            logging.info("Auto-ripper stopped by user")
        except Exception as e:
            logging.error(f"Unexpected error in main loop: {e}")

def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--daemon':
        # Run as daemon (called by systemd or udev)
        ripper = AutoRipper()
        ripper.process_disc()
    else:
        # Run interactive mode
        ripper = AutoRipper()
        ripper.run()

if __name__ == "__main__":
    main()
