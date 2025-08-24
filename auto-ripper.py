#!/usr/bin/env python3
"""
Raspberry Pi Auto CD/DVD Ripper
Handles automatic detection, ripping, and organization of optical media
"""

import subprocess
import time
import os
import sys
import logging
import json
from pathlib import Path
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/auto-ripper/auto-ripper.log'),
        logging.StreamHandler()
    ]
)

class AutoRipper:
    def __init__(self):
        # Check for device from environment (set by udev trigger)
        self.device = os.environ.get('CDROM_DEVICE', '/dev/sr0')
        self.config_file = '/opt/auto-ripper/config.json'
        self.load_config()
        logging.info(f"AutoRipper initialized with device: {self.device}")
        logging.info(f"Running as user: {os.getenv('USER', 'unknown')}, UID: {os.getuid()}")
        
    def load_config(self):
        """Load configuration from JSON file"""
        default_config = {
            "output_dir": "/media/rsd/MUSIC",
            "formats": ["flac", "mp3"],
            "eject_after_rip": True,
            "notification_enabled": False,
            "network_copy": False,
            "network_path": "",
            "max_retries": 3
        }
        
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.config = {**default_config, **json.load(f)}
            else:
                self.config = default_config
                self.save_config()
        except Exception as e:
            logging.error(f"Error loading config: {e}")
            self.config = default_config
    
    def save_config(self):
        """Save configuration to JSON file"""
        try:
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=4)
        except Exception as e:
            logging.error(f"Error saving config: {e}")
    
    def is_disc_present(self):
        """Check if a disc is present in the drive"""
        logging.info(f"Checking for disc in {self.device}")
        
        try:
            # First check if device exists
            if not os.path.exists(self.device):
                logging.error(f"Device {self.device} does not exist")
                return False
            
            # Try multiple detection methods
            
            # Method 1: Try cdparanoia for audio CDs
            try:
                result = subprocess.run(['cdparanoia', '-Q', '-d', self.device], 
                                      capture_output=True, text=True, timeout=15)
                if result.returncode == 0:
                    logging.info(f"Audio CD detected in {self.device} via cdparanoia")
                    return True
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
            
            # Method 2: Try cd-discid for audio CDs
            try:
                result = subprocess.run(['cd-discid', self.device], 
                                      capture_output=True, text=True, timeout=15)
                if result.returncode == 0:
                    logging.info(f"Audio CD detected in {self.device} via cd-discid")
                    return True
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
            
            # Method 3: Try blkid for data discs
            try:
                result = subprocess.run(['blkid', self.device], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    logging.info(f"Data disc detected in {self.device} via blkid")
                    return True
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
            
            # Method 4: Last resort - try dd
            try:
                result = subprocess.run(['dd', f'if={self.device}', 'of=/dev/null', 'bs=2048', 'count=1'], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    logging.info(f"Disc confirmed present in {self.device} via dd")
                    return True
            except subprocess.TimeoutExpired:
                pass
            
            logging.info(f"No readable disc detected in {self.device}")
            return False
                
        except Exception as e:
            logging.error(f"Error checking for disc: {e}")
            return False
    
    def get_disc_type(self):
        """Determine if the disc is audio CD or data/DVD"""
        try:
            # Check for audio CD first
            result = subprocess.run(['cd-discid', self.device], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                return 'audio_cd'
            
            # Check for data disc/DVD
            result = subprocess.run(['file', '-s', self.device], 
                                  capture_output=True, text=True, timeout=10)
            if 'ISO 9660' in result.stdout or 'UDF' in result.stdout:
                return 'data_disc'
                
            return 'unknown'
        except Exception as e:
            logging.error(f"Error determining disc type: {e}")
            return 'unknown'
    
    def rip_audio_cd(self):
        """Rip audio CD using abcde"""
        logging.info("Starting audio CD rip...")
        
        # Check if another rip is already in progress
        lockfile = "/tmp/auto-ripper.lock"
        if os.path.exists(lockfile):
            logging.warning("Another rip process is already running, skipping")
            return False
        
        try:
            # Create lock file
            with open(lockfile, 'w') as f:
                f.write(str(os.getpid()))
            
            # Test internet connectivity for metadata
            internet_available = self.test_internet_connection()
            
            if internet_available:
                logging.info("Internet available, using online metadata")
                cmd = ['abcde', '-d', self.device]
            else:
                logging.info("No internet connection, using offline mode")
                cmd = ['abcde', '-d', self.device, '-c', '/opt/auto-ripper/abcde-offline.conf']
            
            logging.info(f"Running command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
            
            # Log the output for debugging
            if result.stdout:
                logging.info(f"abcde stdout: {result.stdout[:500]}...")
            if result.stderr:
                logging.warning(f"abcde stderr: {result.stderr[:500]}...")
            
            if result.returncode == 0:
                logging.info("Audio CD ripped successfully")
                # Check if files were actually created
                output_files = []
                try:
                    import glob
                    output_files = glob.glob(f"{self.config['output_dir']}/**/*.flac", recursive=True)
                    output_files.extend(glob.glob(f"{self.config['output_dir']}/**/*.mp3", recursive=True))
                    logging.info(f"Found {len(output_files)} output files")
                    for f in output_files[-3:]:  # Log last 3 files
                        logging.info(f"Created: {f}")
                except Exception as e:
                    logging.warning(f"Could not check output files: {e}")
                return True
            else:
                # Check if error is network-related and retry offline
                if "name resolution" in result.stderr.lower() or "network" in result.stderr.lower():
                    logging.warning("Network error detected, retrying in offline mode")
                    cmd = ['abcde', '-d', self.device, '-c', '/opt/auto-ripper/abcde-offline.conf']
                    logging.info(f"Retry command: {' '.join(cmd)}")
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
                    
                    if result.stdout:
                        logging.info(f"abcde retry stdout: {result.stdout[:500]}...")
                    if result.stderr:
                        logging.warning(f"abcde retry stderr: {result.stderr[:500]}...")
                    
                    if result.returncode == 0:
                        logging.info("Audio CD ripped successfully (offline mode)")
                        return True
                
                logging.error(f"Error ripping audio CD (return code: {result.returncode})")
                logging.error(f"Full stderr: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logging.error("Audio CD rip timed out")
            return False
        except Exception as e:
            logging.error(f"Unexpected error during audio CD rip: {e}")
            return False
        finally:
            # Clean up lock file
            if os.path.exists(lockfile):
                os.remove(lockfile)
    
    def test_internet_connection(self):
        """Test if internet connection is available"""
        try:
            import socket
            socket.create_connection(("8.8.8.8", 53), timeout=5)
            return True
        except OSError:
            return False
    
    def rip_dvd(self):
        """Rip DVD using HandBrakeCLI"""
        logging.info("Starting DVD rip...")
        
        try:
            # Get DVD title
            disc_label = self.get_disc_label() or f"DVD_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            output_file = f"{self.config['output_dir']}/{disc_label}.mp4"
            
            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_file), exist_ok=True)
            
            # Use HandBrakeCLI for DVD ripping
            cmd = [
                'HandBrakeCLI',
                '-i', self.device,
                '-o', output_file,
                '--preset', 'High Profile',
                '--main-feature'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=7200)
            
            if result.returncode == 0:
                logging.info(f"DVD ripped successfully to {output_file}")
                return True
            else:
                logging.error(f"Error ripping DVD: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logging.error("DVD rip timed out")
            return False
        except Exception as e:
            logging.error(f"Unexpected error during DVD rip: {e}")
            return False
    
    def get_disc_label(self):
        """Get disc label/title"""
        try:
            result = subprocess.run(['blkid', '-o', 'value', '-s', 'LABEL', self.device],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except Exception:
            pass
        return None
    
    def eject_disc(self):
        """Eject the disc"""
        if self.config['eject_after_rip']:
            try:
                subprocess.run(['eject', self.device], timeout=10)
                logging.info("Disc ejected")
                return True
            except Exception as e:
                logging.error(f"Error ejecting disc: {e}")
                return False
        return True
    
    def send_notification(self, message):
        """Send notification (if enabled)"""
        if self.config['notification_enabled']:
            try:
                # You can implement various notification methods here
                # For now, just log the notification
                logging.info(f"NOTIFICATION: {message}")
            except Exception as e:
                logging.error(f"Error sending notification: {e}")
    
    def copy_to_network(self, source_dir):
        """Copy ripped files to network location"""
        if self.config['network_copy'] and self.config['network_path']:
            try:
                cmd = ['rsync', '-av', '--progress', source_dir, self.config['network_path']]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
                
                if result.returncode == 0:
                    logging.info(f"Files copied to network: {self.config['network_path']}")
                    return True
                else:
                    logging.error(f"Error copying to network: {result.stderr}")
                    return False
            except Exception as e:
                logging.error(f"Network copy error: {e}")
                return False
        return True
    
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
        
        disc_type = self.get_disc_type()
        logging.info(f"Disc type: {disc_type}")
        
        success = False
        
        if disc_type == 'audio_cd':
            success = self.rip_audio_cd()
            if success:
                self.send_notification("Audio CD ripped successfully")
            else:
                self.send_notification("Audio CD rip failed")
                
        elif disc_type == 'data_disc':
            success = self.rip_dvd()
            if success:
                self.send_notification("DVD ripped successfully")
            else:
                self.send_notification("DVD rip failed")
        else:
            logging.warning("Unknown disc type, skipping")
            self.send_notification("Unknown disc type detected")
        
        # Always try to eject
        self.eject_disc()
        
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
