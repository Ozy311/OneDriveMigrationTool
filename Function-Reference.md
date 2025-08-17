# OneDrive Migration Tool - Function Reference

## Quick Reference Guide

This document provides a concise reference for all public functions in the OneDrive Migration Tool. For detailed documentation, see [API-Documentation.md](API-Documentation.md).

## Table of Contents

- [Script Parameters](#script-parameters)
- [Core Functions](#core-functions)
- [Progress Tracking Functions](#progress-tracking-functions)
- [File Verification Functions](#file-verification-functions)
- [Operation Functions](#operation-functions)

## Script Parameters

### Basic Usage
```powershell
# Download only
.\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "user@contoso.com"

# Upload only
.\OneDriveMigration.ps1 -Mode UploadOnly -DestTenant "fabrikam" -DestAdminUpn "admin@fabrikam.com" -DestUserUpn "user@fabrikam.com" -LocalArchivePath "C:\Archive"

# Interactive (full migration)
.\OneDriveMigration.ps1 -Mode Interactive -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "user@contoso.com" -DestTenant "fabrikam" -DestAdminUpn "admin@fabrikam.com" -DestUserUpn "user@fabrikam.com"

# Validation only
.\OneDriveMigration.ps1 -Mode ValidateOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "user@contoso.com"
```

### Common Parameter Combinations
```powershell
# Enhanced verification with resume
-VerificationLevel Enhanced -EnableResume

# Quiet operation
-Concise -Yes

# Dry run for testing
-DryRun

# Custom paths and conflict resolution
-LocalArchivePath "C:\Migration" -ConflictResolution Rename -LogFile "C:\Logs\migration.csv"
```

## Core Functions

### Test-ParameterValidation
**Purpose:** Validates script parameters for the selected mode  
**Usage:** Called automatically, no direct invocation needed  
**Returns:** Exits script with error if validation fails

### Write-MigrationLog
**Syntax:**
```powershell
Write-MigrationLog -Message <String> [-Level <String>] [-Operation <String>] [-ItemType <String>] [-ItemName <String>] [-ItemPath <String>] [-Size <String>] [-Status <String>]
```

**Common Usage:**
```powershell
Write-MigrationLog "Starting operation..." -Level "Progress"
Write-MigrationLog "Operation completed" -Level "Success"
Write-MigrationLog "Warning message" -Level "Warning"
Write-MigrationLog "Error occurred" -Level "Error"

# With CSV logging
Write-MigrationLog "File processed" -Level "Info" -Operation "Download" -ItemType "File" -ItemName "document.pdf" -Status "Success" -Size "2.5MB"
```

### Test-Prerequisites
**Syntax:**
```powershell
Test-Prerequisites
```

**Usage:** Called automatically during script initialization  
**Behavior:** 
- Checks PowerShell version (≥5.1)
- Installs required modules if missing
- Validates disk space
- Exits script if critical prerequisites fail

### Get-MigrationCredentials
**Syntax:**
```powershell
Get-MigrationCredentials -TenantName <String> -Purpose <String>
```

**Examples:**
```powershell
$sourceCreds = Get-MigrationCredentials -TenantName "contoso" -Purpose "Source"
$destCreds = Get-MigrationCredentials -TenantName "fabrikam" -Purpose "Destination"

# Credentials are cached - same tenant reuses credentials
$sameCreds = Get-MigrationCredentials -TenantName "contoso" -Purpose "Destination"  # Returns cached
```

## Progress Tracking Functions

### Initialize-ProgressTracking
**Syntax:**
```powershell
Initialize-ProgressTracking
```

**Usage:** Called automatically when `-EnableResume` is used  
**Creates:** `Migration_Progress_{SessionId}.json` file  
**Prerequisites:** `$EnableResume = $true`, not in DryRun mode

### Get-ProgressData
**Syntax:**
```powershell
$progressData = Get-ProgressData
```

**Return Structure:**
```powershell
@{
    sessionId = "20231201_143022"
    startTime = "2023-12-01T14:30:22.123Z"
    verificationLevel = "Basic"
    mode = "DownloadOnly"
    files = @{
        "/path/to/file.pdf" = @{
            status = "Completed"
            sourceSize = 1048576
            localPath = "C:\Migration\file.pdf"
            # ... additional metadata
        }
    }
}
```

### Update-ProgressData
**Syntax:**
```powershell
Update-ProgressData -FilePath <String> -Status <String> [-SourceSize <Long>] [-SourceModified <DateTime>] [-LocalPath <String>] [-Hash <String>] [-ErrorMessage <String>]
```

**Examples:**
```powershell
# Success
Update-ProgressData -FilePath "/Documents/file.pdf" -Status "Completed" -SourceSize 1048576 -LocalPath "C:\Migration\file.pdf"

# Failure
Update-ProgressData -FilePath "/Documents/largefile.zip" -Status "Failed" -ErrorMessage "File exceeds 250MB limit"

# With hash (Enhanced verification)
Update-ProgressData -FilePath "/Documents/secure.pdf" -Status "Completed" -Hash "abc123def456..."
```

## File Verification Functions

### Test-FileIntegrity
**Syntax:**
```powershell
$result = Test-FileIntegrity -LocalFilePath <String> -ExpectedSize <Long> -ExpectedModified <DateTime> [-ExpectedHash <String>]
```

**Examples:**
```powershell
# Basic verification (size only)
$result = Test-FileIntegrity -LocalFilePath "C:\temp\file.pdf" -ExpectedSize 1048576 -ExpectedModified (Get-Date)

# Enhanced verification (size + hash)
$result = Test-FileIntegrity -LocalFilePath "C:\temp\file.pdf" -ExpectedSize 1048576 -ExpectedModified (Get-Date) -ExpectedHash "abc123..."

# Check result
if ($result.IsValid) {
    Write-Host "File integrity verified: $($result.Reason)"
} else {
    Write-Host "Integrity check failed: $($result.Reason)"
}
```

### Get-FileVerificationHash
**Syntax:**
```powershell
$hash = Get-FileVerificationHash -FilePath <String>
```

**Examples:**
```powershell
$hash = Get-FileVerificationHash -FilePath "C:\temp\document.pdf"
if ($hash) {
    Write-Host "SHA256: $hash"
} else {
    Write-Host "Hash calculation skipped (Basic mode or file not found)"
}
```

### Get-AtomicTempPath
**Syntax:**
```powershell
$tempPath = Get-AtomicTempPath -FinalPath <String>
```

**Example:**
```powershell
$finalPath = "C:\Migration\Documents\report.pdf"
$tempPath = Get-AtomicTempPath -FinalPath $finalPath
# Returns: "C:\Migration\Documents\report.pdf.tmp.1234"

# Atomic operation pattern
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath
$verification = Test-FileIntegrity -LocalFilePath $tempPath -ExpectedSize $expectedSize
if ($verification.IsValid) {
    Move-Item -Path $tempPath -Destination $finalPath
}
```

## Operation Functions

### Invoke-EnhancedValidation
**Syntax:**
```powershell
$result = Invoke-EnhancedValidation -Tenant <String> -AdminUpn <String> -UserUpn <String> -Purpose <String>
```

**Examples:**
```powershell
# Validate source tenant
$sourceValidation = Invoke-EnhancedValidation -Tenant "contoso" -AdminUpn "admin@contoso.com" -UserUpn "user@contoso.com" -Purpose "Source"

if ($sourceValidation.Success) {
    Write-Host "Source validation successful"
    Write-Host "OneDrive URL: $($sourceValidation.OneDriveUrl)"
    Write-Host "File count: $($sourceValidation.FileCount)"
} else {
    Write-Host "Source validation failed: $($sourceValidation.Error)"
}

# Validate destination tenant
$destValidation = Invoke-EnhancedValidation -Tenant "fabrikam" -AdminUpn "admin@fabrikam.com" -UserUpn "user@fabrikam.com" -Purpose "Destination"
```

### Invoke-EnhancedDownload
**Syntax:**
```powershell
$result = Invoke-EnhancedDownload -Tenant <String> -AdminUpn <String> -UserUpn <String> -LocalPath <String> [-PreAuthCredentials <PSCredential>]
```

**Examples:**
```powershell
# Basic download
$downloadResult = Invoke-EnhancedDownload -Tenant "contoso" -AdminUpn "admin@contoso.com" -UserUpn "user@contoso.com" -LocalPath "C:\Migration"

# Download with pre-authenticated credentials
$creds = Get-MigrationCredentials -TenantName "contoso" -Purpose "Source"
$downloadResult = Invoke-EnhancedDownload -Tenant "contoso" -AdminUpn "admin@contoso.com" -UserUpn "user@contoso.com" -LocalPath "C:\Migration" -PreAuthCredentials $creds

# Check results
if ($downloadResult.Success) {
    Write-Host "Download completed successfully"
    Write-Host "Files processed: $($downloadResult.FilesProcessed)"
    Write-Host "Files downloaded: $($downloadResult.FilesDownloaded)"
    Write-Host "Files failed: $($downloadResult.FilesFailed)"
    if ($downloadResult.FilesResumed -gt 0) {
        Write-Host "Files resumed: $($downloadResult.FilesResumed)"
    }
} else {
    Write-Host "Download failed"
}
```

### Invoke-EnhancedUpload
**Syntax:**
```powershell
$result = Invoke-EnhancedUpload -Tenant <String> -AdminUpn <String> -UserUpn <String> -LocalPath <String> [-ConflictResolution <String>] [-SourceUserUpnForMapping <String>] [-UserArchiveFolderOverride <String>] [-PreAuthCredentials <PSCredential>]
```

**Examples:**
```powershell
# Basic upload
$uploadResult = Invoke-EnhancedUpload -Tenant "fabrikam" -AdminUpn "admin@fabrikam.com" -UserUpn "user@fabrikam.com" -LocalPath "C:\Migration"

# Upload with conflict resolution
$uploadResult = Invoke-EnhancedUpload -Tenant "fabrikam" -AdminUpn "admin@fabrikam.com" -UserUpn "user@fabrikam.com" -LocalPath "C:\Migration" -ConflictResolution "Rename"

# Upload with user mapping (different source/destination usernames)
$uploadResult = Invoke-EnhancedUpload -Tenant "fabrikam" -AdminUpn "admin@fabrikam.com" -UserUpn "john.smith@fabrikam.com" -LocalPath "C:\Migration" -SourceUserUpnForMapping "john.doe@contoso.com"

# Upload with explicit folder selection
$uploadResult = Invoke-EnhancedUpload -Tenant "fabrikam" -AdminUpn "admin@fabrikam.com" -UserUpn "user@fabrikam.com" -LocalPath "C:\Migration" -UserArchiveFolderOverride "john.doe"

# Check results
if ($uploadResult.Success) {
    Write-Host "Upload completed successfully"
    Write-Host "Files uploaded: $($uploadResult.FilesUploaded)"
    Write-Host "Files skipped: $($uploadResult.FilesSkipped)"
    Write-Host "Files failed: $($uploadResult.FilesFailed)"
    Write-Host "User folder: $($uploadResult.UserLocalPath)"
} else {
    Write-Host "Upload failed"
}
```

## Common Patterns and Best Practices

### Error Handling Pattern
```powershell
$result = Invoke-SomeFunction -Parameters "values"
if ($result.Success) {
    # Handle success
    Write-Host "Operation successful"
    # Process result data
} else {
    # Handle failure
    Write-Host "Operation failed: $($result.Error)"
    # Log error, exit, or retry
}
```

### Progress Tracking Pattern
```powershell
# Enable resume capability
$EnableResume = $true
Initialize-ProgressTracking

# During file operations
foreach ($file in $files) {
    try {
        # Process file
        Update-ProgressData -FilePath $file.Path -Status "Completed" -SourceSize $file.Size -LocalPath $localPath
    } catch {
        Update-ProgressData -FilePath $file.Path -Status "Failed" -ErrorMessage $_.Exception.Message
    }
}
```

### Atomic File Operations Pattern
```powershell
$finalPath = "C:\Migration\file.pdf"
$tempPath = Get-AtomicTempPath -FinalPath $finalPath

try {
    # Download to temporary location
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath
    
    # Verify integrity
    $verification = Test-FileIntegrity -LocalFilePath $tempPath -ExpectedSize $expectedSize
    
    if ($verification.IsValid) {
        # Atomically move to final location
        Move-Item -Path $tempPath -Destination $finalPath
        Write-MigrationLog "File downloaded successfully" -Level "Success"
    } else {
        throw "File integrity check failed: $($verification.Reason)"
    }
} catch {
    # Clean up temp file on failure
    if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
    Write-MigrationLog "File download failed: $($_.Exception.Message)" -Level "Error"
}
```

### Credential Management Pattern
```powershell
# Get credentials once, reuse for multiple operations
$sourceCreds = Get-MigrationCredentials -TenantName "contoso" -Purpose "Source"
$destCreds = Get-MigrationCredentials -TenantName "fabrikam" -Purpose "Destination"

# Use pre-authenticated credentials to avoid re-prompting
$downloadResult = Invoke-EnhancedDownload -Tenant "contoso" -AdminUpn $SourceAdminUpn -UserUpn $SourceUserUpn -LocalPath $LocalPath -PreAuthCredentials $sourceCreds

$uploadResult = Invoke-EnhancedUpload -Tenant "fabrikam" -AdminUpn $DestAdminUpn -UserUpn $DestUserUpn -LocalPath $LocalPath -PreAuthCredentials $destCreds
```

### Validation Before Operations Pattern
```powershell
# Always validate before performing operations
$sourceValidation = Invoke-EnhancedValidation -Tenant $SourceTenant -AdminUpn $SourceAdminUpn -UserUpn $SourceUserUpn -Purpose "Source"

if (-not $sourceValidation.Success) {
    Write-Host "Source validation failed: $($sourceValidation.Error)"
    exit 1
}

Write-Host "Source validation successful: $($sourceValidation.FileCount) files found"

# Proceed with download
$downloadResult = Invoke-EnhancedDownload -Tenant $SourceTenant -AdminUpn $SourceAdminUpn -UserUpn $SourceUserUpn -LocalPath $LocalPath -PreAuthCredentials $sourceValidation.Credential
```

## Return Value Quick Reference

### Standard Success Response
```powershell
@{
    Success = $true
    # Function-specific properties...
}
```

### Standard Failure Response
```powershell
@{
    Success = $false
    Error = "Detailed error message"
}
```

### Validation Function Returns
```powershell
# Success
@{
    Success = $true
    AdminUrl = "https://tenant-admin.sharepoint.com"
    OneDriveUrl = "https://tenant-my.sharepoint.com/personal/user"
    ItemCount = 150
    FileCount = 120
    Credential = [PSCredential]
}
```

### Download Function Returns
```powershell
@{
    Success = $true
    FilesProcessed = 150
    FilesDownloaded = 145
    FilesSkipped = 3
    FilesFailed = 2
    FilesResumed = 8
    UserLocalPath = "C:\Migration\username"
}
```

### Upload Function Returns
```powershell
@{
    Success = $true
    FilesUploaded = 45
    FilesSkipped = 3
    FilesFailed = 2
    ConflictResolution = "Skip"
    UserLocalPath = "C:\Migration\username"
}
```

### File Integrity Returns
```powershell
# Valid file
@{ IsValid = $true; Reason = "All verifications passed" }

# Invalid file
@{ IsValid = $false; Reason = "Size mismatch: Expected 1048576, got 1048000" }
```

---

**Note:** This reference guide provides syntax and common usage patterns. For comprehensive documentation including detailed parameter descriptions, behavior explanations, and advanced scenarios, refer to [API-Documentation.md](API-Documentation.md).