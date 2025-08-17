# OneDrive Migration Tool - API Documentation

## Overview

The OneDrive Migration Tool is a comprehensive PowerShell solution for enterprise-grade OneDrive tenant-to-tenant migrations. This document provides detailed technical documentation for all public APIs, functions, and components.

## Table of Contents

1. [Script Parameters](#script-parameters)
2. [Core Functions](#core-functions)
3. [Progress Tracking Functions](#progress-tracking-functions)
4. [File Verification Functions](#file-verification-functions)
5. [Operation Functions](#operation-functions)
6. [Return Values and Error Handling](#return-values-and-error-handling)
7. [Usage Examples](#usage-examples)
8. [Architecture Overview](#architecture-overview)

## Script Parameters

### Required Parameters (Mode-Dependent)

#### Mode Selection
```powershell
-Mode <String>
```
**Description:** Specifies the operation mode for the migration tool.  
**Valid Values:** `Interactive`, `DownloadOnly`, `UploadOnly`, `ValidateOnly`, `Automated`  
**Default:** `Interactive`

**Mode Requirements:**
- **Interactive:** Requires both source and destination parameters
- **DownloadOnly:** Requires source parameters only
- **UploadOnly:** Requires destination parameters and LocalArchivePath
- **ValidateOnly:** Requires either source or destination parameters (or both)
- **Automated:** Requires both source and destination parameters

#### Source Tenant Parameters
```powershell
-SourceTenant <String>
-SourceAdminUpn <String>
-SourceUserUpn <String>
```
**Description:** Parameters for connecting to the source OneDrive tenant.
- `SourceTenant`: The tenant name (e.g., "contoso" for contoso.sharepoint.com)
- `SourceAdminUpn`: SharePoint Online admin account with permissions
- `SourceUserUpn`: The user whose OneDrive will be migrated

**Required For:** Interactive, DownloadOnly, Automated modes

#### Destination Tenant Parameters
```powershell
-DestTenant <String>
-DestAdminUpn <String>
-DestUserUpn <String>
```
**Description:** Parameters for connecting to the destination OneDrive tenant.
- `DestTenant`: The destination tenant name
- `DestAdminUpn`: SharePoint Online admin account with permissions
- `DestUserUpn`: The destination user account

**Required For:** Interactive, UploadOnly, Automated modes

### Optional Parameters

#### Archive and Path Management
```powershell
-LocalArchivePath <String>
```
**Description:** Local filesystem path for storing downloaded files.  
**Default:** `.\Migration_yyyyMMdd_HHmmss`  
**Example:** `C:\Migration\JohnDoe-Archive`

```powershell
-UserArchiveFolder <String>
```
**Description:** Specific user folder name within the archive (for UploadOnly mode).  
**Use Case:** When source and destination usernames differ  
**Example:** `john.doe` (looks for folder named "john.doe" in LocalArchivePath)

#### Conflict Resolution
```powershell
-ConflictResolution <String>
```
**Description:** How to handle existing files during upload operations.  
**Valid Values:** `Skip`, `Overwrite`, `Rename`  
**Default:** `Skip`

- **Skip:** Leave existing files unchanged, skip upload
- **Overwrite:** Replace existing files with migrated versions
- **Rename:** Create new files with timestamp suffix

#### File Verification
```powershell
-VerificationLevel <String>
```
**Description:** Level of file integrity verification to perform.  
**Valid Values:** `Basic`, `Enhanced`  
**Default:** `Basic`

- **Basic:** File size comparison only
- **Enhanced:** File size + SHA256 hash verification

#### Resume and Progress
```powershell
-EnableResume
```
**Description:** Enable atomic download operations with resume capability.  
**Type:** Switch parameter  
**Behavior:** Creates progress tracking files for interrupted transfer recovery

#### Logging and Output
```powershell
-LogFile <String>
```
**Description:** Custom path for CSV audit log file.  
**Default:** `{LocalArchivePath}\Migration_Log_yyyyMMdd_HHmmss.csv`

```powershell
-Concise
```
**Description:** Reduce verbose console output (errors and warnings still shown).  
**Type:** Switch parameter

```powershell
-DryRun
```
**Description:** Preview operations without executing actual file transfers.  
**Type:** Switch parameter

#### Automation
```powershell
-Yes
```
**Description:** Skip all confirmation prompts for automated execution.  
**Type:** Switch parameter  
**Required For:** Automated mode

```powershell
-Help
```
**Description:** Display comprehensive help information.  
**Type:** Switch parameter

## Core Functions

### Test-ParameterValidation

**Purpose:** Validates script parameters based on the selected operation mode.

**Syntax:**
```powershell
function Test-ParameterValidation
```

**Parameters:** None (accesses script-level parameters)

**Behavior:**
- Validates required parameters for each mode
- Checks parameter combinations for consistency
- Exits with error code 1 if validation fails
- Provides detailed error messages for missing parameters

**Validation Rules:**
- **ValidateOnly:** Requires either source OR destination parameters
- **DownloadOnly:** Requires all source parameters
- **UploadOnly:** Requires all destination parameters + LocalArchivePath
- **Interactive/Automated:** Requires all source AND destination parameters

**Example Output:**
```
Parameter validation failed:
  - SourceTenant is required for DownloadOnly mode
  - SourceAdminUpn is required for DownloadOnly mode
Use -Help for parameter examples
```

### Write-MigrationLog

**Purpose:** Centralized logging function for console output and CSV audit trails.

**Syntax:**
```powershell
Write-MigrationLog -Message <String> [-Level <String>] [-Operation <String>] [-ItemType <String>] [-ItemName <String>] [-ItemPath <String>] [-Size <String>] [-Status <String>]
```

**Parameters:**
- `Message` (String, Required): The log message to display
- `Level` (String, Optional): Log level - `Info`, `Warning`, `Error`, `Success`, `Progress`
- `Operation` (String, Optional): Operation type for CSV logging
- `ItemType` (String, Optional): Type of item being processed
- `ItemName` (String, Optional): Name of the item
- `ItemPath` (String, Optional): Full path of the item
- `Size` (String, Optional): File size information
- `Status` (String, Optional): Operation status

**Behavior:**
- Console output with color coding based on log level
- Respects `-Concise` parameter (only shows warnings/errors/success)
- Writes structured CSV entries when operation details provided
- Escapes special characters for CSV compatibility

**Console Colors:**
- Info: White
- Warning: Yellow  
- Error: Red
- Success: Green
- Progress: Cyan

**CSV Format:**
```
Timestamp,SessionId,Operation,ItemType,ItemName,ItemPath,Status,Size,Error
```

**Example Usage:**
```powershell
Write-MigrationLog "Starting validation..." -Level "Progress"
Write-MigrationLog "File downloaded successfully" -Level "Success" -Operation "Download" -ItemType "File" -ItemName "document.pdf" -ItemPath "/Documents/document.pdf" -Status "Success" -Size "2.5MB"
```

### Test-Prerequisites

**Purpose:** Validates system requirements and installs necessary PowerShell modules.

**Syntax:**
```powershell
function Test-Prerequisites
```

**Parameters:** None

**Prerequisites Checked:**
1. **PowerShell Version:** Minimum 5.1 required
2. **Required Modules:**
   - `Microsoft.Online.SharePoint.PowerShell`
   - `SharePointPnPPowerShellOnline`
3. **Disk Space:** Warns if less than 5GB available
4. **Module Installation:** Auto-installs missing modules (unless DryRun)

**Behavior:**
- Exits with error code 1 if critical prerequisites fail
- Auto-installs missing modules with appropriate flags
- Provides disk space warnings for download operations
- Imports modules after successful installation

**DryRun Behavior:**
- Reports what modules would be installed
- Skips actual installation and import operations

**Example Output:**
```
[INFO] Checking system prerequisites...
[WARN] Installing required module: SharePointPnPPowerShellOnline
[OK] Prerequisites check passed
[OK] PowerShell modules imported successfully
```

### Get-MigrationCredentials

**Purpose:** Manages authentication credentials with caching for same-tenant scenarios.

**Syntax:**
```powershell
Get-MigrationCredentials -TenantName <String> -Purpose <String>
```

**Parameters:**
- `TenantName` (String, Required): The tenant name for credential caching
- `Purpose` (String, Required): "Source" or "Destination" for logging purposes

**Return Value:** `System.Management.Automation.PSCredential` object or `$null`

**Behavior:**
- Prompts user for credentials using `Get-Credential`
- Caches credentials by tenant name to avoid duplicate prompts
- Returns cached credentials for same-tenant scenarios
- Returns `$null` in DryRun mode

**Caching Logic:**
- Credentials stored in `$Script:CachedCredentials` hashtable
- Key: TenantName, Value: PSCredential object
- Enables single authentication for source/destination same tenant

**Example Usage:**
```powershell
$creds = Get-MigrationCredentials -TenantName "contoso" -Purpose "Source"
if ($creds) {
    Connect-SPOService -Url $adminUrl -Credential $creds
}
```

## Progress Tracking Functions

### Initialize-ProgressTracking

**Purpose:** Sets up resume capability by creating progress tracking files.

**Syntax:**
```powershell
function Initialize-ProgressTracking
```

**Parameters:** None (uses script-level variables)

**Prerequisites:**
- `$EnableResume` must be `$true`
- `$Script:ProgressFile` must be set
- Not executed in DryRun mode

**Behavior:**
- Creates JSON progress file if it doesn't exist
- Initializes with session metadata and empty files collection
- Logs existing progress file detection for resume scenarios

**Progress File Structure:**
```json
{
  "sessionId": "20231201_143022",
  "startTime": "2023-12-01T14:30:22.123Z",
  "verificationLevel": "Basic",
  "mode": "DownloadOnly",
  "files": {}
}
```

**File Location:** `{LocalArchivePath}/Migration_Progress_{SessionId}.json`

### Get-ProgressData

**Purpose:** Reads and parses existing progress tracking data.

**Syntax:**
```powershell
function Get-ProgressData
```

**Parameters:** None

**Return Value:** Hashtable with progress data structure

**Behavior:**
- Returns empty structure if resume disabled or DryRun mode
- Parses existing JSON progress file
- Converts PSCustomObject to hashtable for easier manipulation
- Handles corrupted progress files gracefully

**Return Structure:**
```powershell
@{
    sessionId = "20231201_143022"
    startTime = "2023-12-01T14:30:22.123Z"
    verificationLevel = "Basic"
    mode = "DownloadOnly"
    files = @{
        "/Documents/file1.pdf" = @{
            status = "Completed"
            sourceSize = 1048576
            sourceModified = "2023-11-15T10:30:00Z"
            localPath = "C:\Migration\user\Documents\file1.pdf"
            lastAttempt = "2023-12-01T14:35:15Z"
            verificationLevel = "Basic"
        }
    }
}
```

**Error Handling:**
- Returns default empty structure on JSON parse errors
- Logs warnings for corrupted progress files
- Ensures files property exists and is properly typed

### Update-ProgressData

**Purpose:** Updates progress tracking with file operation results.

**Syntax:**
```powershell
Update-ProgressData -FilePath <String> -Status <String> [-SourceSize <Long>] [-SourceModified <DateTime>] [-LocalPath <String>] [-Hash <String>] [-ErrorMessage <String>]
```

**Parameters:**
- `FilePath` (String, Required): SharePoint file path (used as unique key)
- `Status` (String, Required): Operation status ("Completed", "Failed", "Skipped")
- `SourceSize` (Long, Optional): Original file size in bytes
- `SourceModified` (DateTime, Optional): Source file modification date
- `LocalPath` (String, Optional): Local filesystem path where file was saved
- `Hash` (String, Optional): SHA256 hash for Enhanced verification
- `ErrorMessage` (String, Optional): Error details for failed operations

**Behavior:**
- Updates in-memory progress data structure
- Writes updated JSON to progress file
- Includes timestamp of last attempt
- Preserves verification level used

**File Entry Structure:**
```json
{
  "status": "Completed",
  "sourceSize": 1048576,
  "sourceModified": "2023-11-15T10:30:00Z",
  "localPath": "C:\\Migration\\user\\Documents\\file1.pdf",
  "lastAttempt": "2023-12-01T14:35:15Z",
  "verificationLevel": "Enhanced",
  "hash": "abc123def456...",
  "error": "File too large (>250MB limit)"
}
```

**Error Handling:**
- Logs warnings if progress file update fails
- Continues operation even if progress tracking fails
- Handles JSON serialization errors gracefully

## File Verification Functions

### Test-FileIntegrity

**Purpose:** Verifies downloaded file integrity against source file metadata.

**Syntax:**
```powershell
Test-FileIntegrity -LocalFilePath <String> -ExpectedSize <Long> -ExpectedModified <DateTime> [-ExpectedHash <String>]
```

**Parameters:**
- `LocalFilePath` (String, Required): Path to local file to verify
- `ExpectedSize` (Long, Required): Expected file size in bytes
- `ExpectedModified` (DateTime, Required): Expected modification date (not used in verification)
- `ExpectedHash` (String, Optional): Expected SHA256 hash for Enhanced verification

**Return Value:** Hashtable with verification results
```powershell
@{
    IsValid = $true/$false
    Reason = "Description of verification result"
}
```

**Verification Levels:**
- **Basic:** File size comparison only
- **Enhanced:** File size + SHA256 hash comparison

**Important Notes:**
- SharePoint downloads do NOT preserve original modification dates
- Modified date verification is skipped (documented limitation)
- File size is the primary integrity check for Basic mode
- Hash verification provides cryptographic integrity for Enhanced mode

**Return Examples:**
```powershell
# Success
@{ IsValid = $true; Reason = "All verifications passed" }

# Size mismatch
@{ IsValid = $false; Reason = "Size mismatch: Expected 1048576, got 1048000" }

# Hash mismatch (Enhanced mode)
@{ IsValid = $false; Reason = "Hash mismatch" }

# File not found
@{ IsValid = $false; Reason = "File not found" }
```

### Get-FileVerificationHash

**Purpose:** Calculates SHA256 hash for Enhanced verification mode.

**Syntax:**
```powershell
Get-FileVerificationHash -FilePath <String>
```

**Parameters:**
- `FilePath` (String, Required): Path to file for hash calculation

**Return Value:** String containing SHA256 hash or empty string

**Behavior:**
- Only calculates hash if `$VerificationLevel -eq "Enhanced"`
- Returns empty string for Basic verification mode
- Returns empty string if file doesn't exist
- Logs warnings for hash calculation failures

**Performance Considerations:**
- Hash calculation is CPU and I/O intensive
- Large files may take significant time to process
- Consider implications for very large file migrations

**Example Usage:**
```powershell
$hash = Get-FileVerificationHash -FilePath "C:\temp\document.pdf"
if ($hash) {
    Write-Host "File hash: $hash"
}
```

### Get-AtomicTempPath

**Purpose:** Generates temporary file paths for atomic download operations.

**Syntax:**
```powershell
Get-AtomicTempPath -FinalPath <String>
```

**Parameters:**
- `FinalPath` (String, Required): The intended final file path

**Return Value:** String with temporary file path

**Behavior:**
- Appends `.tmp.$PID` to the final path
- Uses process ID to ensure uniqueness across concurrent operations
- Enables atomic file operations (download to temp, rename when complete)

**Atomic Operation Pattern:**
1. Download file to temporary path
2. Verify file integrity
3. Rename temporary file to final path
4. Update progress tracking

**Example:**
```powershell
$finalPath = "C:\Migration\Documents\report.pdf"
$tempPath = Get-AtomicTempPath -FinalPath $finalPath
# Returns: "C:\Migration\Documents\report.pdf.tmp.1234"
```

## Operation Functions

### Invoke-EnhancedValidation

**Purpose:** Validates tenant connections, permissions, and OneDrive access.

**Syntax:**
```powershell
Invoke-EnhancedValidation -Tenant <String> -AdminUpn <String> -UserUpn <String> -Purpose <String>
```

**Parameters:**
- `Tenant` (String, Required): Tenant name (e.g., "contoso")
- `AdminUpn` (String, Required): SharePoint Online admin account
- `UserUpn` (String, Required): User account to validate
- `Purpose` (String, Required): "Source" or "Destination" for logging

**Return Value:** Hashtable with validation results

**Success Return Structure:**
```powershell
@{
    Success = $true
    AdminUrl = "https://contoso-admin.sharepoint.com"
    OneDriveUrl = "https://contoso-my.sharepoint.com/personal/user_contoso_com"
    ItemCount = 150
    FileCount = 120
    Credential = [PSCredential object]
}
```

**Failure Return Structure:**
```powershell
@{
    Success = $false
    Error = "Authentication failed: Invalid credentials"
}
```

**Validation Steps:**
1. **Admin Connection:** Connect to SharePoint Online Admin Center
2. **Permission Grant:** Set admin as site collection administrator
3. **PnP Connection:** Connect to user's OneDrive using PnP PowerShell
4. **Access Test:** Enumerate Documents library items
5. **Item Count:** Count total items and files

**Authentication Fallbacks:**
1. Try credential-based authentication first
2. Fall back to interactive web authentication if needed
3. Handle modern authentication requirements

**DryRun Behavior:**
- Returns success with placeholder data
- Logs intended validation steps
- Does not perform actual connections

**Example Usage:**
```powershell
$result = Invoke-EnhancedValidation -Tenant "contoso" -AdminUpn "admin@contoso.com" -UserUpn "user@contoso.com" -Purpose "Source"
if ($result.Success) {
    Write-Host "Validation successful: $($result.FileCount) files found"
} else {
    Write-Host "Validation failed: $($result.Error)"
}
```

### Invoke-EnhancedUpload

**Purpose:** Uploads files from local archive to destination OneDrive with conflict resolution.

**Syntax:**
```powershell
Invoke-EnhancedUpload -Tenant <String> -AdminUpn <String> -UserUpn <String> -LocalPath <String> [-ConflictResolution <String>] [-SourceUserUpnForMapping <String>] [-UserArchiveFolderOverride <String>] [-PreAuthCredentials <PSCredential>]
```

**Parameters:**
- `Tenant` (String, Required): Destination tenant name
- `AdminUpn` (String, Required): SharePoint Online admin account
- `UserUpn` (String, Required): Destination user account
- `LocalPath` (String, Required): Local archive path containing files
- `ConflictResolution` (String, Optional): "Skip", "Overwrite", or "Rename" (default: "Skip")
- `SourceUserUpnForMapping` (String, Optional): Source username for folder mapping
- `UserArchiveFolderOverride` (String, Optional): Explicit folder name to upload
- `PreAuthCredentials` (PSCredential, Optional): Pre-authenticated credentials

**Return Value:** Hashtable with upload results

**Success Return Structure:**
```powershell
@{
    Success = $true
    FilesUploaded = 45
    FilesSkipped = 3
    FilesFailed = 2
    ConflictResolution = "Skip"
    UserLocalPath = "C:\Migration\john.doe"
}
```

**User Folder Detection Logic:**
1. **Explicit Override:** Use `-UserArchiveFolderOverride` if provided
2. **Destination Match:** Look for folder matching destination username
3. **Source Mapping:** Look for folder matching source username (user mapping scenario)
4. **Auto-Detection:** Use single available folder, error if multiple found

**Conflict Resolution Strategies:**
- **Skip:** Leave existing files unchanged, log as skipped
- **Overwrite:** Replace existing files with migrated versions
- **Rename:** Add timestamp suffix to create unique filenames

**Upload Process:**
1. **Authentication:** Connect to SharePoint and PnP services
2. **Folder Detection:** Identify user archive folder using detection logic
3. **Structure Recreation:** Recreate folder hierarchy in OneDrive
4. **File Upload:** Upload files with progress tracking and verification
5. **Conflict Handling:** Apply selected conflict resolution strategy

**Progress Tracking:**
- Updates progress file for resume capability
- Logs detailed operation results
- Provides real-time progress indicators

**Example Usage:**
```powershell
$result = Invoke-EnhancedUpload -Tenant "fabrikam" -AdminUpn "admin@fabrikam.com" -UserUpn "john.smith@fabrikam.com" -LocalPath "C:\Migration" -ConflictResolution "Rename" -SourceUserUpnForMapping "john.doe@contoso.com"

if ($result.Success) {
    Write-Host "Upload completed: $($result.FilesUploaded) files uploaded"
} else {
    Write-Host "Upload failed"
}
```

### Invoke-EnhancedDownload

**Purpose:** Downloads files from source OneDrive to local archive with resume capability.

**Syntax:**
```powershell
Invoke-EnhancedDownload -Tenant <String> -AdminUpn <String> -UserUpn <String> -LocalPath <String> [-PreAuthCredentials <PSCredential>]
```

**Parameters:**
- `Tenant` (String, Required): Source tenant name
- `AdminUpn` (String, Required): SharePoint Online admin account
- `UserUpn` (String, Required): Source user account
- `LocalPath` (String, Required): Local path for storing downloaded files
- `PreAuthCredentials` (PSCredential, Optional): Pre-authenticated credentials

**Return Value:** Hashtable with download results

**Success Return Structure:**
```powershell
@{
    Success = $true
    FilesProcessed = 150
    FilesDownloaded = 145
    FilesSkipped = 3
    FilesFailed = 2
    FilesResumed = 8
    UserLocalPath = "C:\Migration\Migration_20231201_143022\john.doe"
}
```

**Download Process:**
1. **Authentication:** Connect to SharePoint and PnP services
2. **Folder Creation:** Create local user folder structure
3. **File Enumeration:** Recursively discover all files and folders
4. **Resume Check:** Skip files already completed (if EnableResume)
5. **Atomic Download:** Download to temporary files, rename when complete
6. **Verification:** Verify file integrity based on verification level
7. **Progress Update:** Update progress tracking for resume capability

**Resume Capability:**
- Uses atomic file operations (download to .tmp, rename when complete)
- Tracks completion status in JSON progress file
- Verifies existing files before skipping
- Handles interrupted downloads gracefully

**Large File Handling:**
- Files >250MB are logged as failures (SharePoint API limitation)
- Operation continues with other files
- Clear logging indicates size limitation issues

**Folder Structure:**
```
LocalPath/
└── {username}/
    ├── Documents/
    │   ├── file1.pdf
    │   └── Subfolder/
    │       └── file2.docx
    └── Pictures/
        └── image1.jpg
```

**Example Usage:**
```powershell
$result = Invoke-EnhancedDownload -Tenant "contoso" -AdminUpn "admin@contoso.com" -UserUpn "john.doe@contoso.com" -LocalPath "C:\Migration"

if ($result.Success) {
    Write-Host "Download completed: $($result.FilesDownloaded) of $($result.FilesProcessed) files downloaded"
    if ($result.FilesResumed -gt 0) {
        Write-Host "Resumed $($result.FilesResumed) files from previous session"
    }
}
```

## Return Values and Error Handling

### Standard Return Patterns

All major operation functions follow consistent return value patterns:

#### Success Response
```powershell
@{
    Success = $true
    # Additional success-specific properties
    FilesProcessed = <Integer>
    FilesDownloaded = <Integer>
    # ... other metrics
}
```

#### Failure Response
```powershell
@{
    Success = $false
    Error = "<Detailed error message>"
    # Optional additional error context
}
```

#### DryRun Response
```powershell
@{
    Success = $true
    DryRun = $true
    # Placeholder values for metrics
    FilesProcessed = "N/A (Dry Run)"
}
```

### Error Categories

#### Authentication Errors
- **Cause:** Invalid credentials, MFA issues, permission problems
- **Handling:** Credential re-prompt, fallback authentication methods
- **User Action:** Verify credentials, check admin permissions

#### Network Errors
- **Cause:** Connection timeouts, network connectivity issues
- **Handling:** Retry logic, graceful degradation
- **User Action:** Check internet connectivity, verify SharePoint URLs

#### File System Errors
- **Cause:** Disk space, permissions, path length limitations
- **Handling:** Detailed error logging, operation continuation where possible
- **User Action:** Free disk space, check permissions, use shorter paths

#### SharePoint API Limitations
- **Cause:** File size limits (>250MB), API rate limiting
- **Handling:** Clear logging, continuation with other files
- **User Action:** Use alternative methods for very large files

### Logging and Audit Trail

#### CSV Audit Log Format
```csv
Timestamp,SessionId,Operation,ItemType,ItemName,ItemPath,Status,Size,Error
2023-12-01 14:30:22,20231201_143022,Download,File,document.pdf,/Documents/document.pdf,Success,2.5MB,
2023-12-01 14:30:25,20231201_143022,Download,File,largefile.zip,/Documents/largefile.zip,Failed,277MB,File exceeds SharePoint limit (277MB > 250MB)
```

#### Progress Tracking JSON
```json
{
  "sessionId": "20231201_143022",
  "startTime": "2023-12-01T14:30:22.123Z",
  "verificationLevel": "Enhanced",
  "mode": "DownloadOnly",
  "files": {
    "/Documents/document.pdf": {
      "status": "Completed",
      "sourceSize": 2621440,
      "sourceModified": "2023-11-15T10:30:00Z",
      "localPath": "C:\\Migration\\user\\Documents\\document.pdf",
      "lastAttempt": "2023-12-01T14:35:15Z",
      "verificationLevel": "Enhanced",
      "hash": "a1b2c3d4e5f6..."
    }
  }
}
```

## Usage Examples

### Basic Download Operation
```powershell
# Simple download with default settings
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com"
```

### Enhanced Download with Resume
```powershell
# Download with enhanced verification and resume capability
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -LocalArchivePath "C:\Migration\JohnDoe" `
  -VerificationLevel Enhanced `
  -EnableResume `
  -LogFile "C:\Logs\JohnDoe-Migration.csv"
```

### Upload with User Mapping
```powershell
# Upload with different source/destination usernames
.\OneDriveMigration.ps1 -Mode UploadOnly `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.smith@fabrikam.onmicrosoft.com" `
  -LocalArchivePath "C:\Migration\Archive" `
  -UserArchiveFolder "john.doe" `
  -ConflictResolution Rename
```

### Complete Interactive Migration
```powershell
# Full migration with user review step
.\OneDriveMigration.ps1 -Mode Interactive `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.doe@fabrikam.onmicrosoft.com" `
  -VerificationLevel Enhanced `
  -EnableResume
```

### Validation and Planning
```powershell
# Test connections and permissions
.\OneDriveMigration.ps1 -Mode ValidateOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com"

# Preview download operations
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -DryRun
```

### Bulk Migration Script
```powershell
# Example bulk migration approach
$users = Import-Csv "user-mappings.csv"  # source_user,dest_user

foreach ($user in $users) {
    Write-Host "Processing $($user.source_user)..." -ForegroundColor Cyan
    
    # Download phase
    $downloadResult = .\OneDriveMigration.ps1 -Mode DownloadOnly `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $user.source_user `
      -LocalArchivePath "C:\Migration\$($user.source_user.Split('@')[0])" `
      -EnableResume -Concise
    
    if ($downloadResult.Success) {
        # Upload phase
        .\OneDriveMigration.ps1 -Mode UploadOnly `
          -DestTenant "fabrikam" `
          -DestAdminUpn "admin@fabrikam.com" `
          -DestUserUpn $user.dest_user `
          -LocalArchivePath "C:\Migration\$($user.source_user.Split('@')[0])" `
          -ConflictResolution Skip -Concise -Yes
    }
}
```

## Architecture Overview

### Component Relationships

```
OneDriveMigration.ps1
├── Parameter Validation
│   └── Test-ParameterValidation()
├── Prerequisites & Setup
│   ├── Test-Prerequisites()
│   └── Module Installation & Import
├── Credential Management
│   ├── Get-MigrationCredentials()
│   └── Credential Caching
├── Progress Tracking (Optional)
│   ├── Initialize-ProgressTracking()
│   ├── Get-ProgressData()
│   └── Update-ProgressData()
├── File Verification
│   ├── Test-FileIntegrity()
│   ├── Get-FileVerificationHash()
│   └── Get-AtomicTempPath()
├── Core Operations
│   ├── Invoke-EnhancedValidation()
│   ├── Invoke-EnhancedDownload()
│   └── Invoke-EnhancedUpload()
└── Logging & Audit
    └── Write-MigrationLog()
```

### Data Flow

#### Download Operation Flow
1. **Parameter Validation** → Validate required source parameters
2. **Prerequisites Check** → Install modules, check disk space
3. **Progress Initialization** → Create progress tracking (if enabled)
4. **Credential Management** → Authenticate with source tenant
5. **Enhanced Validation** → Test connections and permissions
6. **Enhanced Download** → Download files with verification
7. **Progress Updates** → Track completion status
8. **Audit Logging** → Record operations in CSV log

#### Upload Operation Flow
1. **Parameter Validation** → Validate required destination parameters
2. **User Folder Detection** → Identify archive folder to upload
3. **Credential Management** → Authenticate with destination tenant
4. **Enhanced Upload** → Upload files with conflict resolution
5. **Progress Updates** → Track upload status
6. **Audit Logging** → Record operations in CSV log

#### Interactive Mode Flow
1. **Download Phase** → Complete download operation
2. **User Review** → Pause for manual file review
3. **User Confirmation** → Prompt to proceed with upload
4. **Upload Phase** → Complete upload operation

### File System Organization

```
LocalArchivePath/
├── {username}/                     # User-specific folder
│   ├── Documents/                  # OneDrive folder structure
│   │   ├── file1.pdf
│   │   └── Subfolder/
│   │       └── file2.docx
│   └── Pictures/
│       └── image1.jpg
├── Migration_Log_{SessionId}.csv   # Audit log
└── Migration_Progress_{SessionId}.json  # Resume data (if enabled)
```

### Session Management

- **Session ID:** `yyyyMMdd_HHmmss` format for unique identification
- **Progress Tracking:** JSON file enables resume across sessions
- **Credential Caching:** In-memory caching for same-tenant scenarios
- **Atomic Operations:** Temporary files ensure data integrity

### Error Resilience

- **Resume Capability:** Continue interrupted downloads
- **Verification Levels:** Basic (size) or Enhanced (hash) integrity checks
- **Graceful Degradation:** Continue operation despite individual file failures
- **Comprehensive Logging:** Detailed audit trail for troubleshooting

---

**Note:** This API documentation covers the current implementation. The tool is actively developed with additional features planned. Refer to the main README.md for the latest feature status and roadmap.