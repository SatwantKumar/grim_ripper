#!/usr/bin/env python3
"""
Patch for auto-ripper.py to improve CD detection reliability
This script provides enhanced methods that can replace the existing detection logic
"""

import subprocess
import time
import os
import logging

def enhanced_is_disc_present(device):
    """
    Enhanced disc presence detection with better error handling and timeouts
    Replaces the original is_disc_present method
    """
    logging.info(f"Enhanced: Checking for disc in {device}")
    
    try:
        # First check if device exists
        if not os.path.exists(device):
            logging.error(f"Device {device} does not exist")
            return False
        
        # Check device permissions
        if not os.access(device, os.R_OK):
            logging.error(f"Device {device} is not readable - permission denied")
            logging.error("Try: sudo usermod -a -G cdrom $(whoami)")
            return False
        
        # Enhanced detection with progressive timeouts and multiple attempts
        max_attempts = 3
        base_timeout = 15
        
        for attempt in range(1, max_attempts + 1):
            timeout = base_timeout * attempt  # Progressive timeout: 15, 30, 45 seconds
            logging.info(f"Disc detection attempt {attempt}/{max_attempts} (timeout: {timeout}s)")
            
            # Method 1: Try cd-discid first (most reliable for audio CDs)
            try:
                result = subprocess.run(['cd-discid', device], 
                                      capture_output=True, text=True, timeout=timeout)
                if result.returncode == 0 and result.stdout.strip():
                    logging.info(f"Audio CD detected in {device} via cd-discid (attempt {attempt})")
                    return True
            except subprocess.TimeoutExpired:
                logging.warning(f"cd-discid timed out on attempt {attempt}")
            except FileNotFoundError:
                logging.debug("cd-discid not available")
            except Exception as e:
                logging.debug(f"cd-discid failed on attempt {attempt}: {e}")
            
            # Method 2: Try cdparanoia (also confirmed working for audio CDs)
            try:
                result = subprocess.run(['cdparanoia', '-Q', '-d', device], 
                                      capture_output=True, text=True, timeout=timeout)
                if result.returncode == 0:
                    logging.info(f"Audio CD detected in {device} via cdparanoia (attempt {attempt})")
                    return True
            except subprocess.TimeoutExpired:
                logging.warning(f"cdparanoia timed out on attempt {attempt}")
            except FileNotFoundError:
                logging.debug("cdparanoia not available")
            except Exception as e:
                logging.debug(f"cdparanoia failed on attempt {attempt}: {e}")
            
            # Method 3: Try blkid for data discs
            try:
                result = subprocess.run(['blkid', device], 
                                      capture_output=True, text=True, timeout=min(timeout, 10))
                if result.returncode == 0:
                    logging.info(f"Data disc detected in {device} via blkid (attempt {attempt})")
                    return True
            except subprocess.TimeoutExpired:
                logging.warning(f"blkid timed out on attempt {attempt}")
            except FileNotFoundError:
                logging.debug("blkid not available")
            except Exception as e:
                logging.debug(f"blkid failed on attempt {attempt}: {e}")
            
            # Method 4: Try blockdev to check device readiness
            try:
                result = subprocess.run(['blockdev', '--test-ro', device], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    logging.info(f"Device {device} is ready (via blockdev)")
                    # Device is ready, try dd as final test
                    try:
                        result = subprocess.run(['dd', f'if={device}', 'of=/dev/null', 'bs=2048', 'count=1'], 
                                              capture_output=True, text=True, timeout=min(timeout, 15))
                        if result.returncode == 0:
                            logging.info(f"Disc confirmed present in {device} via dd (attempt {attempt})")
                            return True
                    except subprocess.TimeoutExpired:
                        logging.warning(f"dd read timed out on attempt {attempt}")
                    except Exception as e:
                        logging.debug(f"dd read failed on attempt {attempt}: {e}")
            except Exception as e:
                logging.debug(f"blockdev test failed on attempt {attempt}: {e}")
            
            # Wait before next attempt (except on last attempt)
            if attempt < max_attempts:
                wait_time = 5 * attempt  # Progressive wait: 5, 10 seconds
                logging.info(f"Waiting {wait_time}s before next attempt...")
                time.sleep(wait_time)
        
        logging.info(f"No readable disc detected in {device} after {max_attempts} attempts")
        return False
            
    except Exception as e:
        logging.error(f"Error checking for disc: {e}")
        return False

def enhanced_get_disc_type(device):
    """
    Enhanced disc type detection with better reliability
    Replaces the original get_disc_type method
    """
    try:
        logging.info("Enhanced: Determining disc type...")
        
        # Check for audio CD first with multiple methods
        audio_cd_detected = False
        
        # Method 1: cd-discid (most reliable)
        try:
            result = subprocess.run(['cd-discid', device], 
                                  capture_output=True, text=True, timeout=15)
            if result.returncode == 0 and result.stdout.strip():
                logging.info("Audio CD confirmed via cd-discid")
                audio_cd_detected = True
        except Exception as e:
            logging.debug(f"cd-discid type check failed: {e}")
        
        # Method 2: cdparanoia with track listing
        if not audio_cd_detected:
            try:
                result = subprocess.run(['cdparanoia', '-Q', '-d', device], 
                                      capture_output=True, text=True, timeout=15)
                if result.returncode == 0 and 'track' in result.stderr.lower():
                    logging.info("Audio CD confirmed via cdparanoia track listing")
                    audio_cd_detected = True
            except Exception as e:
                logging.debug(f"cdparanoia type check failed: {e}")
        
        if audio_cd_detected:
            return 'audio_cd'
        
        # Check for data disc/DVD
        try:
            result = subprocess.run(['blkid', device], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                logging.info("Data disc confirmed via blkid")
                return 'data_disc'
        except Exception as e:
            logging.debug(f"blkid type check failed: {e}")
        
        # Alternative data disc detection
        try:
            result = subprocess.run(['file', '-s', device], 
                                  capture_output=True, text=True, timeout=10)
            if 'ISO 9660' in result.stdout or 'UDF' in result.stdout:
                logging.info("Data disc confirmed via file command")
                return 'data_disc'
        except Exception as e:
            logging.debug(f"file command type check failed: {e}")
        
        logging.warning("Could not determine disc type")
        return 'unknown'
        
    except Exception as e:
        logging.error(f"Error determining disc type: {e}")
        return 'unknown'

def enhanced_wait_for_disc(device):
    """
    Enhanced wait function with better disc settling logic
    Replaces the original wait_for_disc method
    """
    logging.info("Enhanced: Waiting for disc insertion...")
    
    consecutive_detections = 0
    required_consecutive = 2  # Require 2 consecutive positive detections
    
    while True:
        if enhanced_is_disc_present(device):
            consecutive_detections += 1
            logging.info(f"Disc detected ({consecutive_detections}/{required_consecutive})")
            
            if consecutive_detections >= required_consecutive:
                # Give extra settling time for reliable detection
                logging.info("Disc confirmed present, allowing settling time...")
                time.sleep(5)
                # Final confirmation
                if enhanced_is_disc_present(device):
                    logging.info("Disc ready for processing")
                    return True
                else:
                    logging.warning("Disc disappeared during settling, restarting detection")
                    consecutive_detections = 0
            else:
                time.sleep(3)  # Wait between consecutive checks
        else:
            if consecutive_detections > 0:
                logging.info("Disc detection lost, resetting counter")
            consecutive_detections = 0
            time.sleep(2)  # Standard polling interval

# Additional helper functions

def check_drive_health(device):
    """
    Check the health of the optical drive
    """
    logging.info("Checking optical drive health...")
    
    health_info = {
        'device_exists': os.path.exists(device),
        'device_readable': False,
        'recent_errors': [],
        'recommendations': []
    }
    
    if health_info['device_exists']:
        health_info['device_readable'] = os.access(device, os.R_OK)
        
        if not health_info['device_readable']:
            health_info['recommendations'].append("Fix permissions: sudo usermod -a -G cdrom $(whoami)")
    else:
        health_info['recommendations'].append("Check if optical drive is connected")
    
    # Check for recent errors in dmesg
    try:
        result = subprocess.run(['dmesg'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            lines = result.stdout.split('\n')
            recent_lines = lines[-100:]  # Check last 100 lines
            for line in recent_lines:
                if any(term in line.lower() for term in ['sr0', 'optical', 'cd', 'dvd']) and any(term in line.lower() for term in ['error', 'fail', 'timeout']):
                    health_info['recent_errors'].append(line)
        
        if health_info['recent_errors']:
            health_info['recommendations'].append("Consider cleaning the drive laser or checking cables")
    except:
        pass
    
    return health_info

def reset_drive_state(device):
    """
    Reset the optical drive state to clear any stuck conditions
    """
    logging.info("Resetting optical drive state...")
    
    try:
        # Eject the drive
        subprocess.run(['eject', device], timeout=10, capture_output=True)
        time.sleep(3)
        
        # Try to close the tray (if supported)
        try:
            subprocess.run(['eject', '-t', device], timeout=10, capture_output=True)
            time.sleep(3)
        except:
            pass  # Not all drives support this
        
        logging.info("Drive state reset completed")
        return True
        
    except Exception as e:
        logging.error(f"Drive state reset failed: {e}")
        return False

# Example usage and testing
if __name__ == "__main__":
    import sys
    
    # Set up logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    device = sys.argv[1] if len(sys.argv) > 1 else '/dev/sr0'
    
    print(f"Testing enhanced CD detection on {device}")
    print("=" * 50)
    
    # Check drive health
    health = check_drive_health(device)
    print(f"Drive health check:")
    print(f"  Device exists: {health['device_exists']}")
    print(f"  Device readable: {health['device_readable']}")
    if health['recent_errors']:
        print(f"  Recent errors: {len(health['recent_errors'])}")
    if health['recommendations']:
        print(f"  Recommendations:")
        for rec in health['recommendations']:
            print(f"    - {rec}")
    
    print("\nTesting disc detection...")
    if enhanced_is_disc_present(device):
        disc_type = enhanced_get_disc_type(device)
        print(f"✅ Disc detected! Type: {disc_type}")
    else:
        print("❌ No disc detected")
        print("\nTrying drive reset...")
        reset_drive_state(device)
        print("Please insert a disc and run the test again.")
