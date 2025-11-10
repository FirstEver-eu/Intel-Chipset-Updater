# Intel Chipset Drivers Update Script
# Based on proven detection from Intel Chipset List
# Downloads latest drivers from GitHub and updates if newer versions available
# By Marcin Grygiel / www.firstever.tech

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges. Please run PowerShell as Administrator." -ForegroundColor Red
    exit
}

# GitHub repository URLs
$githubBaseUrl = "https://raw.githubusercontent.com/FirstEver-eu/Intel-Chipset-Updater/main/"
$chipsetDriversUrl = $githubBaseUrl + "chipset-drivers.txt"
$chipsetListUrl = $githubBaseUrl + "Intel_Chipsets_List.md"

# Temporary directory for downloads
$tempDir = "C:\Windows\Temp\IntelChipset"

# Function to get current driver version for a device
function Get-CurrentDriverVersion {
    param([string]$DeviceInstanceId)
    
    try {
        $device = Get-PnpDevice | Where-Object {$_.InstanceId -eq $deviceInstanceId}
        if ($device) {
            $versionProperty = $device | Get-PnpDeviceProperty -KeyName "DEVPKEY_Device_DriverVersion" -ErrorAction SilentlyContinue
            if ($versionProperty -and $versionProperty.Data) {
                return $versionProperty.Data
            }
        }
    } catch {
        # Fallback to WMI if the above fails
        try {
            $driverInfo = Get-CimInstance -ClassName Win32_PnPSignedDriver | Where-Object { 
                $_.DeviceID -eq $deviceInstanceId -and $_.DriverVersion
            } | Select-Object -First 1
            
            if ($driverInfo) {
                return $driverInfo.DriverVersion
            }
        } catch {
            # Ignore errors
        }
    }
    return $null
}

# Function to clean up temporary driver folders
function Clear-TempDriverFolders {
    try {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Ignore cleanup errors
    }
}

# Function to download and parse driver information from GitHub
function Get-LatestDriverInfo {
    param([string]$Url)
    
    try {
        $content = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        return $content.Content
    } catch {
        Write-Host "Error downloading driver information from GitHub." -ForegroundColor Red
        Write-Host "Please check your internet connection and try again." -ForegroundColor Yellow
        return $null
    }
}

# Function to parse chipset drivers information
function Parse-ChipsetDriverInfo {
    param([string]$DriverInfo)
    
    $drivers = @()
    $lines = $DriverInfo -split "`n" | ForEach-Object { $_.Trim() }
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq "Intel Chipset Device Software") {
            $driver = @{
                Name = $lines[$i]
                Version = $null
                DownloadUrl = $null
            }
            
            # Look for DriverVer in next lines
            for ($j = $i + 1; $j -lt [Math]::Min($i + 5, $lines.Count); $j++) {
                if ($lines[$j] -match 'DriverVer\s*=\s*[^,]+,([0-9.]+)') {
                    $driver.Version = $matches[1]
                } elseif ($lines[$j] -match '^https?://') {
                    $driver.DownloadUrl = $lines[$j]
                    break
                }
            }
            
            if ($driver.Version -and $driver.DownloadUrl) {
                $drivers += $driver
            }
        }
    }
    
    return $drivers
}

# Function to parse chipset list information
function Parse-ChipsetList {
    param([string]$ChipsetListInfo)
    
    $chipsetMap = @{}
    $lines = $ChipsetListInfo -split "`n" | ForEach-Object { $_.Trim() }
    $inTable = $false
    $headers = @()
    
    foreach ($line in $lines) {
        if ($line -match '^\|.*\|.*\|.*\|$' -and $line -notmatch '^\|\s*:---') {
            if (-not $inTable) {
                # This is the header row
                $headers = ($line -split '\|' | ForEach-Object { $_.Trim() }) | Where-Object { $_ }
                $inTable = $true
            } else {
                # This is a data row
                $columns = ($line -split '\|' | ForEach-Object { $_.Trim() }) | Where-Object { $_ }
                if ($columns.Count -ge 4) {
                    $hwId = $columns[0]
                    $platform = $columns[1]
                    $driverFile = $columns[2]
                    $maxVersion = $columns[3]
                    
                    $chipsetMap[$hwId] = @{
                        Platform = $platform
                        DriverFile = $driverFile
                        MaxVersion = $maxVersion
                        HasAsterisk = $maxVersion -match '\*$'
                    }
                }
            }
        } elseif ($line -match '^[^|]' -and $inTable) {
            # End of table
            $inTable = $false
        }
    }
    
    return $chipsetMap
}

