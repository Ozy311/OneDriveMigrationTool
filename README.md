# OneDrive Migration Tool - Enterprise Edition

<!-- Author: Ozy -->

A comprehensive PowerShell tool for OneDrive tenant-to-tenant migrations with enterprise-grade logging, validation, and progress tracking.

## 🚀 Key Features

- **Multiple Operation Modes**: Interactive, download-only, upload-only, validation, and automated migrations
- **Enterprise Reliability**: Resume capability for interrupted transfers with file integrity verification
- **Comprehensive Logging**: Structured CSV audit logs for compliance and troubleshooting
- **Conflict Resolution**: Configurable handling of existing files (Skip/Overwrite/Rename)
- **Progress Tracking**: Real-time progress indicators with percentage completion
- **File Integrity**: Basic (size) and Enhanced (SHA256 hash) verification options
- **Dry Run Mode**: Plan migrations without executing actual transfers
- **User Mapping**: Support for different usernames between source and destination tenants
- **Error Handling**: Graceful handling of large files (>250MB) with clear logging
- **PowerShell 5.1 Compatible**: Designed for maximum enterprise compatibility

## 📋 Prerequisites

- **PowerShell 5.1 or higher** (PowerShell 7+ also supported)
- **Internet connectivity**
- **SharePoint Online admin permissions** on both source and destination tenants
- **Required PowerShell modules** (auto-installed):
  - `Microsoft.Online.SharePoint.PowerShell`
  - `SharePointPnPPowerShellOnline`

## 🛠️ Installation

1. **Download the script**:
   ```powershell
   # Clone the repository
   git clone https://github.com/Ozy311/OneDriveMigration.git
   cd OneDriveMigration
   ```

