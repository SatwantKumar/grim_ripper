# Contributing to Grim Ripper - Raspberry Pi Auto CD Ripper

*By Satwant Kumar (Satwant.Dagar@gmail.com)*

Thank you for your interest in contributing! This project aims to make CD ripping on Raspberry Pi as simple and reliable as possible.

## 🤝 How to Contribute

### Reporting Issues
- Use the [GitHub Issues](https://github.com/SatwantKumar/grim_ripper/issues) page
- Include your Raspberry Pi model and OS version
- Provide detailed steps to reproduce the problem
- Include relevant log files from `/var/log/auto-ripper/`

### Suggesting Features
- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Consider backward compatibility

### Code Contributions
1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test on actual Raspberry Pi hardware
5. Submit a pull request

## 🧪 Testing

### Local Development
```bash
# Clone your fork
git clone https://github.com/SatwantKumar/grim_ripper.git
cd grim_ripper

# Test the installer in a container or VM
sudo ./install.sh
```

### Hardware Testing
Please test on real Raspberry Pi hardware with:
- Different CD types (audio, mixed, data)
- Various USB optical drives
- Different network conditions (online/offline)

### Test Cases
- ✅ Fresh installation
- ✅ Upgrade from previous version
- ✅ Permission handling
- ✅ Error recovery
- ✅ Multi-disc handling
- ✅ Network storage integration

## 📝 Code Standards

### Python Code
- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Include docstrings for functions and classes
- Handle exceptions gracefully
- Log important events

### Shell Scripts
- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Quote variables properly
- Use meaningful function names
- Include comments for complex logic

### Configuration Files
- Use JSON for structured config
- Provide sensible defaults
- Document all options
- Maintain backward compatibility

## 🗂️ Project Structure

```
grim_ripper/
├── auto-ripper.py          # Main application
├── install.sh              # One-click installer
├── config.json             # Default configuration
├── abcde.conf              # Online ripping config
├── abcde-offline.conf      # Offline ripping config
├── trigger-rip.sh          # udev trigger script
├── 99-auto-ripper.rules    # udev rules
├── utils/                  # Utility scripts
│   ├── troubleshoot.sh     # Diagnostics
│   ├── cleanup.sh          # Cleanup tools
│   └── test-detection.sh   # Testing tools
├── examples/               # Example configurations
├── docs/                   # Additional documentation
├── tests/                  # Test scripts
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

## 🎯 Development Priorities

### High Priority
- 🔧 Improve error handling and recovery
- 📱 Add web interface for monitoring
- 🔍 Enhanced disc detection reliability
- 📊 Better progress reporting

### Medium Priority
- 🎵 Additional audio format support
- 🌐 Integration with music services
- 📱 Mobile app for notifications
- 🐳 Docker container support

### Low Priority
- 🤖 Machine learning for disc recognition
- 🎨 GUI application
- 🏠 Home Assistant integration

## 🐛 Bug Fixes

### Common Issues to Watch For
- Permission problems after system updates
- USB optical drive compatibility
- Network timeout handling
- Log file rotation and cleanup
- Metadata lookup failures

### Debug Information
When reporting bugs, include:
```bash
# System info
cat /proc/device-tree/model
cat /etc/os-release

# Hardware detection
lsusb | grep -i optical
ls -la /dev/sr*

# Service status
systemctl status auto-ripper

# Recent logs
tail -50 /var/log/auto-ripper/auto-ripper.log
```

## 📚 Documentation

### Required Documentation
- Update README.md for new features
- Add inline code comments
- Update configuration examples
- Include troubleshooting steps

### Documentation Standards
- Use clear, concise language
- Include code examples
- Test all instructions
- Keep examples current

## 🎉 Recognition

Contributors will be:
- Listed in the README.md contributors section
- Credited in release notes
- Invited to maintain specific components

## 📞 Getting Help

- 💬 [GitHub Discussions](https://github.com/SatwantKumar/grim_ripper/discussions)
- 🐛 [Issues](https://github.com/SatwantKumar/grim_ripper/issues)
- 📧 Contact maintainers for complex questions

## 🚀 Release Process

1. Update version numbers
2. Update CHANGELOG.md
3. Test on multiple Pi models
4. Create release branch
5. Tag release
6. Update documentation

Thank you for helping make CD ripping on Raspberry Pi better for everyone! 🎵
