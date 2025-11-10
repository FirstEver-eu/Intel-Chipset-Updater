# Intel Chipset Driver Updater

Automated tool to detect and install the latest Intel chipset INF drivers.  
Unlike official Intel releases, this tool can identify the highest available driver version for each platform and also install drivers for older platforms such as B85; X79/C600; Z87, H87, H81/C220; and X99/C610 — platforms whose drivers are not included in the latest Intel Chipset Driver Software.

## 🪪 Version
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/FirstEver-eu/Intel-Chipset-Updater?style=flat-square&label=Latest%20Version)](https://github.com/FirstEver-eu/Intel-Chipset-Updater/releases)

## 🚀 Features

- **Platform Detection**: Automatically identifies Intel chipset platforms
- **Version Comparison**: Checks current driver versions vs platform-specific latest available
- **Smart Driver Selection**: Uses appropriate drivers for each chipset generation
- **Safe Installation**: Uses official Intel installers with proper parameters
- **Clean Operation**: Automatically cleans temporary files after installation
- **Restart Management**: Prevents automatic restart, allows user-controlled reboot

## 📋 Supported Platforms

### Latest Platforms
- Intel® Core™ Ultra (1st Generation) - Lunar Lake, Meteor Lake
- 14th Generation (Raptor Lake Refresh) - Arrow Lake
- 13th Generation (Raptor Lake) - Z790, W780
- 12th Generation (Alder Lake) - Z690, B660, W680

### Modern Platforms  
- 11th Generation (Tiger Lake / Rocket Lake)
- 10th Generation (Comet Lake / Ice Lake)
- 9th Generation (Coffee Lake Refresh) - Z390, Z370, X299

### Legacy Platforms
- 8th Generation (Coffee Lake) - Z370
- 7th Generation (Kaby Lake) - Z270, H270
- 6th Generation (Skylake)
- 5th Generation (Broadwell) - X99, B85
- 4th Generation (Haswell/Haswell-E) - Z87, X99
- 3rd Generation (Ivy Bridge-E) - X79

### Server & Embedded
- Granite Rapids, Sapphire Rapids, Emmitsburg servers
- Lewisburg C620 series
- Mobile/Embedded: Lakefield, JasperLake, ElkhartLake, and more

## 🛠️ Usage

### Option 1: Download Complete Package (Recommended)
1. Download the latest SFX archive `ChipsetUpdater-10.1.x-Driver64-Win10-Win11.exe` from [Releases](https://github.com/FirstEver-eu/Intel-WiFi-BT-Updater/releases)
2. Run the executable as Administrator
3. Follow the on-screen prompts

### Option 2: Manual Scripts
1. Download both `Update-Intel-Chipset.bat` and `Update-Intel-Chipset.ps1`
2. Ensure both files are in the same directory
3. Run `Update-Intel-Chipset.bat` as Administrator
4. Follow the on-screen prompts

### 🔍 Troubleshooting
For detailed logging and troubleshooting, use:
1. Download both `Get-Intel-HWIDs.bat` and `Get-Intel-HWIDs.ps1`
2. Run `Get-Intel-HWIDs.bat` as Administrator
3. Provides extensive logging to C:\Intel_HWIDs_Report.txt for issue diagnosis.

## ⚠️ Important Notes

- **Administrator Rights Required**: Script must be run as Administrator
- **Restart Required**: Computer restart is needed after driver installation
- **Temporary Black Screen**: During PCIe bus driver updates, screen may temporarily go black
- **Device Reconnection**: Some devices may temporarily disconnect during installation

## 🔧 Manual Update

Driver information is maintained in:
- `chipset-drivers.txt` - Contains download links and versions
- `Intel_Chipsets_List.md` - Platform compatibility matrix

If automatic detection fails, you can manually update these files with the latest driver information.

## 🤝 Contributing

Platform and driver information is maintained based on Intel official documentation and manufacturer updates. If you have access to newer platform information or driver links, please update the relevant files.

## 📝 License

This project is provided as-is for educational and convenience purposes.

## ⚠️ Disclaimer

This tool is not affiliated with Intel Corporation. Drivers are sourced from official Intel servers and manufacturer websites. Use at your own risk. Always backup your system before updating drivers.

## 📸 Screenshot

<img width="602" height="832" alt="Intel Chipset Updater" src="https://github.com/user-attachments/assets/846c299c-3470-4d74-bd74-993936466a04" />

---
**Maintainer**: Marcin Grygiel / www.firstever.tech  
**Source**: https://github.com/FirstEver-eu/Intel-Chipset-Updater  
**VirusTotal Scan**: [Result 0/98](https://www.virustotal.com/gui/url/73be62d14c2a11ebd6322142d44fbd32d843182f3e9f6d5a3a5b6841c552c077) (Clean)



