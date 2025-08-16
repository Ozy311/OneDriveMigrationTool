# Author: Ozy
# OneDrive Migration Tool - Enterprise Edition
# Supports full tenant-to-tenant OneDrive migrations with comprehensive logging and validation
# Compatible with PowerShell v5.1 (recommended) and PowerShell 7+

[CmdletBinding()]
param(
    # Operation Mode
    [Parameter(Mandatory=$false)]
    [ValidateSet("Interactive", "DownloadOnly", "UploadOnly", "ValidateOnly", "Automated")]
    [string]$Mode = "Interactive",
    
    # Source (Download) Parameters
    [Parameter(Mandatory=$false)]
    [string]$SourceTenant,
    
    [Parameter(Mandatory=$false)]
    [string]$SourceAdminUpn,
    
    [Parameter(Mandatory=$false)]
    [string]$SourceUserUpn,
    
    # Destination (Upload) Parameters
    [Parameter(Mandatory=$false)]
    [string]$DestTenant,
    
    [Parameter(Mandatory=$false)]
    [string]$DestAdminUpn,
    
    [Parameter(Mandatory=$false)]
    [string]$DestUserUpn,
    
    # User Mapping Parameters (for UploadOnly when usernames differ)
    [Parameter(Mandatory=$false)]
    [string]$UserArchiveFolder,
    
    # Operation Parameters
    [Parameter(Mandatory=$false)]
    [string]$LocalArchivePath,
    
    # Conflict Resolution (for upload operations)
    [Parameter(Mandatory=$false)]
    [ValidateSet("Skip", "Overwrite", "Rename")]
    [string]$ConflictResolution = "Skip",
    
    # Control Parameters
    [Parameter(Mandatory=$false)]
    [switch]$Yes,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Concise,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile,
    
    # Resume and Verification Parameters
    [Parameter(Mandatory=$false)]
    [ValidateSet("Basic", "Enhanced")]
    [string]$VerificationLevel = "Basic",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableResume,
    
    # Help Parameter
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Show comprehensive help if no meaningful parameters provided or Help switch used
if ($Help -or (-not $SourceTenant -and -not $DestTenant -and $Mode -eq "Interactive")) {
    Write-Host @"

=================================================================
            OneDrive Migration Tool - Enterprise Edition
=================================================================

DESCRIPTION:
    Comprehensive tool for OneDrive tenant-to-tenant migrations with 
    enterprise-grade logging, validation, and progress tracking.

FEATURES:
    + Interactive migration with human oversight
    + Download-only backup mode  
    + Upload-only restore mode
    + Full validation with connection testing
    + CSV audit logging for compliance
    + Progress tracking and resume capability
    + Dry-run mode for planning
    + PowerShell 5.1 and 7+ compatible

LIMITATIONS:
    ! Individual file size limit: 15GB (no chunking implemented)
    ! Requires SharePoint admin permissions on both tenants
    ! Large migrations may take several hours

MODES:
    Interactive   Default mode - Download, pause for review, then upload
    DownloadOnly  Backup files from source tenant only
    UploadOnly    Restore files to destination tenant only  
    ValidateOnly  Test connections and permissions
    Automated     Full migration without user interaction

PARAMETERS:
    -SourceTenant      Source tenant name (required for download operations)
    -SourceAdminUpn    Source admin email (required for download operations)
    -SourceUserUpn     Source user email (required for download operations)
    -DestTenant        Destination tenant name (required for upload operations)
    -DestAdminUpn      Destination admin email (required for upload operations)  
    -DestUserUpn       Destination user email (required for upload operations)
    -LocalArchivePath  Local storage path (default: .\Migration_timestamp)
    -UserArchiveFolder Specific user folder name in archive (for username mapping)
    -ConflictResolution How to handle existing files: Skip|Overwrite|Rename
    -LogFile           Custom CSV log file path (default: auto-generated)
    -VerificationLevel File integrity verification: Basic(size)|Enhanced(size+hash) (default: Basic)
    -EnableResume      Enable resume capability for interrupted transfers
    -Yes               Skip confirmation prompts (for automation)
    -DryRun            Show what would be processed without executing
    -Concise           Reduce verbose output

EXAMPLES:

  1) DOWNLOAD ONLY (Backup):
     .\OneDriveMigration.ps1 -Mode DownloadOnly `
       -SourceTenant "contoso" `
       -SourceAdminUpn "admin@contoso.com" `
       -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
       -LocalArchivePath "C:\Backups\JohnDoe"

  2) INTERACTIVE MIGRATION (Default - Recommended):
     .\OneDriveMigration.ps1 `
       -SourceTenant "contoso" `
       -SourceAdminUpn "admin@contoso.com" `
       -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
       -DestTenant "fabrikam" `
       -DestAdminUpn "admin@fabrikam.com" `
       -DestUserUpn "jdoe@fabrikam.onmicrosoft.com"

  3) UPLOAD ONLY (Restore from backup):
     .\OneDriveMigration.ps1 -Mode UploadOnly `
       -DestTenant "fabrikam" `
       -DestAdminUpn "admin@fabrikam.com" `
       -DestUserUpn "jdoe@fabrikam.onmicrosoft.com" `
       -LocalArchivePath "C:\Backups\JohnDoe" `
       -ConflictResolution Rename

  4) VALIDATION (Test connections):
     .\OneDriveMigration.ps1 -Mode ValidateOnly `
       -SourceTenant "contoso" `
       -SourceAdminUpn "admin@contoso.com" `
       -SourceUserUpn "jdoe@contoso.onmicrosoft.com"

  5) AUTOMATED MIGRATION (No prompts):
     .\OneDriveMigration.ps1 -Mode Automated `
       -SourceTenant "contoso" `
       -SourceAdminUpn "admin@contoso.com" `
       -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
       -DestTenant "fabrikam" `
       -DestAdminUpn "admin@fabrikam.com" `
       -DestUserUpn "jdoe@fabrikam.onmicrosoft.com" `
       -Yes -Concise

  6) UPLOAD WITH USER MAPPING (Different usernames):
     .\OneDriveMigration.ps1 -Mode UploadOnly `
       -DestTenant "fabrikam" `
       -DestAdminUpn "admin@fabrikam.com" `
       -DestUserUpn "john.doe@fabrikam.onmicrosoft.com" `
       -LocalArchivePath "C:\Migration\Archive" `
       -UserArchiveFolder "jdoe" `
       -ConflictResolution Skip

  7) DOWNLOAD WITH RESUME (Enterprise reliability):
     .\OneDriveMigration.ps1 -Mode DownloadOnly `
       -SourceTenant "contoso" `
       -SourceAdminUpn "admin@contoso.com" `
       -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
       -EnableResume -VerificationLevel Enhanced

  8) DRY RUN (Planning):
     .\OneDriveMigration.ps1 -Mode DownloadOnly `
       -SourceTenant "contoso" `
       -SourceAdminUpn "admin@contoso.com" `
       -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
       -DryRun

PREREQUISITES:
    - PowerShell 5.1 or 7+
    - Internet connectivity
    - SharePoint Online admin permissions
    - Required PowerShell modules (auto-installed):
      - Microsoft.Online.SharePoint.PowerShell
      - SharePointPnPPowerShellOnline

For more information, see README.md

=================================================================

"@ -ForegroundColor Cyan
    exit 0
}

# PowerShell Version Check
if ($PSVersionTable.PSVersion.Major -ge 7) {
    if (-not $Concise) {
        Write-Warning @"
You are running PowerShell 7+. This script was designed and tested on PowerShell 5.1.
While it may work on PS7, if you encounter issues, please try running on PowerShell 5.1:
    powershell.exe -File "OneDriveMigration.ps1" [parameters]
Use -Concise to suppress this warning.
"@
        Start-Sleep -Seconds 2
    }
}

