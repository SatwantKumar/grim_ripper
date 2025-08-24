#!/usr/bin/env python3
"""
Enhanced CD Detection Module
Addresses issues where CD detection fails after initial success
"""

import subprocess
import time
import os
import logging
from typing import Optional, Tuple

class EnhancedCDDetector:
    """
    Enhanced CD detection with improved reliability and error handling
    """
    
    def __init__(self, device: str = '/dev/sr0'):
        self.device = device
        self.max_detection_attempts = 5
        self.base_timeout = 10
        self.progressive_timeout = True
        
    def reset_drive_state(self) -> bool:
        """
        Reset the optical drive to clear any stuck states
        """
        try:
            logging.info("Resetting optical drive state...")
            
            # Try to eject and close the tray
            subprocess.run(['eject', self.device], timeout=10, capture_output=True)
            time.sleep(2)
            
            # Some drives support close command
            try:
                subprocess.run(['eject', '-t', self.device], timeout=10, capture_output=True)
                time.sleep(2)
            except:
                pass  # Not all drives support this
                
            logging.info("Drive state reset completed")
            return True
            
        except Exception as e:
            logging.warning(f"Drive reset failed: {e}")
            return False
    
    def check_device_permissions(self) -> Tuple[bool, str]:
        """
        Check if the device exists and is accessible
        Returns (success, error_message)
        """
        if not os.path.exists(self.device):
            return False, f"Device {self.device} does not exist"
            
        if not os.access(self.device, os.R_OK):
            return False, f"Device {self.device} is not readable - check permissions"
            
        return True, "Device permissions OK"
    
    def wait_for_drive_ready(self, max_wait: int = 30) -> bool:
        """
        Wait for the drive to become ready after media insertion
        """
        logging.info(f"Waiting for drive to become ready (max {max_wait}s)...")
        
        start_time = time.time()
        while time.time() - start_time < max_wait:
            try:
                # Use blockdev to check if device is ready
                result = subprocess.run(['blockdev', '--test-ro', self.device], 
                                      capture_output=True, timeout=5)
                if result.returncode == 0:
                    logging.info("Drive is ready")
                    return True
                    
            except subprocess.TimeoutExpired:
                pass
            except Exception as e:
                logging.debug(f"Drive readiness check failed: {e}")
                
            time.sleep(2)
            
        logging.warning("Drive did not become ready within timeout")
        return False
    
    def detect_audio_cd_robust(self) -> Tuple[bool, Optional[str]]:
        """
        Robust audio CD detection with multiple methods and retries
        Returns (is_audio_cd, disc_id)
        """
        logging.info("Starting robust audio CD detection...")
        
        # Check device permissions first
        perms_ok, error_msg = self.check_device_permissions()
        if not perms_ok:
            logging.error(error_msg)
            return False, None
            
        # Wait for drive to be ready
        if not self.wait_for_drive_ready():
            logging.error("Drive not ready for detection")
            return False, None
        
        for attempt in range(1, self.max_detection_attempts + 1):
            timeout = self.base_timeout if not self.progressive_timeout else self.base_timeout * attempt
            
            logging.info(f"Audio CD detection attempt {attempt}/{self.max_detection_attempts} (timeout: {timeout}s)")
            
            # Method 1: cd-discid (most reliable for audio CDs)
            try:
                result = subprocess.run(['cd-discid', self.device], 
                                      capture_output=True, text=True, timeout=timeout)
                if result.returncode == 0 and result.stdout.strip():
                    disc_id = result.stdout.strip().split()[0]
                    logging.info(f"Audio CD detected via cd-discid: {disc_id}")
                    return True, disc_id
                    
            except subprocess.TimeoutExpired:
                logging.warning(f"cd-discid timed out on attempt {attempt}")
            except FileNotFoundError:
                logging.error("cd-discid command not found")
            except Exception as e:
                logging.warning(f"cd-discid failed on attempt {attempt}: {e}")
            
            # Method 2: cdparanoia with query
            try:
                result = subprocess.run(['cdparanoia', '-Q', '-d', self.device], 
                                      capture_output=True, text=True, timeout=timeout)
                if result.returncode == 0 and 'track' in result.stderr.lower():
                    logging.info("Audio CD detected via cdparanoia")
                    # Try to get disc ID with cd-discid if available
                    try:
                        id_result = subprocess.run(['cd-discid', self.device], 
                                                 capture_output=True, text=True, timeout=5)
                        if id_result.returncode == 0:
                            disc_id = id_result.stdout.strip().split()[0]
                            return True, disc_id
                    except:
                        pass
                    return True, None
                    
            except subprocess.TimeoutExpired:
                logging.warning(f"cdparanoia timed out on attempt {attempt}")
            except FileNotFoundError:
                logging.error("cdparanoia command not found")
            except Exception as e:
                logging.warning(f"cdparanoia failed on attempt {attempt}: {e}")
            
            # Method 3: Direct read test for any media
            try:
                result = subprocess.run(['dd', f'if={self.device}', 'of=/dev/null', 
                                       'bs=2048', 'count=1'], 
                                      capture_output=True, timeout=timeout)
                if result.returncode == 0:
                    logging.info(f"Media detected via dd on attempt {attempt}, but type unknown")
                    # Media exists but may not be audio CD
                    # Continue to next attempt with longer timeout
                else:
                    logging.warning(f"No readable media detected on attempt {attempt}")
                    
            except subprocess.TimeoutExpired:
                logging.warning(f"dd read timed out on attempt {attempt}")
            except Exception as e:
                logging.warning(f"dd read failed on attempt {attempt}: {e}")
            
            # Progressive delay between attempts
            if attempt < self.max_detection_attempts:
                delay = min(5 * attempt, 15)  # 5, 10, 15, 15... seconds
                logging.info(f"Waiting {delay}s before next attempt...")
                time.sleep(delay)
        
        logging.error("Audio CD detection failed after all attempts")
        return False, None
    
    def detect_data_disc(self) -> bool:
        """
        Detect if media is a data disc (DVD/CD-ROM)
        """
        try:
            result = subprocess.run(['blkid', self.device], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                logging.info("Data disc detected via blkid")
                return True
                
        except Exception as e:
            logging.debug(f"blkid detection failed: {e}")
            
        try:
            result = subprocess.run(['file', '-s', self.device], 
                                  capture_output=True, text=True, timeout=10)
            if 'ISO 9660' in result.stdout or 'UDF' in result.stdout:
                logging.info("Data disc detected via file command")
                return True
                
        except Exception as e:
            logging.debug(f"file command detection failed: {e}")
            
        return False
    
    def get_comprehensive_disc_info(self) -> dict:
        """
        Get comprehensive information about the inserted disc
        """
        info = {
            'device': self.device,
            'is_audio_cd': False,
            'is_data_disc': False,
            'disc_id': None,
            'media_present': False,
            'device_ready': False,
            'permissions_ok': False,
            'error_messages': []
        }
        
        # Check device permissions
        perms_ok, error_msg = self.check_device_permissions()
        info['permissions_ok'] = perms_ok
        if not perms_ok:
            info['error_messages'].append(error_msg)
            return info
            
        # Check if drive is ready
        info['device_ready'] = self.wait_for_drive_ready(15)
        if not info['device_ready']:
            info['error_messages'].append("Drive not ready")
            
        # Basic media presence test
        try:
            result = subprocess.run(['dd', f'if={self.device}', 'of=/dev/null', 
                                   'bs=2048', 'count=1'], 
                                  capture_output=True, timeout=10)
            info['media_present'] = (result.returncode == 0)
        except:
            info['media_present'] = False
            
        if not info['media_present']:
            info['error_messages'].append("No readable media detected")
            return info
            
        # Detect audio CD
        is_audio, disc_id = self.detect_audio_cd_robust()
        info['is_audio_cd'] = is_audio
        info['disc_id'] = disc_id
        
        # Detect data disc if not audio
        if not is_audio:
            info['is_data_disc'] = self.detect_data_disc()
            
        return info


def main():
    """Test the enhanced CD detector"""
    import sys
    
    # Set up logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    device = sys.argv[1] if len(sys.argv) > 1 else '/dev/sr0'
    detector = EnhancedCDDetector(device)
    
    print(f"Testing enhanced CD detection on {device}")
    print("=" * 50)
    
    info = detector.get_comprehensive_disc_info()
    
    print(f"Device: {info['device']}")
    print(f"Permissions OK: {info['permissions_ok']}")
    print(f"Device Ready: {info['device_ready']}")
    print(f"Media Present: {info['media_present']}")
    print(f"Is Audio CD: {info['is_audio_cd']}")
    print(f"Is Data Disc: {info['is_data_disc']}")
    print(f"Disc ID: {info['disc_id']}")
    
    if info['error_messages']:
        print("\nErrors:")
        for error in info['error_messages']:
            print(f"  - {error}")
    
    if info['is_audio_cd']:
        print("\n✅ SUCCESS: Audio CD detected and ready for ripping!")
    elif info['is_data_disc']:
        print("\n✅ SUCCESS: Data disc detected!")
    elif info['media_present']:
        print("\n⚠️  WARNING: Media detected but type unknown")
    else:
        print("\n❌ FAILURE: No usable media detected")


if __name__ == "__main__":
    main()
