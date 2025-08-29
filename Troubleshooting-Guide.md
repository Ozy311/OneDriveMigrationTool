# OneDrive Migration Tool - Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting information for the OneDrive Migration Tool, including common issues, error messages, diagnostic steps, and solutions.

## Table of Contents

1. [Quick Diagnostic Steps](#quick-diagnostic-steps)
2. [Authentication Issues](#authentication-issues)
3. [Connection and Network Problems](#connection-and-network-problems)
4. [File Transfer Issues](#file-transfer-issues)
5. [PowerShell and Module Issues](#powershell-and-module-issues)
6. [Permission and Access Problems](#permission-and-access-problems)
7. [Performance and Timeout Issues](#performance-and-timeout-issues)
8. [Resume and Progress Tracking Issues](#resume-and-progress-tracking-issues)
9. [Error Codes Reference](#error-codes-reference)
10. [Diagnostic Commands](#diagnostic-commands)

## Quick Diagnostic Steps

### First Steps for Any Issue

1. **Run Help Command**
   ```powershell
   .\OneDriveMigration.ps1 -Help
   ```

2. **Validate Parameters**
   ```powershell
   # Test parameter validation
   .\OneDriveMigration.ps1 -Mode ValidateOnly -SourceTenant "your-tenant" -SourceAdminUpn "admin@yourtenant.com" -SourceUserUpn "user@yourtenant.com"
   ```

3. **Test with Dry Run**
   ```powershell
   .\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "your-tenant" -SourceAdminUpn "admin@yourtenant.com" -SourceUserUpn "user@yourtenant.com" -DryRun
   ```

4. **Check Prerequisites**
   ```powershell
   # PowerShell version
   $PSVersionTable.PSVersion
   
   # Available modules
   Get-Module -ListAvailable | Where-Object {$_.Name -like "*SharePoint*"}
   
   # Disk space
   Get-PSDrive C | Select-Object Used,Free,@{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}}
   ```

## Authentication Issues

### Issue: "The sign-in name or password does not match"

**Symptoms:**
- Authentication fails during connection
- Credential prompts keep appearing
- "Invalid credentials" errors

**Causes:**
- Incorrect username/password
- MFA/Conditional Access policies
- Account lockout or disabled
- Modern authentication requirements

**Solutions:**

1. **Verify Credentials**
   ```powershell
   # Test credentials manually
   $cred = Get-Credential
   Connect-SPOService -Url "https://yourtenant-admin.sharepoint.com" -Credential $cred
   ```

2. **Check Account Status**
   - Verify account is active in Azure AD
   - Check for account lockouts
   - Ensure SharePoint Online license is assigned

3. **Handle MFA/Conditional Access**
   ```powershell
   # Use interactive authentication
   Connect-PnPOnline -Url "https://yourtenant-my.sharepoint.com/personal/user" -UseWebLogin
   ```

4. **Modern Authentication Issues**
   ```powershell
   # Enable modern authentication
   Connect-SPOService -Url "https://yourtenant-admin.sharepoint.com" -Credential $cred -ModernAuth $true
   ```

### Issue: "Authentication cancelled by user"

**Symptoms:**
- Script exits after credential prompt
- "Authentication cancelled" message

**Solutions:**
1. **Ensure Credential Entry**
   - Don't cancel the credential dialog
   - Enter valid admin credentials
   - Use UPN format (user@domain.com)

2. **Pre-authenticate**
   ```powershell
   # Test credentials first
   $cred = Get-Credential -Message "Enter SharePoint admin credentials"
   Connect-SPOService -Url "https://yourtenant-admin.sharepoint.com" -Credential $cred
   ```

### Issue: Cached Credential Problems

**Symptoms:**
- Wrong credentials being reused
- Cannot change credentials
- Same tenant authentication issues

**Solutions:**
1. **Clear Credential Cache**
   ```powershell
   # Restart PowerShell session
   # Or modify the script's $Script:CachedCredentials variable
   ```

2. **Use Different PowerShell Session**
   ```powershell
   # Open new PowerShell window
   # Credentials are cached per session
   ```

## Connection and Network Problems

### Issue: "Connection timeout or network error"

**Symptoms:**
- Operations hang or timeout
- Network-related error messages
- Intermittent connection failures

**Solutions:**

1. **Test Network Connectivity**
   ```powershell
   # Test SharePoint URLs
   Test-NetConnection -ComputerName "yourtenant.sharepoint.com" -Port 443
   Test-NetConnection -ComputerName "yourtenant-admin.sharepoint.com" -Port 443
   Test-NetConnection -ComputerName "yourtenant-my.sharepoint.com" -Port 443
   ```

2. **Check Proxy Settings**
   ```powershell
   # Check proxy configuration
   netsh winhttp show proxy
   
   # Set proxy if needed
   netsh winhttp set proxy proxy-server:port
   ```

3. **Firewall and Security**
   - Ensure SharePoint Online URLs are accessible
   - Check corporate firewall rules
   - Verify SSL/TLS settings

4. **Use Concise Mode**
   ```powershell
   # Reduce network overhead
   .\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "tenant" -SourceAdminUpn "admin@tenant.com" -SourceUserUpn "user@tenant.com" -Concise
   ```

### Issue: "PnP connection failed"

**Symptoms:**
- PnP PowerShell connection errors
- "Unable to connect to OneDrive" messages
- Authentication works but PnP fails

**Solutions:**

1. **Try Interactive Authentication**
   ```powershell
   # The script automatically tries this fallback
   # Or test manually:
   Connect-PnPOnline -Url "https://yourtenant-my.sharepoint.com/personal/user" -UseWebLogin
   ```

2. **Update PnP Module**
   ```powershell
   # Uninstall old version
   Uninstall-Module SharePointPnPPowerShellOnline -Force
   
   # Install latest version
   Install-Module SharePointPnPPowerShellOnline -Force -SkipPublisherCheck
   ```

3. **Check OneDrive URL Format**
   ```powershell
   # Verify URL construction
   $userPath = "user@tenant.com".Replace('@', '_').Replace('.', '_')
   $oneDriveUrl = "https://tenant-my.sharepoint.com/personal/$userPath"
   Write-Host "OneDrive URL: $oneDriveUrl"
   ```

## File Transfer Issues

### Issue: "File exceeds SharePoint limit (>250MB)"

**Symptoms:**
- Large files logged as failures
- "File too large" warnings
- Files >250MB not transferring

**Expected Behavior:**
- This is a documented SharePoint REST API limitation
- Files are logged as failed but migration continues
- Most files (typically 796/799) transfer successfully

**Solutions:**

1. **Accept Limitation**
   - This is expected behavior for very large files
   - Review CSV logs to identify affected files
   - Use alternative methods for files >250MB

2. **Alternative Transfer Methods**
   ```powershell
   # Use SharePoint sync client for large files
   # Or OneDrive desktop app
   # Or SharePoint web interface for individual large files
   ```

3. **Identify Large Files**
   ```powershell
   # Review CSV log for failed large files
   Import-Csv "Migration_Log_*.csv" | Where-Object {$_.Status -eq "Failed" -and $_.Error -like "*250MB*"}
   ```

### Issue: "File integrity check failed"

**Symptoms:**
- Files fail verification after download
- "Size mismatch" or "Hash mismatch" errors
- Files appear corrupted

**Solutions:**

1. **Check Verification Level**
   ```powershell
   # Use Basic verification (size only)
   .\OneDriveMigration.ps1 -Mode DownloadOnly -VerificationLevel Basic
   
   # Or Enhanced verification (size + hash)
   .\OneDriveMigration.ps1 -Mode DownloadOnly -VerificationLevel Enhanced
   ```

2. **Retry Failed Files**
   ```powershell
   # Enable resume to retry failed files
   .\OneDriveMigration.ps1 -Mode DownloadOnly -EnableResume
   ```

3. **Check Disk Space**
   ```powershell
   # Ensure adequate disk space
   Get-PSDrive C | Select-Object Used,Free,@{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}}
   ```

### Issue: Files Not Uploading

**Symptoms:**
- Upload operations appear successful but files missing
- Conflict resolution issues
- User folder detection problems

**Solutions:**

1. **Check User Folder Detection**
   ```powershell
   # Verify archive folder structure
   Get-ChildItem "C:\Migration\Archive" -Directory
   
   # Use explicit folder specification
   .\OneDriveMigration.ps1 -Mode UploadOnly -UserArchiveFolder "john.doe"
   ```

2. **Verify Conflict Resolution**
   ```powershell
   # Check what conflict resolution is being used
   # Skip: Existing files are left unchanged
   # Overwrite: Existing files are replaced
   # Rename: New files get timestamp suffix
   
   .\OneDriveMigration.ps1 -Mode UploadOnly -ConflictResolution Overwrite
   ```

3. **Test Upload Manually**
   ```powershell
   # Test PnP upload functionality
   Connect-PnPOnline -Url "https://tenant-my.sharepoint.com/personal/user" -UseWebLogin
   Add-PnPFile -Path "C:\test\file.pdf" -Folder "Documents"
   ```

## PowerShell and Module Issues

### Issue: "Failed to install required modules"

**Symptoms:**
- Module installation errors
- "Access denied" during installation
- Module import failures

**Solutions:**

1. **Run as Administrator**
   ```powershell
   # Right-click PowerShell, "Run as Administrator"
   Install-Module Microsoft.Online.SharePoint.PowerShell -Force
   Install-Module SharePointPnPPowerShellOnline -Force -SkipPublisherCheck
   ```

2. **Install for Current User**
   ```powershell
   Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force
   Install-Module SharePointPnPPowerShellOnline -Scope CurrentUser -Force -SkipPublisherCheck
   ```

3. **Manual Module Installation**
   ```powershell
   # Check PowerShell Gallery connectivity
   Test-NetConnection -ComputerName "www.powershellgallery.com" -Port 443
   
   # Set execution policy
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   
   # Trust PowerShell Gallery
   Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
   ```

### Issue: PowerShell Version Compatibility

**Symptoms:**
- "PowerShell 7+" warning messages
- Unexpected behavior in PowerShell Core
- Module compatibility issues

**Solutions:**

1. **Use PowerShell 5.1**
   ```cmd
   # From Command Prompt or Run dialog
   powershell.exe -File "OneDriveMigration.ps1" -Mode DownloadOnly -SourceTenant "tenant"
   ```

2. **Suppress Version Warning**
   ```powershell
   # Add -Concise parameter to suppress warnings
   .\OneDriveMigration.ps1 -Mode DownloadOnly -Concise
   ```

3. **Check PowerShell Version**
   ```powershell
   $PSVersionTable.PSVersion
   # Should be 5.1 or higher
   ```

### Issue: Module Import Errors

**Symptoms:**
- "Module not found" errors
- Import-Module failures
- Cmdlet not recognized

**Solutions:**

1. **Check Module Installation**
   ```powershell
   Get-Module -ListAvailable -Name "Microsoft.Online.SharePoint.PowerShell"
   Get-Module -ListAvailable -Name "SharePointPnPPowerShellOnline"
   ```

2. **Force Module Import**
   ```powershell
   Import-Module Microsoft.Online.SharePoint.PowerShell -Force
   Import-Module SharePointPnPPowerShellOnline -Force
   ```

3. **Check Module Paths**
   ```powershell
   $env:PSModulePath -split ';'
   # Verify module installation paths
   ```

## Permission and Access Problems

### Issue: "Access denied" or "Insufficient permissions"

**Symptoms:**
- Permission denied errors
- Cannot access OneDrive
- Admin operations fail

**Solutions:**

1. **Verify SharePoint Admin Role**
   - Ensure admin account has SharePoint Administrator role
   - Check Global Administrator permissions if needed
   - Verify in Microsoft 365 Admin Center

2. **Check OneDrive Access**
   ```powershell
   # Verify admin can access user's OneDrive via web interface
   # Navigate to: https://tenant-my.sharepoint.com/personal/user_tenant_com
   ```

3. **Grant Site Collection Admin**
   ```powershell
   # The script does this automatically, but verify manually:
   $adminUrl = "https://tenant-admin.sharepoint.com"
   $oneDriveUrl = "https://tenant-my.sharepoint.com/personal/user_tenant_com"
   Connect-SPOService -Url $adminUrl -Credential $cred
   Set-SPOUser -Site $oneDriveUrl -LoginName "admin@tenant.com" -IsSiteCollectionAdmin $true
   ```

### Issue: "OneDrive not provisioned"

**Symptoms:**
- Cannot connect to user's OneDrive
- OneDrive URL returns 404
- User has no OneDrive

**Solutions:**

1. **Provision OneDrive**
   ```powershell
   # User must access OneDrive at least once
   # Or provision via PowerShell:
   Request-SPOPersonalSite -UserEmails "user@tenant.com"
   ```

2. **Wait for Provisioning**
   - OneDrive provisioning can take several minutes
   - Retry after waiting

3. **Check User License**
   - Verify user has SharePoint Online license
   - Check in Microsoft 365 Admin Center

## Performance and Timeout Issues

### Issue: Slow Performance or Timeouts

**Symptoms:**
- Very slow file transfers
- Operations timing out
- Poor progress indicators

**Solutions:**

1. **Use Concise Mode**
   ```powershell
   # Reduce console output overhead
   .\OneDriveMigration.ps1 -Mode DownloadOnly -Concise
   ```

2. **Check Network Performance**
   ```powershell
   # Test download speed
   Measure-Command { Invoke-WebRequest -Uri "https://yourtenant.sharepoint.com" -UseBasicParsing }
   ```

3. **Optimize Verification Level**
   ```powershell
   # Use Basic verification for better performance
   .\OneDriveMigration.ps1 -Mode DownloadOnly -VerificationLevel Basic
   ```

4. **Monitor System Resources**
   ```powershell
   # Check CPU and memory usage
   Get-Process PowerShell | Select-Object CPU,WorkingSet
   ```

### Issue: Enhanced Verification Slow

**Symptoms:**
- Very slow progress with Enhanced verification
- High CPU usage during hash calculation
- Long delays between files

**Solutions:**

1. **Use Basic Verification**
   ```powershell
   # Switch to size-only verification
   .\OneDriveMigration.ps1 -Mode DownloadOnly -VerificationLevel Basic
   ```

2. **Accept Performance Trade-off**
   - Enhanced verification provides cryptographic integrity
   - Consider importance vs. performance for your use case

3. **Monitor Progress**
   ```powershell
   # Hash calculation time varies by file size
   # Large files take significantly longer
   ```

## Resume and Progress Tracking Issues

### Issue: Resume Not Working

**Symptoms:**
- Files re-download despite EnableResume
- Progress file not found
- Resume starts from beginning

**Solutions:**

1. **Verify Resume Parameters**
   ```powershell
   # Ensure EnableResume is specified
   .\OneDriveMigration.ps1 -Mode DownloadOnly -EnableResume
   ```

2. **Check Progress File Location**
   ```powershell
   # Progress file should be in LocalArchivePath
   Get-ChildItem "Migration_Progress_*.json"
   ```

3. **Verify File Integrity**
   ```powershell
   # Corrupted progress files are recreated
   # Check for JSON syntax errors in progress file
   ```

### Issue: Progress File Corruption

**Symptoms:**
- "Could not read progress file" warnings
- Resume starts fresh despite previous progress
- JSON parsing errors

**Solutions:**

1. **Delete Corrupted Progress File**
   ```powershell
   # Remove corrupted file to start fresh
   Remove-Item "Migration_Progress_*.json"
   ```

2. **Backup Progress Files**
   ```powershell
   # Backup progress files for important migrations
   Copy-Item "Migration_Progress_*.json" "Progress_Backup.json"
   ```

## Error Codes Reference

### Common Error Patterns

| Error Pattern | Meaning | Solution |
|---------------|---------|----------|
| `Parameter validation failed` | Required parameters missing | Check parameter requirements for selected mode |
| `Prerequisites check failed` | System requirements not met | Install missing modules, check PowerShell version |
| `Authentication failed` | Credential or permission issues | Verify credentials, check admin permissions |
| `Connection timeout` | Network connectivity problems | Check internet connection, proxy settings |
| `File exceeds SharePoint limit` | File >250MB | Expected behavior, use alternative for large files |
| `Size mismatch` | File integrity check failed | Retry download, check disk space |
| `Hash mismatch` | Enhanced verification failed | Retry download, check file corruption |
| `Access denied` | Insufficient permissions | Verify admin role, check OneDrive access |
| `OneDrive not found` | User OneDrive not provisioned | Provision OneDrive, check user license |
| `Module not found` | PowerShell modules missing | Install required modules |

### CSV Log Status Codes

| Status | Description | Action Required |
|--------|-------------|-----------------|
| `Success` | Operation completed successfully | None |
| `Failed` | Operation failed with error | Review error details, retry if appropriate |
| `Skipped` | Item skipped (already exists, resume) | Normal behavior |
| `Warning` | Operation completed with warnings | Review warning details |

## Diagnostic Commands

### System Information
```powershell
# PowerShell version
$PSVersionTable

# Available disk space
Get-PSDrive | Where-Object {$_.Provider -like "*FileSystem*"} | Select-Object Name,Used,Free,@{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}}

# Network connectivity
Test-NetConnection -ComputerName "yourtenant.sharepoint.com" -Port 443
Test-NetConnection -ComputerName "yourtenant-admin.sharepoint.com" -Port 443
```

### Module Diagnostics
```powershell
# Check installed modules
Get-Module -ListAvailable | Where-Object {$_.Name -like "*SharePoint*"}

# Module versions
Get-Module -ListAvailable -Name "Microsoft.Online.SharePoint.PowerShell" | Select-Object Name,Version
Get-Module -ListAvailable -Name "SharePointPnPPowerShellOnline" | Select-Object Name,Version

# Import status
Get-Module | Where-Object {$_.Name -like "*SharePoint*"}
```

### Connection Testing
```powershell
# Test SharePoint Online connection
$cred = Get-Credential
Connect-SPOService -Url "https://yourtenant-admin.sharepoint.com" -Credential $cred

# Test PnP connection
Connect-PnPOnline -Url "https://yourtenant-my.sharepoint.com/personal/user_yourtenant_com" -Credentials $cred

# List OneDrive contents
Get-PnPListItem -List "Documents" | Select-Object -First 5
```

### Log Analysis
```powershell
# Review CSV logs
$logs = Import-Csv "Migration_Log_*.csv"

# Count by status
$logs | Group-Object Status | Select-Object Name,Count

# Failed operations
$logs | Where-Object {$_.Status -eq "Failed"} | Select-Object ItemName,Error

# Large file failures
$logs | Where-Object {$_.Status -eq "Failed" -and $_.Error -like "*250MB*"} | Select-Object ItemName,Size
```

### Progress File Analysis
```powershell
# Read progress file
$progress = Get-Content "Migration_Progress_*.json" | ConvertFrom-Json

# Session information
$progress | Select-Object sessionId,startTime,mode,verificationLevel

# File status summary
$progress.files.PSObject.Properties.Value | Group-Object status | Select-Object Name,Count

# Failed files
$progress.files.PSObject.Properties | Where-Object {$_.Value.status -eq "Failed"} | Select-Object Name,@{Name="Error";Expression={$_.Value.error}}
```

## Getting Additional Help

### Built-in Help
```powershell
# Comprehensive help
.\OneDriveMigration.ps1 -Help

# Parameter examples
.\OneDriveMigration.ps1 -Help | Select-String -Pattern "Example"
```

### Validation Mode Testing
```powershell
# Test source connection
.\OneDriveMigration.ps1 -Mode ValidateOnly -SourceTenant "tenant" -SourceAdminUpn "admin@tenant.com" -SourceUserUpn "user@tenant.com"

# Test destination connection
.\OneDriveMigration.ps1 -Mode ValidateOnly -DestTenant "tenant" -DestAdminUpn "admin@tenant.com" -DestUserUpn "user@tenant.com"
```

### Dry Run Testing
```powershell
# Preview download operations
.\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "tenant" -SourceAdminUpn "admin@tenant.com" -SourceUserUpn "user@tenant.com" -DryRun

# Preview upload operations
.\OneDriveMigration.ps1 -Mode UploadOnly -DestTenant "tenant" -DestAdminUpn "admin@tenant.com" -DestUserUpn "user@tenant.com" -LocalArchivePath "C:\Archive" -DryRun
```

---

**Note:** This troubleshooting guide covers common issues and solutions. For additional support, review the CSV audit logs for detailed error information and consider testing with ValidateOnly and DryRun modes before performing actual migrations.