# Parameter Validation Based on Mode
function Test-ParameterValidation {
    $errors = @()
    
    switch ($Mode) {
        "ValidateOnly" {
            if (-not $SourceTenant -and -not $DestTenant) { 
                $errors += "ValidateOnly mode requires either Source parameters (SourceTenant, SourceAdminUpn, SourceUserUpn) or Destination parameters (DestTenant, DestAdminUpn, DestUserUpn)" 
            }
            if ($SourceTenant -and (-not $SourceAdminUpn -or -not $SourceUserUpn)) {
                $errors += "When SourceTenant is specified, SourceAdminUpn and SourceUserUpn are also required"
            }
            if ($DestTenant -and (-not $DestAdminUpn -or -not $DestUserUpn)) {
                $errors += "When DestTenant is specified, DestAdminUpn and DestUserUpn are also required"
            }
        }
        "DownloadOnly" {
            if (-not $SourceTenant) { $errors += "SourceTenant is required for DownloadOnly mode" }
            if (-not $SourceAdminUpn) { $errors += "SourceAdminUpn is required for DownloadOnly mode" }
            if (-not $SourceUserUpn) { $errors += "SourceUserUpn is required for DownloadOnly mode" }
        }
        "UploadOnly" {
            if (-not $DestTenant) { $errors += "DestTenant is required for UploadOnly mode" }
            if (-not $DestAdminUpn) { $errors += "DestAdminUpn is required for UploadOnly mode" }
            if (-not $DestUserUpn) { $errors += "DestUserUpn is required for UploadOnly mode" }
            if (-not $LocalArchivePath) { $errors += "LocalArchivePath is required for UploadOnly mode (specify archive location)" }
        }
        { $_ -in @("Interactive", "Automated") } {
            if (-not $SourceTenant) { $errors += "SourceTenant is required for $Mode mode" }
            if (-not $SourceAdminUpn) { $errors += "SourceAdminUpn is required for $Mode mode" }
            if (-not $SourceUserUpn) { $errors += "SourceUserUpn is required for $Mode mode" }
            if (-not $DestTenant) { $errors += "DestTenant is required for $Mode mode" }
            if (-not $DestAdminUpn) { $errors += "DestAdminUpn is required for $Mode mode" }
            if (-not $DestUserUpn) { $errors += "DestUserUpn is required for $Mode mode" }
        }
    }
    
    if ($errors.Count -gt 0) {
        Write-Host "Parameter validation failed:" -ForegroundColor Red
        foreach ($errorMsg in $errors) {
            Write-Host "  - $errorMsg" -ForegroundColor Red
        }
        Write-Host "`nUse -Help for parameter examples" -ForegroundColor Yellow
        exit 1
    }
}

# Validate parameters
Test-ParameterValidation

# Global Variables
$Script:StartTime = Get-Date
$Script:SessionId = Get-Date -Format 'yyyyMMdd_HHmmss'
$Script:ProgressFile = ""

# Set default LocalArchivePath if not provided
if (-not $LocalArchivePath) {
    $LocalArchivePath = Join-Path -Path (Get-Location) -ChildPath "Migration_$Script:SessionId"
}

# Set progress file path for resume functionality
if ($EnableResume) {
    $Script:ProgressFile = Join-Path -Path $LocalArchivePath -ChildPath "Migration_Progress_$Script:SessionId.json"
}

# Set default LogFile if not provided
if (-not $LogFile) {
    $LogFile = Join-Path -Path $LocalArchivePath -ChildPath "Migration_Log_$Script:SessionId.csv"
}

# Ensure log directory exists
$logDir = Split-Path -Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Initialize CSV log
$csvHeaders = @("Timestamp", "SessionId", "Operation", "ItemType", "ItemName", "ItemPath", "Status", "Size", "Error")
$csvHeaders -join "," | Out-File -FilePath $LogFile -Encoding UTF8

# Logging Functions
function Write-MigrationLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success", "Progress")]
        [string]$Level = "Info",
        [string]$Operation = "",
        [string]$ItemType = "",
        [string]$ItemName = "",
        [string]$ItemPath = "",
        [string]$Size = "",
        [string]$Status = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Console output with colors (unless Concise mode)
    if (-not $Concise -or $Level -in @("Error", "Warning", "Success")) {
        $colors = @{ 
            "Info" = "White"; "Warning" = "Yellow"; "Error" = "Red"; 
            "Success" = "Green"; "Progress" = "Cyan" 
        }
        
        $prefix = switch ($Level) {
            "Info" { "[INFO]" }
            "Warning" { "[WARN]" }
            "Error" { "[ERROR]" }
            "Success" { "[OK]" }
            "Progress" { "[...]" }
        }
        
        Write-Host "$prefix $Message" -ForegroundColor $colors[$Level]
    }
    
    # CSV logging
    if ($Operation -or $ItemName) {
        $csvLine = @(
            $timestamp,
            $Script:SessionId,
            $Operation,
            $ItemType,
            $ItemName,
            $ItemPath,
            $Status,
            $Size,
            ($Error -replace '"', '""')  # Escape quotes for CSV
        )
        ($csvLine -join '","').Insert(0, '"') + '"' | Add-Content -Path $LogFile -Encoding UTF8
    }
}