# Function to download and extract file
function Download-Extract-File {
    param([string]$Url, [string]$OutputPath, [string]$Type)
    
    try {
        $tempFile = "$tempDir\temp_$(Get-Random)"
        
        # Download file
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing
        
        if (Test-Path $tempFile) {
            if ($Type -eq "ZIP") {
                # Extract ZIP file
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $OutputPath)
                    $success = $true
                } catch {
                    # Fallback to COM object
                    try {
                        $shell = New-Object -ComObject Shell.Application
                        $zipFolder = $shell.NameSpace($tempFile)
                        $destFolder = $shell.NameSpace($OutputPath)
                        $destFolder.CopyHere($zipFolder.Items(), 0x14) # 0x14 = No UI + Overwrite
                        $success = $true
                    } catch {
                        $success = $false
                    }
                }
            } else {
                # For EXE, just copy to output path
                New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
                Copy-Item $tempFile "$OutputPath\SetupChipset.exe" -Force
                $success = $true
            }
            
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $success
        }
    } catch {
        Write-Host "Error downloading or extracting driver package." -ForegroundColor Red
    }
    return $false
}

# Function to get appropriate driver for device
function Get-DriverForDevice {
    param([string]$DeviceHwId, [array]$AvailableDrivers, [hashtable]$ChipsetMap)
    
    # Find matching HW_ID in chipset map
    $matchingHwId = $ChipsetMap.Keys | Where-Object { 
        $deviceHwId -like "*$_*" -or $deviceHwId -eq $_
    } | Select-Object -First 1
    
    if ($matchingHwId) {
        $chipsetInfo = $ChipsetMap[$matchingHwId]
        $maxVersion = $chipsetInfo.MaxVersion -replace '\*$', ''
        
        # Find the best driver for this platform
        $bestDriver = $null
        
        # For X79 and X99 platforms - use exact version (10.1.2.19)
        if ($matchingHwId -eq "1E10" -or $matchingHwId -eq "8D50") {
            $bestDriver = $AvailableDrivers | Where-Object { $_.Version -eq $maxVersion } | Select-Object -First 1
            if ($bestDriver) {
                Write-Host "X79/X99 platform detected - using optimized driver $($bestDriver.Version)" -ForegroundColor Cyan
            }
        } else {
            # For other platforms: if max version > 10.1.2.19, use the latest driver
            if ([version]$maxVersion -gt [version]"10.1.2.19") {
                $bestDriver = $AvailableDrivers | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
            } else {
                # For older platforms, use exact version from the list
                $bestDriver = $AvailableDrivers | Where-Object { $_.Version -eq $maxVersion } | Select-Object -First 1
            }
        }
        
        # Fallback if exact version not found
        if (-not $bestDriver) {
            $bestDriver = $AvailableDrivers | Where-Object { [version]$_.Version -le [version]$maxVersion } | 
                Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
        }
        
        if ($bestDriver) {
            return @{
                Driver = $bestDriver
                ChipsetInfo = $chipsetInfo
                HwId = $matchingHwId
            }
        }
    }
    
    return $null
}

