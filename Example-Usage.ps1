# Author: Ozy
# OneDrive Migration Tool - Usage Examples
# This file contains practical examples of how to use the OneDrive Migration Tool

Write-Host @"
=================================================================
        OneDrive Migration Tool - Usage Examples
=================================================================
"@ -ForegroundColor Cyan

Write-Host "`n1. HELP & GETTING STARTED" -ForegroundColor Yellow
Write-Host "# Show comprehensive help with all parameters and examples"
Write-Host '.\OneDriveMigration.ps1 -Help' -ForegroundColor Green

Write-Host "`n2. VALIDATION (Always run this first!)" -ForegroundColor Yellow
Write-Host "# Test source tenant connection and permissions"
Write-Host @'
.\OneDriveMigration.ps1 -Mode ValidateOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com"
'@ -ForegroundColor Green

Write-Host "`n3. DRY RUN (Preview operations)" -ForegroundColor Yellow
Write-Host "# See what would be downloaded without actually doing it"
Write-Host @'
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -DryRun
'@ -ForegroundColor Green

Write-Host "`n4. DOWNLOAD ONLY (Backup)" -ForegroundColor Yellow
Write-Host "# Download all files to local archive with folder structure preserved"
Write-Host @'
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -LocalArchivePath "C:\Migration\JohnDoe-Backup"
'@ -ForegroundColor Green

Write-Host "`n5. DOWNLOAD WITH CUSTOM LOGGING" -ForegroundColor Yellow
Write-Host "# Custom log file location and concise output"
Write-Host @'
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -LocalArchivePath "C:\Migration\JohnDoe" `
  -LogFile "C:\Logs\Migration-JohnDoe.csv" `
  -Concise
'@ -ForegroundColor Green

Write-Host "`n6. INTERACTIVE MIGRATION (Default - Phase 3)" -ForegroundColor Yellow
Write-Host "# Full migration with user review between download and upload"
Write-Host @'
.\OneDriveMigration.ps1 `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "jdoe@fabrikam.onmicrosoft.com"
'@ -ForegroundColor Green

Write-Host "`n7. UPLOAD ONLY (Phase 2 - Coming Soon)" -ForegroundColor Yellow
Write-Host "# Restore from local archive to destination tenant"
Write-Host @'
.\OneDriveMigration.ps1 -Mode UploadOnly `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "jdoe@fabrikam.onmicrosoft.com" `
  -LocalArchivePath "C:\Migration\JohnDoe-Backup" `
  -ConflictResolution Rename
'@ -ForegroundColor Green

Write-Host "`n8. AUTOMATED MIGRATION (Phase 4 - Coming Soon)" -ForegroundColor Yellow
Write-Host "# Full migration without user interaction (for scripting)"
Write-Host @'
.\OneDriveMigration.ps1 -Mode Automated `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -DestTenant "fabrikam" `
  -DestAdminUpn "admin@fabrikam.com" `
  -DestUserUpn "jdoe@fabrikam.onmicrosoft.com" `
  -Yes -Concise
'@ -ForegroundColor Green

Write-Host "`n9. BULK MIGRATION SCRIPT EXAMPLE" -ForegroundColor Yellow
Write-Host "# Example of scripting multiple user migrations"
Write-Host @'
# Create a CSV with user mappings: source_user,dest_user
$users = Import-Csv "user_mappings.csv"

foreach ($user in $users) {
    Write-Host "Migrating $($user.source_user)..." -ForegroundColor Cyan
    
    # Download phase
    .\OneDriveMigration.ps1 -Mode DownloadOnly `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $user.source_user `
      -LocalArchivePath "C:\Migration\$($user.source_user.Split('@')[0])"
    
    # Upload phase (when Phase 2 is complete)
    # .\OneDriveMigration.ps1 -Mode UploadOnly `
    #   -DestTenant "fabrikam" `
    #   -DestAdminUpn "admin@fabrikam.com" `
    #   -DestUserUpn $user.dest_user `
    #   -LocalArchivePath "C:\Migration\$($user.source_user.Split('@')[0])" `
    #   -Yes
}
'@ -ForegroundColor Green

Write-Host "`n10. TROUBLESHOOTING EXAMPLES" -ForegroundColor Yellow
Write-Host "# If you encounter issues, try these diagnostic steps:"
Write-Host ""
Write-Host "# A) Test credentials only" -ForegroundColor Cyan
Write-Host @'
.\OneDriveMigration.ps1 -Mode ValidateOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -DryRun
'@ -ForegroundColor Green

Write-Host ""
Write-Host "# B) Check PowerShell version compatibility" -ForegroundColor Cyan
Write-Host @'
# If running PowerShell 7 and having issues, use PS 5.1:
powershell.exe -File "OneDriveMigration.ps1" -Mode ValidateOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com"
'@ -ForegroundColor Green

Write-Host ""
Write-Host "# C) Test with minimal parameters" -ForegroundColor Cyan
Write-Host @'
.\OneDriveMigration.ps1 -Mode DownloadOnly `
  -SourceTenant "contoso" `
  -SourceAdminUpn "admin@contoso.com" `
  -SourceUserUpn "jdoe@contoso.onmicrosoft.com" `
  -DryRun -Concise
'@ -ForegroundColor Green

Write-Host "`n11. REAL-WORLD WORKFLOW EXAMPLE" -ForegroundColor Yellow
Write-Host @'
# Step 1: Validate source tenant
.\OneDriveMigration.ps1 -Mode ValidateOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "jdoe@contoso.onmicrosoft.com"

# Step 2: Preview download (dry run)
.\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "jdoe@contoso.onmicrosoft.com" -DryRun

# Step 3: Perform actual download
.\OneDriveMigration.ps1 -Mode DownloadOnly -SourceTenant "contoso" -SourceAdminUpn "admin@contoso.com" -SourceUserUpn "jdoe@contoso.onmicrosoft.com"

# Step 4: Review downloaded files in local archive
# [Manual file review step]

# Step 5: Upload to destination (Phase 2)
# .\OneDriveMigration.ps1 -Mode UploadOnly -DestTenant "fabrikam" -DestAdminUpn "admin@fabrikam.com" -DestUserUpn "jdoe@fabrikam.onmicrosoft.com" -LocalArchivePath ".\Migration_YYYYMMDD_HHMMSS"
'@ -ForegroundColor Green

Write-Host "`n=================================================================`n" -ForegroundColor Cyan

Write-Host "CURRENT STATUS:" -ForegroundColor Yellow
Write-Host "✅ Phase 1 Complete: Enhanced download with logging & validation" -ForegroundColor Green
Write-Host "🔄 Phase 2 In Development: Upload functionality" -ForegroundColor Yellow
Write-Host "📋 Phase 3 Planned: Interactive workflow" -ForegroundColor Cyan
Write-Host "📋 Phase 4 Planned: Full automation" -ForegroundColor Cyan