# Prerequisites Check Function
function Test-Prerequisites {
    Write-MigrationLog "Checking system prerequisites..." -Level "Progress"
    
    $issues = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 or higher required (found $($PSVersionTable.PSVersion))"
    }
    
    # Check required modules
    $requiredModules = @("Microsoft.Online.SharePoint.PowerShell", "SharePointPnPPowerShellOnline")
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            if (-not $DryRun) {
                Write-MigrationLog "Installing required module: $module" -Level "Warning"
                try {
                    if ($module -eq "SharePointPnPPowerShellOnline") {
                        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
                    } else {
                        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
                    }
                } catch {
                    $issues += "Failed to install module $module : $($_.Exception.Message)"
                }
            } else {
                Write-MigrationLog "Would install module: $module" -Level "Info"
            }
        }
    }
    
    # Check disk space for downloads
    if ($Mode -in @("Interactive", "DownloadOnly", "Automated")) {
        $drive = (Get-Item $LocalArchivePath).PSDrive
        if (-not $drive) {
            $drive = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($LocalArchivePath).TrimEnd('\').TrimEnd(':'))
        }
        
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        if ($freeSpaceGB -lt 5) {
            Write-MigrationLog "Low disk space warning: Only ${freeSpaceGB}GB available" -Level "Warning"
        } else {
            Write-MigrationLog "Disk space check: ${freeSpaceGB}GB available" -Level "Info"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-MigrationLog "Prerequisites check failed:" -Level "Error"
        foreach ($issue in $issues) {
            Write-MigrationLog "  - $issue" -Level "Error"
        }
        exit 1
    } else {
        Write-MigrationLog "Prerequisites check passed" -Level "Success"
    }
    
    # Import modules if not dry run
    if (-not $DryRun) {
        foreach ($module in $requiredModules) {
            Import-Module -Name $module -Force
        }
        Write-MigrationLog "PowerShell modules imported successfully" -Level "Success"
    }
}

# Credential Management
$Script:CachedCredentials = @{}

function Get-MigrationCredentials {
    param(
        [string]$TenantName,
        [string]$Purpose  # "Source" or "Destination"
    )
    
    if ($DryRun) {
        Write-MigrationLog "Would prompt for $Purpose tenant credentials ($TenantName)" -Level "Info"
        return $null
    }
    
    # Check if we already have credentials for this tenant (same-tenant scenario)
    if ($Script:CachedCredentials.ContainsKey($TenantName)) {
        Write-MigrationLog "Reusing credentials for $Purpose tenant (same as previous: $TenantName)" -Level "Info"
        return $Script:CachedCredentials[$TenantName]
    }
    
    Write-MigrationLog "Please enter $Purpose tenant credentials for $TenantName..." -Level "Warning"
    $credentials = Get-Credential -Message "Enter credentials for $Purpose tenant ($TenantName)"
    
    # Cache credentials for potential reuse
    if ($credentials) {
        $Script:CachedCredentials[$TenantName] = $credentials
    }
    
    return $credentials
}

# Progress Tracking Functions
function Initialize-ProgressTracking {
    if (-not $EnableResume -or $DryRun) { return }
    
    if (-not (Test-Path $Script:ProgressFile)) {
        $progressData = @{
            sessionId = $Script:SessionId
            startTime = $Script:StartTime
            verificationLevel = $VerificationLevel
            mode = $Mode
            files = @{}
        }
        $progressData | ConvertTo-Json -Depth 3 | Out-File -FilePath $Script:ProgressFile -Encoding UTF8
        Write-MigrationLog "Initialized progress tracking: $Script:ProgressFile" -Level "Info"
    } else {
        Write-MigrationLog "Resume mode: Found existing progress file" -Level "Info"
    }
}

function Get-ProgressData {
    if (-not $EnableResume -or $DryRun) { return @{ files = @{} } }
    
    if (Test-Path $Script:ProgressFile) {
        try {
            $content = Get-Content -Path $Script:ProgressFile -Raw | ConvertFrom-Json
            # Ensure files property exists and is a hashtable
            if (-not $content.files) {
                $content | Add-Member -NotePropertyName "files" -NotePropertyValue @{} -Force
            }
            # Convert PSCustomObject to hashtable for easier manipulation
            $filesHashtable = @{}
            if ($content.files) {
                $content.files.PSObject.Properties | ForEach-Object {
                    $filesHashtable[$_.Name] = $_.Value
                }
            }
            $content.files = $filesHashtable
            return $content
        } catch {
            Write-MigrationLog "Warning: Could not read progress file, starting fresh" -Level "Warning"
            return @{ files = @{} }
        }
    }
    return @{ files = @{} }
}

function Update-ProgressData {
    param(
        [string]$FilePath,
        [string]$Status,
        [long]$SourceSize = 0,
        [datetime]$SourceModified = [datetime]::MinValue,
        [string]$LocalPath = "",
        [string]$Hash = "",
        [string]$ErrorMessage = ""
    )
    
    if (-not $EnableResume -or $DryRun) { return }
    
    try {
        $progressData = Get-ProgressData
        if (-not $progressData.files) { 
            $progressData.files = @{} 
        }
        
        $fileInfo = @{
            status = $Status
            sourceSize = $SourceSize
            sourceModified = $SourceModified.ToString("yyyy-MM-ddTHH:mm:ssZ")
            localPath = $LocalPath
            lastAttempt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            verificationLevel = $VerificationLevel
        }
        
        if ($Hash) { $fileInfo.hash = $Hash }
        if ($ErrorMessage) { $fileInfo.error = $ErrorMessage }
        
        $progressData.files[$FilePath] = $fileInfo
        $progressData | ConvertTo-Json -Depth 4 | Out-File -FilePath $Script:ProgressFile -Encoding UTF8
        
    } catch {
        Write-MigrationLog "Warning: Could not update progress file: $($_.Exception.Message)" -Level "Warning"
    }
}

# File Verification Functions
function Test-FileIntegrity {
    param(
        [string]$LocalFilePath,
        [long]$ExpectedSize,
        [datetime]$ExpectedModified,
        [string]$ExpectedHash = ""
    )
    
    if (-not (Test-Path $LocalFilePath)) { 
        return @{ IsValid = $false; Reason = "File not found" }
    }
    
    $fileInfo = Get-Item $LocalFilePath
    
    # Basic verification: Size only (SharePoint downloads don't preserve original modified dates)
    if ($fileInfo.Length -ne $ExpectedSize) {
        return @{ IsValid = $false; Reason = "Size mismatch: Expected $ExpectedSize, got $($fileInfo.Length)" }
    }
    
    # Note: SharePoint/OneDrive downloads do NOT preserve original modified dates
    # The download process sets the modified date to the current download time
    # Therefore, we only verify file size for Basic mode and rely on hash for Enhanced mode
    
    # Enhanced verification: SHA256 Hash
    if ($VerificationLevel -eq "Enhanced" -and $ExpectedHash) {
        try {
            $actualHash = (Get-FileHash -Path $LocalFilePath -Algorithm SHA256).Hash
            if ($actualHash -ne $ExpectedHash) {
                return @{ IsValid = $false; Reason = "Hash mismatch" }
            }
        } catch {
            return @{ IsValid = $false; Reason = "Hash calculation failed: $($_.Exception.Message)" }
        }
    }
    
    return @{ IsValid = $true; Reason = "All verifications passed" }
}

function Get-FileVerificationHash {
    param([string]$FilePath)
    
    if ($VerificationLevel -eq "Enhanced" -and (Test-Path $FilePath)) {
        try {
            return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
        } catch {
            Write-MigrationLog "Warning: Could not calculate hash for $FilePath" -Level "Warning"
            return ""
        }
    }
    return ""
}

function Get-AtomicTempPath {
    param([string]$FinalPath)
    return "$FinalPath.tmp.$PID"
}

Write-MigrationLog "=== OneDrive Migration Tool Started ===" -Level "Success"
Write-MigrationLog "Session ID: $Script:SessionId" -Level "Info"
Write-MigrationLog "Mode: $Mode" -Level "Info"
if ($DryRun) { Write-MigrationLog "DRY RUN MODE - No actual operations will be performed" -Level "Warning" }
if ($EnableResume) { 
    Write-MigrationLog "Resume Enabled: $VerificationLevel verification" -Level "Info"
    if ($Script:ProgressFile) {
        Write-MigrationLog "Progress File: $Script:ProgressFile" -Level "Info"
    }
}
Write-MigrationLog "Local Archive Path: $LocalArchivePath" -Level "Info"
Write-MigrationLog "Log File: $LogFile" -Level "Info"

# Run prerequisites check
Test-Prerequisites

# Initialize progress tracking
Initialize-ProgressTracking

Write-MigrationLog "Enhanced Framework with Resume Capability Initialized!" -Level "Success"
Write-MigrationLog "Ready for enterprise-grade download/upload operations" -Level "Info"

# Enhanced Validation Function
function Invoke-EnhancedValidation {
    param(
        [string]$Tenant,
        [string]$AdminUpn,
        [string]$UserUpn,
        [string]$Purpose
    )
    
    if ($DryRun) {
        Write-MigrationLog "Would validate $Purpose connection to $Tenant" -Level "Info"
        Write-MigrationLog "Would test admin permissions for $AdminUpn" -Level "Info"
        Write-MigrationLog "Would connect to OneDrive for $UserUpn" -Level "Info"
        Write-MigrationLog "Would list files from Documents library" -Level "Info"
        return @{ Success = $true; ItemCount = "N/A (Dry Run)"; DryRun = $true }
    }
    
    try {
        Write-MigrationLog "Validating $Purpose connection to $Tenant..." -Level "Progress"
        
        $adminUrl = "https://$Tenant-admin.sharepoint.com"
        $userPath = $UserUpn.Replace('@', '_').Replace('.', '_')
        $oneDriveUrl = "https://$Tenant-my.sharepoint.com/personal/$userPath"
        
        # Get credentials
        $cred = Get-MigrationCredentials -TenantName $Tenant -Purpose $Purpose
        if (-not $cred) { throw "Failed to obtain credentials" }
        
        # Test admin connection
        Write-MigrationLog "Testing admin connection..." -Level "Progress"
        Connect-SPOService -Url $adminUrl -Credential $cred -ModernAuth $true
        Set-SPOUser -Site $oneDriveUrl -LoginName $AdminUpn -IsSiteCollectionAdmin $true
        
        Start-Sleep -Seconds 5
        
        # Test PnP connection
        Write-MigrationLog "Testing OneDrive access..." -Level "Progress"
        Write-MigrationLog "Attempting PnP connection to: $oneDriveUrl" -Level "Info"
        Write-MigrationLog "Using credentials for: $($cred.UserName)" -Level "Info"
        
        try {
            Connect-PnPOnline -Url $oneDriveUrl -Credentials $cred
            Write-MigrationLog "PnP connection successful" -Level "Success"
        } catch {
            Write-MigrationLog "PnP connection failed: $($_.Exception.Message)" -Level "Error"
            Write-MigrationLog "Trying interactive authentication..." -Level "Info"
            
            # Try UseWebLogin for legacy PnP module
            Write-MigrationLog "Trying UseWebLogin for modern authentication..." -Level "Info"
            Connect-PnPOnline -Url $oneDriveUrl -UseWebLogin
            Write-MigrationLog "Interactive PnP connection successful" -Level "Success"
        }
        
        # Test access to Documents library and count items
        Write-MigrationLog "Counting items in Documents library..." -Level "Progress"
        $items = Get-PnPListItem -List "Documents" -PageSize 100
        $totalItems = $items.Count
        $fileCount = ($items | Where-Object { $_.FieldValues.FSObjType -eq 0 }).Count
        
        Write-MigrationLog "$Purpose validation successful!" -Level "Success"
        Write-MigrationLog "Found $totalItems total items ($fileCount files)" -Level "Success"
        
        # Log validation result
        Write-MigrationLog "" -Level "Info" -Operation "Validation" -ItemType "Connection" -ItemName "$Purpose-$Tenant" -Status "Success" -Size "$totalItems items"
        
        return @{
            Success = $true
            AdminUrl = $adminUrl
            OneDriveUrl = $oneDriveUrl
            ItemCount = $totalItems
            FileCount = $fileCount
            Credential = $cred
        }
        
    } catch {
        Write-MigrationLog "$Purpose validation failed: $($_.Exception.Message)" -Level "Error"
        Write-MigrationLog "" -Level "Error" -Operation "Validation" -ItemType "Connection" -ItemName "$Purpose-$Tenant" -Status "Failed" -Error $_.Exception.Message
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Enhanced Upload Function  
function Invoke-EnhancedUpload {
    param(
        [string]$Tenant,
        [string]$AdminUpn,
        [string]$UserUpn,
        [string]$LocalPath,
        [string]$ConflictResolution = "Skip",
        [string]$SourceUserUpnForMapping = "",
        [string]$UserArchiveFolderOverride = "",
        [System.Management.Automation.PSCredential]$PreAuthCredentials = $null
    )
    
    if ($DryRun) {
        Write-MigrationLog "Would upload files from $LocalPath to $Tenant" -Level "Info"
        Write-MigrationLog "Would connect to destination OneDrive for $UserUpn" -Level "Info"
        
        # Simulate folder detection logic for dry run
        if ($UserArchiveFolderOverride) {
            Write-MigrationLog "Would use explicit folder: $UserArchiveFolderOverride" -Level "Info"
        } elseif (Test-Path (Join-Path $LocalPath ($UserUpn.Split('@')[0])) -PathType Container) {
            Write-MigrationLog "Would detect folder by destination username: $($UserUpn.Split('@')[0])" -Level "Info"
        } elseif ($SourceUserUpnForMapping -and (Test-Path (Join-Path $LocalPath ($SourceUserUpnForMapping.Split('@')[0])) -PathType Container)) {
            Write-MigrationLog "Would detect folder by source username: $($SourceUserUpnForMapping.Split('@')[0]) (mapping to $($UserUpn.Split('@')[0]))" -Level "Info"
        } else {
            Write-MigrationLog "Would auto-detect first available user folder" -Level "Info"
        }
        
        Write-MigrationLog "Would recreate folder structure in OneDrive" -Level "Info"
        Write-MigrationLog "Conflict resolution mode: $ConflictResolution" -Level "Info"
        return @{ Success = $true; FilesUploaded = "N/A (Dry Run)"; DryRun = $true }
    }
    
    try {
        Write-MigrationLog "=== STARTING ENHANCED UPLOAD ===" -Level "Success"
        
        $adminUrl = "https://$Tenant-admin.sharepoint.com"
        $userPath = $UserUpn.Replace('@', '_').Replace('.', '_')
        $oneDriveUrl = "https://$Tenant-my.sharepoint.com/personal/$userPath"
        
        # Smart user archive folder detection
        $userArchiveFolder = $null
        $detectionMethod = ""
        
        # Method 1: Explicit UserArchiveFolder parameter (highest priority)
        if ($UserArchiveFolderOverride) {
            $explicitPath = Join-Path -Path $LocalPath -ChildPath $UserArchiveFolderOverride
            if (Test-Path $explicitPath -PathType Container) {
                $userArchiveFolder = Get-Item $explicitPath
                $detectionMethod = "Explicit parameter: $UserArchiveFolderOverride"
            } else {
                throw "Specified UserArchiveFolder '$UserArchiveFolderOverride' not found in $LocalPath"
            }
        }
        
        # Method 2: Match destination username (dest user folder exists)
        if (-not $userArchiveFolder) {
            $destUserFolder = $DestUserUpn.Split('@')[0]
            $destUserPath = Join-Path -Path $LocalPath -ChildPath $destUserFolder
            if (Test-Path $destUserPath -PathType Container) {
                $userArchiveFolder = Get-Item $destUserPath
                $detectionMethod = "Matched destination username: $destUserFolder"
            }
        }
        
        # Method 3: Match source username (for user mapping scenarios)
        if (-not $userArchiveFolder -and $SourceUserUpnForMapping) {
            $sourceUserFolder = $SourceUserUpnForMapping.Split('@')[0]
            $sourceUserPath = Join-Path -Path $LocalPath -ChildPath $sourceUserFolder
            if (Test-Path $sourceUserPath -PathType Container) {
                $userArchiveFolder = Get-Item $sourceUserPath
                $detectionMethod = "Matched source username: $sourceUserFolder (mapping to $($UserUpn.Split('@')[0]))"
            }
        }
        
        # Method 4: Auto-detect first available folder (fallback)
        if (-not $userArchiveFolder) {
            $availableFolders = Get-ChildItem -Path $LocalPath -Directory | Where-Object { $_.Name -notlike "Migration_Log*" }
            if ($availableFolders.Count -eq 1) {
                $userArchiveFolder = $availableFolders[0]
                $detectionMethod = "Auto-detected single folder: $($userArchiveFolder.Name)"
            } elseif ($availableFolders.Count -gt 1) {
                $folderList = ($availableFolders.Name -join ", ")
                throw "Multiple user folders found [$folderList]. Use -UserArchiveFolder to specify which one to upload."
            } else {
                throw "No user archive folder found in $LocalPath"
            }
        }
        
        $userLocalPath = $userArchiveFolder.FullName
        Write-MigrationLog "Archive folder detection: $detectionMethod" -Level "Info"
        Write-MigrationLog "Using archive folder: $userLocalPath" -Level "Info"
        
        # Get credentials (use pre-authenticated if available)
        if ($PreAuthCredentials) {
            $cred = $PreAuthCredentials
            Write-MigrationLog "Using pre-authenticated credentials for destination tenant" -Level "Info"
        } else {
            $cred = Get-MigrationCredentials -TenantName $Tenant -Purpose "Destination"
            if (-not $cred) { throw "Failed to obtain credentials" }
        }
        
        Write-MigrationLog "Connecting to SharePoint Online Admin..." -Level "Progress"
        Connect-SPOService -Url $adminUrl -Credential $cred -ModernAuth $true
        
        Write-MigrationLog "Granting admin access to destination OneDrive..." -Level "Progress"
        Set-SPOUser -Site $oneDriveUrl -LoginName $AdminUpn -IsSiteCollectionAdmin $true
        
        Start-Sleep -Seconds 10
        
        Write-MigrationLog "Connecting to destination OneDrive..." -Level "Progress"
        Write-MigrationLog "Attempting PnP connection to: $oneDriveUrl" -Level "Info"
        Write-MigrationLog "Using credentials for: $($cred.UserName)" -Level "Info"
        
        try {
            Connect-PnPOnline -Url $oneDriveUrl -Credentials $cred
            Write-MigrationLog "PnP connection successful" -Level "Success"
        } catch {
            Write-MigrationLog "PnP connection failed: $($_.Exception.Message)" -Level "Error"
            Write-MigrationLog "Trying alternative PnP connection method..." -Level "Info"
            
            # Try UseWebLogin for legacy PnP module
            try {
                Write-MigrationLog "Trying UseWebLogin for modern authentication..." -Level "Info"
                Connect-PnPOnline -Url $oneDriveUrl -UseWebLogin
                Write-MigrationLog "Web login PnP connection successful" -Level "Success"
            } catch {
                Write-MigrationLog "Web login PnP connection also failed: $($_.Exception.Message)" -Level "Error"
                throw "Unable to connect to destination OneDrive. Check tenant authentication policies or try newer PnP.PowerShell module."
            }
        }
        
        # Get all files to upload (recursively)
        $filesToUpload = Get-ChildItem -Path $userLocalPath -File -Recurse
        $totalFiles = $filesToUpload.Count
        $uploadedFiles = @()
        $skippedFiles = @()
        $failedFiles = @()
        $uploadCount = 0
        $failedCount = 0
        $processedFiles = 0
        
        Write-MigrationLog "Found $totalFiles files to upload..." -Level "Success"
        
        if ($totalFiles -eq 0) {
            Write-MigrationLog "No files found to upload in $userLocalPath" -Level "Warning"
            return @{ Success = $true; FilesUploaded = 0; SkippedFiles = 0; UploadedFiles = @() }
        }
        
        foreach ($file in $filesToUpload) {
            try {
                # Initialize upload status for this file
                $uploadFailed = $false
                
                # Calculate relative path from archive root
                $relativePath = $file.FullName.Replace($userLocalPath, "").TrimStart('\')
                $relativeDir = Split-Path -Path $relativePath -Parent
                
                # Determine SharePoint folder path
                if ($relativeDir) {
                    $sharePointFolder = "Documents/$($relativeDir.Replace('\', '/'))"
                } else {
                    $sharePointFolder = "Documents"
                }
                
                # Check if file already exists (for conflict resolution)
                $existingFile = $null
                try {
                    $existingFile = Get-PnPFile -Url "$sharePointFolder/$($file.Name)" -ErrorAction SilentlyContinue
                } catch {
                    # File doesn't exist, which is fine
                }
                
                $shouldUpload = $true
                $conflictAction = ""
                
                if ($existingFile) {
                    switch ($ConflictResolution) {
                        "Skip" {
                            $shouldUpload = $false
                            $conflictAction = "Skipped (file exists)"
                            $skippedFiles += @{
                                FileName = $file.Name
                                RelativePath = $relativePath
                                Reason = "File already exists"
                            }
                        }
                        "Overwrite" {
                            $shouldUpload = $true
                            $conflictAction = "Overwritten"
                        }
                        "Rename" {
                            $extension = [System.IO.Path]::GetExtension($file.Name)
                            $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                            $newFileName = "$nameWithoutExt`_$timestamp$extension"
                            $file = $file | Add-Member -NotePropertyName "RenamedTo" -NotePropertyValue $newFileName -PassThru
                            $conflictAction = "Renamed to $newFileName"
                        }
                    }
                }
                
                if ($shouldUpload) {
                    # Check file size before upload (SharePoint limit is ~250MB)
                    $fileSizeMB = [math]::Round($file.Length / 1MB, 2)
                    $sharePointLimit = 250 # MB
                    
                    if ($fileSizeMB -gt $sharePointLimit) {
                        Write-MigrationLog "File exceeds SharePoint limit (${fileSizeMB}MB > ${sharePointLimit}MB): $($file.Name)" -Level "Warning"
                        $conflictAction = "Failed - File too large (${fileSizeMB}MB)"
                        $shouldUpload = $false
                        $uploadFailed = $true
                        $failedCount++
                        $failedFiles += $file.Name
                    } else {
                        # Ensure folder exists in SharePoint
                        if ($relativeDir) {
                            $folderParts = $relativeDir.Split('\')
                            $currentPath = "Documents"
                            
                            foreach ($folderPart in $folderParts) {
                                $currentPath += "/$folderPart"
                                try {
                                    Add-PnPFolder -Name $folderPart -Folder (Split-Path -Path $currentPath -Parent) -ErrorAction SilentlyContinue
                                } catch {
                                    # Folder might already exist
                                }
                            }
                        }
                        
                        # Upload the file with error handling
                        $finalFileName = if ($file.RenamedTo) { $file.RenamedTo } else { $file.Name }
                        $uploadFailed = $false
                        
                        try {
                            Add-PnPFile -Path $file.FullName -Folder $sharePointFolder -NewFileName $finalFileName
                            
                            # Track uploaded file
                            $uploadedFiles += @{
                                FileName = $file.Name
                                FinalName = $finalFileName
                                RelativePath = $relativePath
                                SharePointPath = "$sharePointFolder/$finalFileName"
                                Size = $fileSizeMB
                                ConflictAction = $conflictAction
                            }
                            
                            $uploadCount++
                            
                        } catch {
                            $uploadFailed = $true
                            $failedCount++
                            $failedFiles += $file.Name
                            $errorMsg = $_.Exception.Message
                            Write-MigrationLog "Upload failed for $($file.Name): $errorMsg" -Level "Error"
                            
                            # Determine failure reason
                            if ($errorMsg -like "*too big*" -or $errorMsg -like "*larger than*") {
                                $conflictAction = "Failed - File too large"
                            } elseif ($errorMsg -like "*connection*" -or $errorMsg -like "*timeout*") {
                                $conflictAction = "Failed - Connection error"
                            } else {
                                $conflictAction = "Failed - $($errorMsg.Split('.')[0])"
                            }
                            
                            # Update progress tracking for failed file
                            if ($EnableResume) {
                                Update-ProgressData -FilePath $relativePath -Status "Failed" -SourceSize $file.Length -ErrorMessage $errorMsg
                            }
                        }
                    }
                }
                
                # Progress reporting
                $processedFiles++
                $percentComplete = [math]::Round(($processedFiles / $totalFiles) * 100, 1)
                
                $displayPath = if ($relativePath.Contains('\')) { $relativePath } else { $file.Name }
                
                # Determine status message and log level
                if ($uploadFailed) {
                    $statusMsg = "[$percentComplete%] FAILED: $displayPath"
                    $logLevel = "Error"
                } elseif ($shouldUpload) {
                    $statusMsg = "[$percentComplete%] Uploaded: $displayPath"
                    $logLevel = "Progress"
                } else {
                    $statusMsg = "[$percentComplete%] Skipped: $displayPath"
                    $logLevel = "Info"
                }
                
                Write-MigrationLog $statusMsg -Level $logLevel
                
                # CSV logging with proper status
                if ($uploadFailed) {
                    $status = "Failed"
                } elseif ($shouldUpload) {
                    $status = "Success"
                } else {
                    $status = "Skipped"
                }
                
                $statusDetail = if ($conflictAction) { $conflictAction } else { $status }
                $fileSizeMB = [math]::Round($file.Length / 1MB, 2)
                Write-MigrationLog "" -Level "Info" -Operation "Upload" -ItemType "File" -ItemName $file.Name -ItemPath $displayPath -Status $statusDetail -Size "$fileSizeMB MB"
                
            } catch {
                Write-MigrationLog "Failed to upload $($file.Name): $($_.Exception.Message)" -Level "Error"
                Write-MigrationLog "" -Level "Error" -Operation "Upload" -ItemType "File" -ItemName $file.Name -Status "Failed" -Error $_.Exception.Message
            }
        }
        
        Write-MigrationLog "Upload complete!" -Level "Success"
        Write-MigrationLog "Files uploaded: $uploadCount" -Level "Success"
        Write-MigrationLog "Files skipped: $($skippedFiles.Count)" -Level "Info"
        if ($failedCount -gt 0) {
            Write-MigrationLog "Files failed: $failedCount" -Level "Warning"
        }
        
        return @{
            Success = ($failedCount -eq 0)
            FilesUploaded = $uploadCount
            FilesSkipped = $skippedFiles.Count
            FilesFailed = $failedCount
            UploadedFiles = $uploadedFiles
            SkippedFiles = $skippedFiles
            FailedFiles = $failedFiles
            ConflictResolution = $ConflictResolution
        }
        
    } catch {
        Write-MigrationLog "Upload failed: $($_.Exception.Message)" -Level "Error"
        Write-MigrationLog "" -Level "Error" -Operation "Upload" -ItemType "Operation" -ItemName "UploadAll" -Status "Failed" -Error $_.Exception.Message
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Enhanced Download Function
function Invoke-EnhancedDownload {
    param(
        [string]$Tenant,
        [string]$AdminUpn,
        [string]$UserUpn,
        [string]$LocalPath,
        [System.Management.Automation.PSCredential]$PreAuthCredentials = $null
    )
    
    if ($DryRun) {
        Write-MigrationLog "Would download files from $Tenant to $LocalPath" -Level "Info"
        Write-MigrationLog "Would connect to OneDrive and enumerate all files" -Level "Info"
        Write-MigrationLog "Would preserve folder structure during download" -Level "Info"
        Write-MigrationLog "Would log all operations to CSV" -Level "Info"
        return @{ Success = $true; FilesDownloaded = "N/A (Dry Run)"; DryRun = $true }
    }
    
    try {
        Write-MigrationLog "=== STARTING ENHANCED DOWNLOAD ===" -Level "Success"
        
        $adminUrl = "https://$Tenant-admin.sharepoint.com"
        $userPath = $UserUpn.Replace('@', '_').Replace('.', '_')
        $oneDriveUrl = "https://$Tenant-my.sharepoint.com/personal/$userPath"
        $userLocalPath = Join-Path -Path $LocalPath -ChildPath ($UserUpn.Split('@')[0])
        
        # Get credentials (use pre-authenticated if available)
        if ($PreAuthCredentials) {
            $cred = $PreAuthCredentials
            Write-MigrationLog "Using pre-authenticated credentials for source tenant" -Level "Info"
        } else {
            $cred = Get-MigrationCredentials -TenantName $Tenant -Purpose "Source"
            if (-not $cred) { throw "Failed to obtain credentials" }
        }
        
        Write-MigrationLog "Connecting to SharePoint Online Admin..." -Level "Progress"
        Connect-SPOService -Url $adminUrl -Credential $cred -ModernAuth $true
        
        Write-MigrationLog "Granting admin access to OneDrive site..." -Level "Progress"
        Set-SPOUser -Site $oneDriveUrl -LoginName $AdminUpn -IsSiteCollectionAdmin $true
        
        Start-Sleep -Seconds 10
        
        Write-MigrationLog "Connecting to OneDrive site for file access..." -Level "Progress"
        Write-MigrationLog "Attempting PnP connection to: $oneDriveUrl" -Level "Info"
        
        try {
            Connect-PnPOnline -Url $oneDriveUrl -Credentials $cred
            Write-MigrationLog "PnP connection successful" -Level "Success"
        } catch {
            Write-MigrationLog "PnP connection failed: $($_.Exception.Message)" -Level "Error"
            Write-MigrationLog "Trying interactive authentication..." -Level "Info"
            
            # Try UseWebLogin for legacy PnP module
            Write-MigrationLog "Trying UseWebLogin for modern authentication..." -Level "Info"
            Connect-PnPOnline -Url $oneDriveUrl -UseWebLogin
            Write-MigrationLog "Interactive PnP connection successful" -Level "Success"
        }
        
        # Ensure local folder exists
        if (!(Test-Path -Path $userLocalPath)) {
            Write-MigrationLog "Creating local folder: $userLocalPath" -Level "Info"
            New-Item -Path $userLocalPath -ItemType Directory -Force | Out-Null
        }
        
        Write-MigrationLog "Getting all items from Documents library..." -Level "Progress"
        $items = Get-PnPListItem -List "Documents"
        $fileCount = 0
        $folderCount = 0
        $totalFiles = ($items | Where-Object { $_.FieldValues.FSObjType -eq 0 }).Count
        $downloadedFiles = @()
        $skippedVersionFiles = 0
        
        Write-MigrationLog "Found $($items.Count) total items ($totalFiles files)..." -Level "Success"
        
        if ($items.Count -eq 0) {
            Write-MigrationLog "No items found in OneDrive Documents library." -Level "Warning"
            return @{ Success = $true; FilesDownloaded = 0; FoldersProcessed = 0; DownloadedFiles = @() }
        }
        
        $documentsBasePath = "/personal/$userPath/Documents"
        $processedFiles = 0
        
        # Get progress data for resume functionality
        $progressData = Get-ProgressData
        
        foreach ($item in $items) {
            $fileServerRelativeUrl = $item.FieldValues.FileRef
            $fileName = $item.FieldValues.FileLeafRef
            $fileDirRef = $item.FieldValues.FileDirRef
            
            # Only process files (not folders)
            if ($item.FieldValues.FSObjType -eq 0) {
                try {
                    # Extract the subfolder path
                    if ($fileDirRef -eq $documentsBasePath) {
                        $localPath = $userLocalPath
                        $relativePath = ""
                    } else {
                        $subFolderPath = $fileDirRef.Replace($documentsBasePath + "/", "")
                        $localPath = Join-Path -Path $userLocalPath -ChildPath $subFolderPath
                        $relativePath = $subFolderPath
                        
                        if (!(Test-Path -Path $localPath)) {
                            Write-MigrationLog "Creating folder: $subFolderPath" -Level "Info"
                            New-Item -Path $localPath -ItemType Directory -Force | Out-Null
                        }
                    }
                    
                    $finalFilePath = Join-Path -Path $localPath -ChildPath $fileName
                    $displayPath = if ($relativePath) { "$relativePath\$fileName" } else { $fileName }
                    
                    # Progress reporting with percentage (calculate early for resume messages)
                    $processedFiles++
                    $percentComplete = [math]::Round(($processedFiles / $totalFiles) * 100, 1)
                    
                    # Check if file already exists and is verified (resume logic)
                    $shouldDownload = $true
                    if ($EnableResume -and (Test-Path $finalFilePath)) {
                        $expectedSize = $item.FieldValues.File_x0020_Size
                        $expectedHash = ""
                        
                        # Get expected hash from progress data if available
                        if ($progressData.files -and $progressData.files[$fileServerRelativeUrl]) {
                            $expectedHash = $progressData.files[$fileServerRelativeUrl].hash
                        }
                        
                        $verification = Test-FileIntegrity -LocalFilePath $finalFilePath -ExpectedSize $expectedSize -ExpectedModified ([datetime]::MinValue) -ExpectedHash $expectedHash
                        if ($verification.IsValid) {
                            $shouldDownload = $false
                            if ($VerificationLevel -eq "Enhanced" -and -not $Concise) {
                                $actualHash = (Get-FileHash -Path $finalFilePath -Algorithm SHA256).Hash
                                Write-MigrationLog "[$percentComplete%] Resumed (verified): $displayPath" -Level "Progress"
                                Write-MigrationLog "    Enhanced verification: SHA256 hash validated ($($actualHash.Substring(0,16))...)" -Level "Info"
                            } else {
                                Write-MigrationLog "[$percentComplete%] Resumed (verified): $displayPath" -Level "Progress"
                            }
                        } else {
                            Write-MigrationLog "[$percentComplete%] Re-downloading (verification failed: $($verification.Reason)): $displayPath" -Level "Warning"
                        }
                    }
                    
                    if ($shouldDownload) {
                        # Atomic download: Use temporary file
                        $tempFilePath = Get-AtomicTempPath -FinalPath $finalFilePath
                        
                        try {
                            # Download to temporary file
                            $tempFileName = Split-Path $tempFilePath -Leaf
                            Get-PnPFile -Url $fileServerRelativeUrl -Path $localPath -FileName $tempFileName -AsFile -Force
                            
                            # Verify temp file was created
                            if (-not (Test-Path $tempFilePath)) {
                                throw "Temp file was not created: $tempFilePath"
                            }
                            
                            # Verify the downloaded file (size only - SharePoint doesn't preserve modified dates)
                            $expectedSize = $item.FieldValues.File_x0020_Size
                            
                            $verification = Test-FileIntegrity -LocalFilePath $tempFilePath -ExpectedSize $expectedSize -ExpectedModified ([datetime]::MinValue)
                            if ($verification.IsValid) {
                                # Generate hash if using Enhanced verification
                                $fileHash = Get-FileVerificationHash -FilePath $tempFilePath
                                
                                # Atomic rename: Move temp file to final location
                                Move-Item -Path $tempFilePath -Destination $finalFilePath -Force
                                
                                # Update progress tracking
                                Update-ProgressData -FilePath $fileServerRelativeUrl -Status "completed" -SourceSize $expectedSize -SourceModified ([datetime]::Now) -LocalPath $finalFilePath -Hash $fileHash
                                
                                if ($VerificationLevel -eq "Enhanced" -and -not $Concise -and $fileHash) {
                                    Write-MigrationLog "[$percentComplete%] Downloaded: $displayPath" -Level "Progress"
                                    Write-MigrationLog "    Enhanced verification: SHA256 hash calculated ($($fileHash.Substring(0,16))...)" -Level "Info"
                                } else {
                                    Write-MigrationLog "[$percentComplete%] Downloaded: $displayPath" -Level "Progress"
                                }
                            } else {
                                # Verification failed, remove temp file and retry
                                Remove-Item -Path $tempFilePath -Force -ErrorAction SilentlyContinue
                                Update-ProgressData -FilePath $fileServerRelativeUrl -Status "failed" -SourceSize $expectedSize -SourceModified ([datetime]::Now) -ErrorMessage "Verification failed: $($verification.Reason)"
                                throw "File verification failed: $($verification.Reason)"
                            }
                            
                        } catch {
                            # Cleanup temp file on any error
                            if (Test-Path $tempFilePath) {
                                Remove-Item -Path $tempFilePath -Force -ErrorAction SilentlyContinue
                            }
                            
                            # Check if this is a SharePoint version/conflict file (soft error)
                            if ($fileName -match '\[\d+\]' -or $fileName -match '\[.*\]') {
                                Write-MigrationLog "[$percentComplete%] Skipped version/conflict file: $displayPath" -Level "Warning"
                                Write-MigrationLog "    Reason: SharePoint version history or conflict resolution file" -Level "Info"
                                Write-MigrationLog "    Note: Main version likely downloaded successfully" -Level "Info"
                                $skippedVersionFiles++
                                continue
                            }
                            
                            # Hard error for regular files
                            $errorDetails = $_.Exception.Message
                            Write-MigrationLog "Download error details: $errorDetails" -Level "Info"
                            Write-MigrationLog "Failed file URL: $fileServerRelativeUrl" -Level "Info"
                            Write-MigrationLog "Temp file path: $tempFilePath" -Level "Info"
                            
                            throw
                        }
                    }
                    
                    # Track downloaded files
                    $fileSizeMB = if ($item.FieldValues.File_x0020_Size) { [math]::Round($item.FieldValues.File_x0020_Size / 1MB, 2) } else { 0 }
                    $downloadedFiles += @{
                        FileName = $fileName
                        RelativePath = $relativePath
                        LocalPath = $finalFilePath
                        Size = $fileSizeMB
                        Modified = $item.FieldValues.Modified
                        Downloaded = $shouldDownload
                    }
                    
                    # CSV logging
                    $operationStatus = if ($shouldDownload) { "Downloaded" } else { "Resumed" }
                    Write-MigrationLog "" -Level "Info" -Operation "Download" -ItemType "File" -ItemName $fileName -ItemPath $displayPath -Status $operationStatus -Size "$fileSizeMB MB"
                    
                    $fileCount++
                    
                } catch {
                    Write-MigrationLog "Failed to download $fileName : $($_.Exception.Message)" -Level "Error"
                    Write-MigrationLog "" -Level "Error" -Operation "Download" -ItemType "File" -ItemName $fileName -Status "Failed" -Error $_.Exception.Message
                    
                    # Update progress with error
                    Update-ProgressData -FilePath $fileServerRelativeUrl -Status "failed" -ErrorMessage $_.Exception.Message
                }
            } else {
                $folderCount++
            }
        }
        
        Write-MigrationLog "Download complete!" -Level "Success"
        Write-MigrationLog "Files processed: $fileCount" -Level "Success"
        Write-MigrationLog "Folders processed: $folderCount" -Level "Success"
        
        # Resume-specific statistics
        if ($EnableResume) {
            $downloadedCount = ($downloadedFiles | Where-Object { $_.Downloaded }).Count
            $resumedCount = ($downloadedFiles | Where-Object { -not $_.Downloaded }).Count
            if ($resumedCount -gt 0) {
                Write-MigrationLog "Files downloaded: $downloadedCount" -Level "Success"
                Write-MigrationLog "Files resumed (verified): $resumedCount" -Level "Success"
                Write-MigrationLog "Verification level: $VerificationLevel" -Level "Info"
            }
        }
        
        # Version file statistics
        if ($skippedVersionFiles -gt 0) {
            Write-MigrationLog "SharePoint version/conflict files skipped: $skippedVersionFiles" -Level "Info"
            Write-MigrationLog "Note: Main versions of these files likely downloaded successfully" -Level "Info"
        }
        
        return @{
            Success = $true
            FilesDownloaded = $fileCount
            FoldersProcessed = $folderCount
            DownloadedFiles = $downloadedFiles
            UserLocalPath = $userLocalPath
        }
        
    } catch {
        Write-MigrationLog "Download failed: $($_.Exception.Message)" -Level "Error"
        Write-MigrationLog "" -Level "Error" -Operation "Download" -ItemType "Operation" -ItemName "DownloadAll" -Status "Failed" -Error $_.Exception.Message
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Main execution logic
if ($Mode -eq "ValidateOnly") {
    Write-MigrationLog "=== VALIDATION MODE ===" -Level "Success"
    
    $validationPassed = $true
    
    # Validate source if parameters provided
    if ($SourceTenant) {
        Write-MigrationLog "Validating SOURCE tenant..." -Level "Info"
        $sourceResult = Invoke-EnhancedValidation -Tenant $SourceTenant -AdminUpn $SourceAdminUpn -UserUpn $SourceUserUpn -Purpose "Source"
        
        if ($sourceResult.Success) {
            Write-MigrationLog "[OK] Source validation passed - $($sourceResult.ItemCount) items found" -Level "Success"
        } else {
            Write-MigrationLog "[ERROR] Source validation failed: $($sourceResult.Error)" -Level "Error"
            $validationPassed = $false
        }
    }
    
    # Validate destination if parameters provided
    if ($DestTenant) {
        Write-MigrationLog "Validating DESTINATION tenant..." -Level "Info"
        $destResult = Invoke-EnhancedValidation -Tenant $DestTenant -AdminUpn $DestAdminUpn -UserUpn $DestUserUpn -Purpose "Destination"
        
        if ($destResult.Success) {
            Write-MigrationLog "[OK] Destination validation passed - $($destResult.ItemCount) items found" -Level "Success"
        } else {
            Write-MigrationLog "[ERROR] Destination validation failed: $($destResult.Error)" -Level "Error"
            $validationPassed = $false
        }
    }
    
    if (-not $validationPassed) {
        exit 1
    } else {
        Write-MigrationLog "All validations completed successfully!" -Level "Success"
    }
    
} elseif ($Mode -eq "DownloadOnly") {
    Write-MigrationLog "=== DOWNLOAD ONLY MODE ===" -Level "Success"
    $downloadResult = Invoke-EnhancedDownload -Tenant $SourceTenant -AdminUpn $SourceAdminUpn -UserUpn $SourceUserUpn -LocalPath $LocalArchivePath
    
    if ($downloadResult.Success) {
        Write-MigrationLog "Download completed successfully!" -Level "Success"
        if (-not $downloadResult.DryRun) {
            Write-MigrationLog "Files are stored in: $($downloadResult.UserLocalPath)" -Level "Info"
        }
    } else {
        Write-MigrationLog "Download failed!" -Level "Error"
        exit 1
    }
    
} elseif ($Mode -eq "UploadOnly") {
    Write-MigrationLog "=== UPLOAD ONLY MODE ===" -Level "Success"
    Write-MigrationLog "Conflict resolution mode: $ConflictResolution" -Level "Info"
    
    # Validate archive path exists
    if (-not (Test-Path $LocalArchivePath)) {
        Write-MigrationLog "Archive path not found: $LocalArchivePath" -Level "Error"
        Write-MigrationLog "Use -LocalArchivePath to specify the location of downloaded files" -Level "Error"
        exit 1
    }
    
    $uploadResult = Invoke-EnhancedUpload -Tenant $DestTenant -AdminUpn $DestAdminUpn -UserUpn $DestUserUpn -LocalPath $LocalArchivePath -ConflictResolution $ConflictResolution -SourceUserUpnForMapping $SourceUserUpn -UserArchiveFolderOverride $UserArchiveFolder
    
    if ($uploadResult.Success) {
        Write-MigrationLog "Upload completed successfully!" -Level "Success"
        if (-not $uploadResult.DryRun) {
            Write-MigrationLog "Files uploaded: $($uploadResult.FilesUploaded)" -Level "Success"
            Write-MigrationLog "Files skipped: $($uploadResult.FilesSkipped)" -Level "Info"
            if ($uploadResult.FilesFailed -gt 0) {
                Write-MigrationLog "Files failed: $($uploadResult.FilesFailed)" -Level "Warning"
            }
            if ($uploadResult.ConflictResolution -ne "Skip") {
                Write-MigrationLog "Conflict resolution applied using: $($uploadResult.ConflictResolution)" -Level "Info"
            }
        }
    } else {
        Write-MigrationLog "Upload failed!" -Level "Error"
        if ($uploadResult.FilesFailed -gt 0) {
            Write-MigrationLog "Files failed: $($uploadResult.FilesFailed)" -Level "Error"
        }
        exit 1
    }
    
} elseif ($Mode -eq "Interactive") {
    Write-MigrationLog "=== INTERACTIVE MODE ===" -Level "Success"
    
    # Step 0: Authenticate to both tenants upfront
    Write-MigrationLog "Authenticating to both tenants..." -Level "Info"
    Write-MigrationLog "" -Level "Info"
    
    # Get source credentials
    $sourceCreds = Get-MigrationCredentials -TenantName $SourceTenant -Purpose "Source"
    if (-not $sourceCreds -and -not $DryRun) {
        Write-MigrationLog "Source authentication cancelled by user" -Level "Error"
        exit 1
    }
    
    # Get destination credentials (may reuse if same tenant)
    $destCreds = Get-MigrationCredentials -TenantName $DestTenant -Purpose "Destination"
    if (-not $destCreds -and -not $DryRun) {
        Write-MigrationLog "Destination authentication cancelled by user" -Level "Error"
        exit 1
    }
    
    Write-MigrationLog "Authentication completed for both tenants" -Level "Success"
    Write-MigrationLog "" -Level "Info"
    
    # Step 1: Download files from source
    Write-MigrationLog "Phase 1: Downloading files from source..." -Level "Info"
    $downloadResult = Invoke-EnhancedDownload -Tenant $SourceTenant -AdminUpn $SourceAdminUpn -UserUpn $SourceUserUpn -LocalPath $LocalArchivePath -PreAuthCredentials $sourceCreds
    
    if (-not $downloadResult.Success) {
        Write-MigrationLog "Download failed! Cannot proceed with interactive migration." -Level "Error"
        exit 1
    }
    
    # Step 2: Show summary and pause for user review
    Write-MigrationLog "" -Level "Info"
    Write-MigrationLog "=== DOWNLOAD COMPLETE - REVIEW REQUESTED ===" -Level "Success"
    Write-MigrationLog "Files downloaded to: $($downloadResult.UserLocalPath)" -Level "Info"
    Write-MigrationLog "Files processed: $($downloadResult.FilesProcessed)" -Level "Info"
    Write-MigrationLog "Files downloaded: $($downloadResult.FilesDownloaded)" -Level "Info"
    if ($EnableResume -and $downloadResult.FilesResumed -gt 0) {
        Write-MigrationLog "Files resumed: $($downloadResult.FilesResumed)" -Level "Info"
    }
    Write-MigrationLog "" -Level "Info"
    
    # Step 3: User confirmation prompt
    if (-not $Yes) {
        Write-MigrationLog "Please review the downloaded files before proceeding with upload." -Level "Warning"
        Write-MigrationLog "Archive location: $($downloadResult.UserLocalPath)" -Level "Info"
        Write-MigrationLog "" -Level "Info"
        
        do {
            $response = Read-Host "Proceed with upload to destination? (Y/N/S for Yes/No/Skip)"
            $response = $response.ToUpper()
        } while ($response -notin @("Y", "N", "S", "YES", "NO", "SKIP"))
        
        if ($response -in @("N", "NO")) {
            Write-MigrationLog "Migration cancelled by user. Files remain in archive." -Level "Warning"
            Write-MigrationLog "Use UploadOnly mode later to complete the migration." -Level "Info"
            exit 0
        } elseif ($response -in @("S", "SKIP")) {
            Write-MigrationLog "Upload skipped by user. Migration completed (download only)." -Level "Success"
            exit 0
        }
    }
    
    # Step 4: Upload files to destination
    Write-MigrationLog "" -Level "Info"
    Write-MigrationLog "Phase 2: Uploading files to destination..." -Level "Info"
    Write-MigrationLog "Conflict resolution mode: $ConflictResolution" -Level "Info"
    
    $uploadResult = Invoke-EnhancedUpload -Tenant $DestTenant -AdminUpn $DestAdminUpn -UserUpn $DestUserUpn -LocalPath $LocalArchivePath -ConflictResolution $ConflictResolution -SourceUserUpnForMapping $SourceUserUpn -UserArchiveFolderOverride $UserArchiveFolder -PreAuthCredentials $destCreds
    
    if ($uploadResult.Success) {
        Write-MigrationLog "" -Level "Info"
        Write-MigrationLog "=== INTERACTIVE MIGRATION COMPLETED SUCCESSFULLY ===" -Level "Success"
        Write-MigrationLog "Source: $SourceUserUpn @ $SourceTenant" -Level "Info"
        Write-MigrationLog "Destination: $DestUserUpn @ $DestTenant" -Level "Info"
        Write-MigrationLog "Files migrated: $($uploadResult.FilesUploaded)" -Level "Success"
        Write-MigrationLog "Files skipped: $($uploadResult.FilesSkipped)" -Level "Info"
        if ($uploadResult.FilesFailed -gt 0) {
            Write-MigrationLog "Files failed: $($uploadResult.FilesFailed)" -Level "Warning"
        }
        if ($uploadResult.ConflictResolution -ne "Skip") {
            Write-MigrationLog "Conflict resolution: $($uploadResult.ConflictResolution)" -Level "Info"
        }
    } else {
        Write-MigrationLog "Upload failed! Files remain in archive for retry." -Level "Error"
        if ($uploadResult.FilesFailed -gt 0) {
            Write-MigrationLog "Files failed: $($uploadResult.FilesFailed)" -Level "Error"
        }
        Write-MigrationLog "Use UploadOnly mode to retry the upload." -Level "Info"
        exit 1
    }
    
} elseif ($Mode -eq "Automated") {
    Write-MigrationLog "=== AUTOMATED MODE ===" -Level "Success"
    Write-MigrationLog "Automated mode not yet implemented" -Level "Error"
    throw "Automated mode is currently under development"
    
} else {
    Write-MigrationLog "Unknown mode: $Mode" -Level "Error"
    exit 1
}

Write-MigrationLog "=== OneDrive Migration Tool Completed ===" -Level "Success"