# Function to install chipset driver
function Install-ChipsetDriver {
    param([hashtable]$DriverInfo, [string]$DriverPath)
    
    $version = $DriverInfo.Driver.Version
    $setupPath = $null
    
    # Determine setup path based on version
    switch ($version) {
        "10.1.1.8" {
            $setupPath = Join-Path $DriverPath "SetupChipset.exe"
        }
        "10.1.2.19" {
            $setupPath = Join-Path $DriverPath "INFUpdate\Setup.exe"
        }
        "10.1.1.38" {
            $setupPath = Join-Path $DriverPath "INFUpdate\SetupChipset.exe"
        }
        default {
            # For newer versions (10.1.20266.8668 and above)
            if ($version -match "^10\.1\.[0-9]{5}") {
                $setupPath = Join-Path $DriverPath "SetupChipset.exe"
            } else {
                # Fallback
                $exeFiles = Get-ChildItem -Path $DriverPath -Filter "*.exe" -Recurse | Where-Object {
                    $_.Name -like "*Setup*" -or $_.Name -like "*Install*"
                }
                if ($exeFiles) {
                    $setupPath = $exeFiles[0].FullName
                }
            }
        }
    }
    
    if ($setupPath -and (Test-Path $setupPath)) {
        Write-Host "Running installer..." -ForegroundColor Cyan
        try {
            # Uruchom instalator z parametrami -S -OVERALL -downgrade -norestart
            $process = Start-Process -FilePath $setupPath -ArgumentList "-S -OVERALL -downgrade -norestart" -Wait -PassThru
            
            # Kod 3010 = SUCCESS - RESTART REQUIRED (to nie jest błąd!)
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                Write-Host "Driver installed successfully." -ForegroundColor Green
                return $true
            } else {
                Write-Host "Installer finished with exit code: $($process.ExitCode)" -ForegroundColor Red
                return $false
            }
            
        } catch {
            Write-Host "Error running installer: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Error: Installer not found" -ForegroundColor Red
        return $false
    }
}

Write-Host "=== Intel Chipset Drivers Update ===" -ForegroundColor Cyan
Write-Host "Downloading latest driver information..." -ForegroundColor Green

# Create temporary directory
Clear-TempDriverFolders
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Download latest driver information
$chipsetInfo = Get-LatestDriverInfo -Url $chipsetDriversUrl
$chipsetListInfo = Get-LatestDriverInfo -Url $chipsetListUrl

if (-not $chipsetInfo -or -not $chipsetListInfo) {
    Write-Host "Failed to download driver information. Exiting." -ForegroundColor Red
    Clear-TempDriverFolders
    exit
}

# Parse driver information
Write-Host "Parsing driver information..." -ForegroundColor Green
$availableDrivers = Parse-ChipsetDriverInfo -DriverInfo $chipsetInfo
$chipsetMap = Parse-ChipsetList -ChipsetListInfo $chipsetListInfo

if ($availableDrivers.Count -eq 0 -or $chipsetMap.Count -eq 0) {
    Write-Host "Error: Could not parse driver information." -ForegroundColor Red
    Clear-TempDriverFolders
    exit
}

$latestDriver = $availableDrivers | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
Write-Host "Intel Chipset Device Software: $($latestDriver.Version)" -ForegroundColor Yellow
Write-Host ""

# Find Intel Chipset devices
Write-Host "Scanning for Intel Platform..." -ForegroundColor Green

# Get all Intel devices (VEN_8086)
$intelDevices = Get-PnpDevice | Where-Object {
    $_.InstanceId -like "*VEN_8086*" -and $_.Class -eq "System" -and $_.Status -eq "OK"
}

$chipsetDevices = @()
$chipsetUpdateAvailable = $false

foreach ($device in $intelDevices) {
    $driverMatch = Get-DriverForDevice -DeviceHwId $device.InstanceId -AvailableDrivers $availableDrivers -ChipsetMap $chipsetMap
    if ($driverMatch) {
        $chipsetDevices += @{
            Device = $device
            DriverMatch = $driverMatch
        }
    }
}

if ($chipsetDevices.Count -eq 0) {
    Write-Host "No compatible Intel chipset platforms found." -ForegroundColor Yellow
} else {
    Write-Host "Found $($chipsetDevices.Count) Intel chipset platform(s):" -ForegroundColor Green
    
    foreach ($chipsetDevice in $chipsetDevices) {
        $device = $chipsetDevice.Device
        $driverMatch = $chipsetDevice.DriverMatch
        $currentVersion = Get-CurrentDriverVersion -DeviceInstanceId $device.InstanceId
        $platformVersion = $driverMatch.Driver.Version
        $platform = $driverMatch.ChipsetInfo.Platform
        
        Write-Host "`nPlatform: $platform" -ForegroundColor White
        Write-Host "Instance ID: $($device.InstanceId)" -ForegroundColor Gray
        
        if ($currentVersion) {
            Write-Host "Current Version: $currentVersion" -ForegroundColor Gray
            Write-Host "Platform Version: $platformVersion" -ForegroundColor Gray
            
            if ($currentVersion -eq $platformVersion) {
                Write-Host "Status: Already on latest version" -ForegroundColor Green
            } else {
                Write-Host "Status: Update available! ($currentVersion -> $platformVersion)" -ForegroundColor Yellow
                $chipsetUpdateAvailable = $true
            }
        } else {
            Write-Host "Current Version: Unable to determine" -ForegroundColor Gray
            Write-Host "Platform Version: $platformVersion" -ForegroundColor Gray
            Write-Host "Status: Will attempt to install driver" -ForegroundColor Yellow
            $chipsetUpdateAvailable = $true
        }
        
        # Show asterisk warning if needed
        if ($driverMatch.ChipsetInfo.HasAsterisk) {
            Write-Host "" -ForegroundColor Yellow
            Write-Host "* The version of the driver package provided on the ASUS website is not necessarily" -ForegroundColor Yellow
            Write-Host "  indicative of the version of the chipset drivers that will be installed in your" -ForegroundColor Yellow
            Write-Host "  operating system. It is recommended to verify the actual driver versions post-" -ForegroundColor Yellow
            Write-Host "  installation through the Device Manager." -ForegroundColor Yellow
        }
    }
}