2. **Set execution policy** (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Run initial setup**:
   ```powershell
   # The script will automatically install required modules on first run
   .\OneDriveMigration.ps1 -Help
   ```

## 📖 Usage Examples

### Interactive Migration (Recommended)
Complete migration with human oversight and confirmation:
```powershell
.\OneDriveMigration.ps1 -Mode Interactive `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.doe@fabrikam.onmicrosoft.com"
```

### Download Only (Backup)
Create a local backup of OneDrive files:
```powershell
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -LocalArchivePath "C:\Backups\JohnDoe" `
  -EnableResume -VerificationLevel Enhanced
```

### Upload Only (Restore)
Restore files from a local backup:
```powershell
.\OneDriveMigration.ps1 -Mode UploadOnly `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.doe@fabrikam.onmicrosoft.com" `
  -LocalArchivePath "C:\Backups\JohnDoe" `
  -ConflictResolution Rename
```

### Validation Only
Test connections and permissions without transferring files:
```powershell
# Test source tenant
.\OneDriveMigration.ps1 -Mode ValidateOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com"

# Test destination tenant
.\OneDriveMigration.ps1 -Mode ValidateOnly `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.doe@fabrikam.onmicrosoft.com"
```

### User Mapping (Different Usernames)
Migrate when source and destination usernames differ:
```powershell
.\OneDriveMigration.ps1 -Mode UploadOnly `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.smith@fabrikam.onmicrosoft.com" `
  -LocalArchivePath "C:\Migration\Archive" `
  -UserArchiveFolder "john.doe" `
  -ConflictResolution Skip
```

### Automated Migration
Hands-off migration for scripted environments:
```powershell
.\OneDriveMigration.ps1 -Mode Automated `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "john.doe@fabrikam.onmicrosoft.com" `
  -Yes -Concise
```

### Dry Run (Planning)
See what would be migrated without actually transferring files:
```powershell
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "john.doe@contoso.onmicrosoft.com" `
  -DryRun
```

## 🔧 Parameters Reference

### Required Parameters (by Mode)

| Parameter | Interactive | DownloadOnly | UploadOnly | ValidateOnly | Automated |
|-----------|-------------|--------------|------------|--------------|-----------|
| `SourceTenant` | ✅ | ✅ | ❌ | Optional | ✅ |
| `SourceAdminUpn` | ✅ | ✅ | ❌ | Optional | ✅ |
| `SourceUserUpn` | ✅ | ✅ | ❌ | Optional | ✅ |
| `DestTenant` | ✅ | ❌ | ✅ | Optional | ✅ |
| `DestAdminUpn` | ✅ | ❌ | ✅ | Optional | ✅ |
| `DestUserUpn` | ✅ | ❌ | ✅ | Optional | ✅ |
| `LocalArchivePath` | Optional | Optional | ✅ | ❌ | Optional |

### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `LocalArchivePath` | Local storage path for files | `.\Migration_yyyyMMdd_HHmmss` | `C:\Migrations\Archive` |
| `ConflictResolution` | How to handle existing files | `Skip` | `Skip\|Overwrite\|Rename` |
| `VerificationLevel` | File integrity verification | `Basic` | `Basic\|Enhanced` |
| `LogFile` | Custom CSV log file path | Auto-generated | `C:\Logs\migration.csv` |
| `UserArchiveFolder` | Specific user folder in archive | Auto-detected | `john.doe` |
| `EnableResume` | Enable resume capability | `False` | Switch parameter |
| `Yes` | Skip confirmation prompts | `False` | Switch parameter |
| `Concise` | Reduce verbose output | `False` | Switch parameter |
| `DryRun` | Show actions without executing | `False` | Switch parameter |

## 📊 Operation Modes

### Interactive Mode (Default)
1. **Downloads** files from source tenant
2. **Pauses** for user review and confirmation
3. **Uploads** files to destination tenant
4. **Provides** detailed progress and results

### DownloadOnly Mode
- Creates local backup of OneDrive files
- Preserves folder structure
- Supports resume for interrupted downloads
- Ideal for creating archive copies

### UploadOnly Mode
- Restores files from local archive
- Configurable conflict resolution
- User mapping support for different usernames
- Resume capability for failed uploads

### ValidateOnly Mode
- Tests admin permissions and connectivity
- Validates OneDrive access
- Lists file counts for planning
- No file transfers performed

### Automated Mode
- Complete migration without user interaction
- Suitable for scripted environments
- Requires `-Yes` parameter for safety
- Use `-Concise` to minimize output

## 🔒 File Integrity & Resume

### Verification Levels

**Basic Verification (Default)**:
- File size comparison
- Fast and reliable for most use cases

**Enhanced Verification**:
- File size + SHA256 hash comparison
- Slower but provides cryptographic integrity
- Recommended for critical data migrations

### Resume Capability

Enable with `-EnableResume` parameter:
- **Atomic Operations**: Files downloaded to temporary names, renamed when complete
- **Progress Tracking**: JSON file tracks completion status per file
- **Integrity Checks**: Verifies existing files before skipping
- **Graceful Recovery**: Continues from where previous run left off

Example resume session:
```powershell
# Initial run (interrupted)
.\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "user@contoso.onmicrosoft.com" -EnableResume

# Resume from interruption
.\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "user@contoso.onmicrosoft.com" -EnableResume
```

## 📈 Logging & Auditing

### CSV Audit Logs
Every operation is logged to structured CSV files containing:
- **Timestamp**: When the operation occurred
- **Operation**: Download/Upload/Validation
- **Item Type**: File/Folder/Operation
- **Item Name**: File or folder name
- **Item Path**: Full path information
- **Status**: Success/Failed/Skipped
- **Size**: File size in MB
- **Error Details**: Failure reasons (if applicable)

### Log File Locations
- **Default**: `.\Migration_yyyyMMdd_HHmmss\Migration_Log_yyyyMMdd_HHmmss.csv`
- **Custom**: Specify with `-LogFile` parameter

### Progress Tracking
- **Real-time**: Percentage completion and transfer rates
- **Resume Data**: `Migration_Progress_SessionId.json` for resume capability
- **Detailed Output**: File-by-file status unless `-Concise` is used

## ⚠️ Known Limitations

1. **File Size Limit**: Individual files larger than 250MB will be logged as failures
   - This is a SharePoint REST API limitation
   - Large files are clearly identified in logs
   - Main migration is not affected (796/799 files typically succeed)

2. **SharePoint Versioning**: Version history is not migrated
   - Only current versions of files are transferred
   - Conflict resolution files are skipped with warnings

3. **Permissions**: File-level permissions are not preserved
   - Destination permissions inherit from OneDrive settings
   - Admin must configure sharing permissions post-migration

4. **Metadata**: Some file metadata may not be preserved
   - Creation/modification dates may change during transfer
   - Enhanced verification uses file content, not metadata

## 🔧 Troubleshooting

### Common Issues

**Authentication Failures**:
```
Error: The sign-in name or password does not match
```
- Verify admin credentials are correct
- Ensure admin has SharePoint Online permissions
- Check if MFA/Conditional Access is interfering

**Connection Timeouts**:
```
Error: Connection timeout or network error
```
- Check internet connectivity
- Verify SharePoint URLs are accessible
- Try using `-Concise` mode to reduce output overhead

**Module Installation Issues**:
```
Error: Failed to install required modules
```
- Run PowerShell as Administrator
- Manually install modules:
  ```powershell
  Install-Module Microsoft.Online.SharePoint.PowerShell -Force
  Install-Module SharePointPnPPowerShellOnline -Force -SkipPublisherCheck
  ```

**Large File Warnings**:
```
Warning: File exceeds SharePoint limit (277MB > 250MB)
```
- This is expected behavior for files >250MB
- Files are logged as failed but don't affect overall migration
- Consider alternative methods for very large files

### Getting Help

1. **Built-in Help**:
   ```powershell
   .\OneDriveMigration.ps1 -Help
   ```

2. **Validation Mode**: Test connections before full migration
3. **Dry Run Mode**: Preview operations without executing
4. **Log Files**: Check CSV logs for detailed error information

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with appropriate tests
4. Submit a pull request with detailed description

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for enterprise SharePoint Online migrations
- Tested with real-world tenant-to-tenant scenarios
- Designed for reliability and audit compliance

---

**⭐ If this tool helped with your OneDrive migration, please star the repository!**