# If all devices are up to date, ask if user wants to reinstall anyway
if ((-not $chipsetUpdateAvailable) -and ($chipsetDevices.Count -gt 0)) {
    Write-Host "`nAll platforms are up to date." -ForegroundColor Green
    $response = Read-Host "Do you want to force reinstall the driver anyway? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        $chipsetUpdateAvailable = $true
    } else {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        Clear-TempDriverFolders
        exit
    }
}

# Ask for update confirmation with important notice
if ($chipsetUpdateAvailable) {
    Write-Host ""
    Write-Host "IMPORTANT NOTICE:" -ForegroundColor Yellow
    Write-Host "The driver update process may take several minutes to complete." -ForegroundColor Yellow
    Write-Host "During installation, the screen may temporarily go black and some devices" -ForegroundColor Yellow
    Write-Host "may temporarily disconnect as PCIe bus drivers are being updated." -ForegroundColor Yellow
    Write-Host "This is normal behavior and the system will return to normal operation" -ForegroundColor Yellow
    Write-Host "once the installation is complete." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to proceed with driver update? (Y/N)"
} else {
    $response = "N"
}

if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "`nStarting driver update process in silent mode..." -ForegroundColor Green
    
    # Download and install drivers for each platform
    $successCount = 0
    
    foreach ($chipsetDevice in $chipsetDevices) {
        $device = $chipsetDevice.Device
        $driverMatch = $chipsetDevice.DriverMatch
        $driver = $driverMatch.Driver
        $platform = $driverMatch.ChipsetInfo.Platform
        
        Write-Host "`nUpdating $platform..." -ForegroundColor Cyan
        
        # Determine file type
        $fileType = if ($driver.DownloadUrl -match '\.zip$') { "ZIP" } else { "EXE" }
        $driverPath = "$tempDir\$($driver.Version)_$(Get-Random)"
        
        Write-Host "Downloading Intel Chipset Driver Software $($driver.Version)..." -ForegroundColor Green
        if (Download-Extract-File -Url $driver.DownloadUrl -OutputPath $driverPath -Type $fileType) {
            Write-Host "Driver downloaded successfully." -ForegroundColor Green
            
            if (Install-ChipsetDriver -DriverInfo $driverMatch -DriverPath $driverPath) {
                $successCount++
            } else {
                Write-Host "Failed to install driver." -ForegroundColor Red
            }
        } else {
            Write-Host "Failed to download driver." -ForegroundColor Red
        }
    }
    
    if ($successCount -gt 0) {
        Write-Host "`nIMPORTANT:" -ForegroundColor Yellow
        Write-Host "Computer restart is required to complete driver installation!" -ForegroundColor Yellow
        Write-Host "Please restart your computer as soon as possible." -ForegroundColor Yellow
    }
} else {
    Write-Host "Update cancelled." -ForegroundColor Yellow
}

# Clean up
Write-Host "`nCleaning up temporary files..." -ForegroundColor Gray
Clear-TempDriverFolders

Write-Host "`nDriver update process completed." -ForegroundColor Cyan
Write-Host "If you have any issues with this script, please report them at:"
Write-Host "https://github.com/FirstEver-eu/Intel-Chipset-Updater" -ForegroundColor Cyan