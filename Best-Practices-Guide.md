# OneDrive Migration Tool - Best Practices Guide

## Overview

This guide provides advanced usage examples, enterprise best practices, performance optimization strategies, and real-world migration scenarios for the OneDrive Migration Tool.

## Table of Contents

1. [Migration Planning and Strategy](#migration-planning-and-strategy)
2. [Enterprise Deployment Patterns](#enterprise-deployment-patterns)
3. [Performance Optimization](#performance-optimization)
4. [Security and Compliance](#security-and-compliance)
5. [Bulk Migration Strategies](#bulk-migration-strategies)
6. [Error Recovery and Resilience](#error-recovery-and-resilience)
7. [Monitoring and Reporting](#monitoring-and-reporting)
8. [Advanced Scenarios](#advanced-scenarios)
9. [Automation and Scripting](#automation-and-scripting)
10. [Post-Migration Validation](#post-migration-validation)

## Migration Planning and Strategy

### Pre-Migration Assessment

#### 1. Tenant Analysis
```powershell
# Analyze source tenant capacity and user distribution
$users = @("user1@contoso.com", "user2@contoso.com", "user3@contoso.com")

foreach ($user in $users) {
    Write-Host "Analyzing $user..." -ForegroundColor Cyan
    
    # Validation provides file counts
    $validation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $user
    
    if ($validation.Success) {
        [PSCustomObject]@{
            User = $user
            TotalItems = $validation.ItemCount
            Files = $validation.FileCount
            EstimatedSizeMB = $validation.FileCount * 2.5  # Rough estimate
        }
    }
} | Export-Csv "TenantAnalysis.csv" -NoTypeInformation
```

#### 2. Network and Infrastructure Planning
```powershell
# Test network performance to both tenants
$sourceTest = Measure-Command { 
    Test-NetConnection -ComputerName "contoso.sharepoint.com" -Port 443 
}
$destTest = Measure-Command { 
    Test-NetConnection -ComputerName "fabrikam.sharepoint.com" -Port 443 
}

Write-Host "Source connectivity: $($sourceTest.TotalMilliseconds)ms"
Write-Host "Destination connectivity: $($destTest.TotalMilliseconds)ms"

# Estimate bandwidth requirements
$estimatedFileSizeMB = 150  # Average per user
$totalUsers = 100
$totalDataGB = ($estimatedFileSizeMB * $totalUsers) / 1024
$migrationWindowHours = 48
$requiredBandwidthMbps = ($totalDataGB * 8 * 1024) / ($migrationWindowHours * 3600)

Write-Host "Estimated total data: ${totalDataGB}GB"
Write-Host "Required bandwidth: ${requiredBandwidthMbps}Mbps"
```

### Migration Phases Strategy

#### Phase 1: Pilot Migration (5-10 users)
```powershell
# Select pilot users with varied data profiles
$pilotUsers = @(
    @{Source="smalluser@contoso.com"; Dest="smalluser@fabrikam.com"; Profile="Light"},
    @{Source="heavyuser@contoso.com"; Dest="heavyuser@fabrikam.com"; Profile="Heavy"},
    @{Source="mixeduser@contoso.com"; Dest="mixeduser@fabrikam.com"; Profile="Mixed"}
)

foreach ($user in $pilotUsers) {
    Write-Host "Pilot migration: $($user.Source) -> $($user.Dest)" -ForegroundColor Green
    
    # Use enhanced verification and resume for pilot
    .\OneDriveMigration.ps1 -Mode Interactive `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $user.Source `
      -DestTenant "fabrikam" `
      -DestAdminUpn "admin@fabrikam.com" `
      -DestUserUpn $user.Dest `
      -VerificationLevel Enhanced `
      -EnableResume `
      -LogFile "Pilot_$($user.Profile)_$(Get-Date -Format 'yyyyMMdd').csv"
}
```

#### Phase 2: Batch Migration (Production)
```powershell
# Production batch approach
$batchSize = 20
$allUsers = Import-Csv "UserMappings.csv"  # source_user,dest_user
$batches = for ($i = 0; $i -lt $allUsers.Count; $i += $batchSize) {
    $allUsers[$i..([math]::Min($i + $batchSize - 1, $allUsers.Count - 1))]
}

foreach ($batch in $batches) {
    $batchNumber = [array]::IndexOf($batches, $batch) + 1
    Write-Host "Processing Batch $batchNumber of $($batches.Count)" -ForegroundColor Yellow
    
    # Process batch with optimized settings
    foreach ($user in $batch) {
        .\OneDriveMigration.ps1 -Mode Automated `
          -SourceTenant "contoso" `
          -SourceAdminUpn "admin@contoso.com" `
          -SourceUserUpn $user.source_user `
          -DestTenant "fabrikam" `
          -DestAdminUpn "admin@fabrikam.com" `
          -DestUserUpn $user.dest_user `
          -VerificationLevel Basic `
          -EnableResume `
          -Concise -Yes
    }
    
    # Pause between batches
    Start-Sleep -Seconds 300  # 5 minutes
}
```

## Enterprise Deployment Patterns

### Pattern 1: Hub-and-Spoke Migration

```powershell
# Central migration server with multiple execution nodes
param(
    [string]$MigrationHubPath = "\\MigrationHub\Shared",
    [int]$NodeId = 1,
    [int]$TotalNodes = 4
)

# Load user assignments for this node
$allUsers = Import-Csv "$MigrationHubPath\UserMappings.csv"
$nodeUsers = $allUsers | Where-Object { ([array]::IndexOf($allUsers, $_) % $TotalNodes) -eq ($NodeId - 1) }

Write-Host "Node $NodeId processing $($nodeUsers.Count) users" -ForegroundColor Cyan

foreach ($user in $nodeUsers) {
    $nodeLogPath = "$MigrationHubPath\Logs\Node$NodeId"
    New-Item -Path $nodeLogPath -ItemType Directory -Force | Out-Null
    
    .\OneDriveMigration.ps1 -Mode Automated `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $user.source_user `
      -DestTenant "fabrikam" `
      -DestAdminUpn "admin@fabrikam.com" `
      -DestUserUpn $user.dest_user `
      -LocalArchivePath "$MigrationHubPath\Archive\Node$NodeId\$($user.source_user.Split('@')[0])" `
      -LogFile "$nodeLogPath\Migration_$($user.source_user.Split('@')[0])_$(Get-Date -Format 'yyyyMMdd').csv" `
      -EnableResume -Concise -Yes
}
```

### Pattern 2: Staged Migration with Validation Gates

```powershell
# Multi-stage migration with validation checkpoints
function Invoke-StagedMigration {
    param(
        [string]$SourceUser,
        [string]$DestUser,
        [string]$MigrationId = (Get-Date -Format 'yyyyMMdd_HHmmss')
    )
    
    $stageResults = @{}
    
    # Stage 1: Validation
    Write-Host "Stage 1: Validation for $SourceUser" -ForegroundColor Yellow
    $validation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $SourceUser
    
    if (-not $validation.Success) {
        throw "Validation failed for $SourceUser"
    }
    $stageResults.Validation = $validation
    
    # Stage 2: Download with verification
    Write-Host "Stage 2: Download for $SourceUser" -ForegroundColor Yellow
    $download = .\OneDriveMigration.ps1 -Mode DownloadOnly `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $SourceUser `
      -LocalArchivePath "C:\Migration\$MigrationId\$($SourceUser.Split('@')[0])" `
      -VerificationLevel Enhanced `
      -EnableResume
    
    if (-not $download.Success) {
        throw "Download failed for $SourceUser"
    }
    $stageResults.Download = $download
    
    # Stage 3: Destination validation
    Write-Host "Stage 3: Destination validation for $DestUser" -ForegroundColor Yellow
    $destValidation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
      -DestTenant "fabrikam" `
      -DestAdminUpn "admin@fabrikam.com" `
      -DestUserUpn $DestUser
    
    if (-not $destValidation.Success) {
        throw "Destination validation failed for $DestUser"
    }
    $stageResults.DestValidation = $destValidation
    
    # Stage 4: Upload with conflict resolution
    Write-Host "Stage 4: Upload for $DestUser" -ForegroundColor Yellow
    $upload = .\OneDriveMigration.ps1 -Mode UploadOnly `
      -DestTenant "fabrikam" `
      -DestAdminUpn "admin@fabrikam.com" `
      -DestUserUpn $DestUser `
      -LocalArchivePath "C:\Migration\$MigrationId\$($SourceUser.Split('@')[0])" `
      -ConflictResolution Rename `
      -EnableResume
    
    if (-not $upload.Success) {
        throw "Upload failed for $DestUser"
    }
    $stageResults.Upload = $upload
    
    return $stageResults
}

# Execute staged migration
try {
    $results = Invoke-StagedMigration -SourceUser "john.doe@contoso.com" -DestUser "john.doe@fabrikam.com"
    Write-Host "Migration completed successfully" -ForegroundColor Green
} catch {
    Write-Host "Migration failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

## Performance Optimization

### Optimization Strategy 1: Parallel Processing

```powershell
# Parallel migration using PowerShell jobs
$users = Import-Csv "UserMappings.csv"
$maxConcurrentJobs = 4

$scriptBlock = {
    param($user, $scriptPath)
    
    & $scriptPath -Mode Automated `
      -SourceTenant "contoso" `
      -SourceAdminUpn "admin@contoso.com" `
      -SourceUserUpn $user.source_user `
      -DestTenant "fabrikam" `
      -DestAdminUpn "admin@fabrikam.com" `
      -DestUserUpn $user.dest_user `
      -VerificationLevel Basic `
      -Concise -Yes
}

foreach ($user in $users) {
    # Wait if we've reached max concurrent jobs
    while ((Get-Job -State Running).Count -ge $maxConcurrentJobs) {
        Start-Sleep -Seconds 30
        Get-Job -State Completed | Remove-Job
    }
    
    # Start new job
    Start-Job -ScriptBlock $scriptBlock -ArgumentList $user, ".\OneDriveMigration.ps1" -Name "Migration_$($user.source_user.Split('@')[0])"
    Write-Host "Started migration job for $($user.source_user)" -ForegroundColor Green
}

# Wait for all jobs to complete
while ((Get-Job -State Running).Count -gt 0) {
    Write-Host "Waiting for $((Get-Job -State Running).Count) jobs to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
}

# Collect results
Get-Job | Receive-Job
Get-Job | Remove-Job
```

### Optimization Strategy 2: Resource-Aware Processing

```powershell
# Monitor system resources and adjust processing
function Get-SystemLoad {
    $cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $memory = Get-WmiObject -Class Win32_OperatingSystem
    $memoryUsed = (($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100
    
    return @{
        CPU = $cpu.Average
        Memory = $memoryUsed
    }
}

function Invoke-ResourceAwareMigration {
    param([array]$Users)
    
    $completedUsers = @()
    $failedUsers = @()
    
    foreach ($user in $Users) {
        # Check system load
        $load = Get-SystemLoad
        
        # If system is under heavy load, wait
        while ($load.CPU -gt 80 -or $load.Memory -gt 85) {
            Write-Host "System under heavy load (CPU: $($load.CPU)%, Memory: $($load.Memory)%). Waiting..." -ForegroundColor Yellow
            Start-Sleep -Seconds 120
            $load = Get-SystemLoad
        }
        
        # Adjust verification level based on system load
        $verificationLevel = if ($load.CPU -lt 50 -and $load.Memory -lt 70) { "Enhanced" } else { "Basic" }
        
        Write-Host "Processing $($user.source_user) with $verificationLevel verification (CPU: $($load.CPU)%, Memory: $($load.Memory)%)" -ForegroundColor Cyan
        
        try {
            $result = .\OneDriveMigration.ps1 -Mode Automated `
              -SourceTenant "contoso" `
              -SourceAdminUpn "admin@contoso.com" `
              -SourceUserUpn $user.source_user `
              -DestTenant "fabrikam" `
              -DestAdminUpn "admin@fabrikam.com" `
              -DestUserUpn $user.dest_user `
              -VerificationLevel $verificationLevel `
              -EnableResume -Concise -Yes
            
            if ($result.Success) {
                $completedUsers += $user
            } else {
                $failedUsers += $user
            }
        } catch {
            $failedUsers += $user
            Write-Host "Migration failed for $($user.source_user): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return @{
        Completed = $completedUsers
        Failed = $failedUsers
    }
}
```

### Optimization Strategy 3: Network-Optimized Settings

```powershell
# Configure optimal settings based on network conditions
function Test-NetworkOptimization {
    $testUrl = "https://contoso.sharepoint.com"
    $testFile = "https://contoso.sharepoint.com/test/smallfile.txt"
    
    # Test latency
    $latency = Measure-Command { 
        try { Invoke-WebRequest -Uri $testUrl -UseBasicParsing | Out-Null } catch { }
    }
    
    # Test throughput (rough estimate)
    $throughput = Measure-Command {
        try { Invoke-WebRequest -Uri $testFile -UseBasicParsing | Out-Null } catch { }
    }
    
    $networkProfile = if ($latency.TotalMilliseconds -lt 100 -and $throughput.TotalMilliseconds -lt 500) {
        "HighSpeed"
    } elseif ($latency.TotalMilliseconds -lt 300) {
        "Standard"
    } else {
        "LowSpeed"
    }
    
    return @{
        Profile = $networkProfile
        Latency = $latency.TotalMilliseconds
        ThroughputTest = $throughput.TotalMilliseconds
    }
}

# Apply network-optimized settings
$networkProfile = Test-NetworkOptimization

$migrationParams = @{
    Mode = "Automated"
    SourceTenant = "contoso"
    SourceAdminUpn = "admin@contoso.com"
    DestTenant = "fabrikam"
    DestAdminUpn = "admin@fabrikam.com"
    EnableResume = $true
    Yes = $true
}

# Adjust settings based on network profile
switch ($networkProfile.Profile) {
    "HighSpeed" {
        $migrationParams.VerificationLevel = "Enhanced"
        $migrationParams.Concise = $false  # Allow verbose output
    }
    "Standard" {
        $migrationParams.VerificationLevel = "Basic"
        $migrationParams.Concise = $true
    }
    "LowSpeed" {
        $migrationParams.VerificationLevel = "Basic"
        $migrationParams.Concise = $true
        # Consider smaller batch sizes or additional delays
    }
}

Write-Host "Network profile: $($networkProfile.Profile) (Latency: $($networkProfile.Latency)ms)" -ForegroundColor Cyan
```

## Security and Compliance

### Secure Credential Management

```powershell
# Use Windows Credential Manager for secure credential storage
function Set-MigrationCredentials {
    param(
        [string]$TenantName,
        [string]$Purpose
    )
    
    $credentialName = "OneDriveMigration_${TenantName}_${Purpose}"
    
    # Prompt for credentials
    $cred = Get-Credential -Message "Enter credentials for $Purpose tenant ($TenantName)"
    
    # Store in Windows Credential Manager (requires CredentialManager module)
    if (Get-Module -ListAvailable -Name CredentialManager) {
        Import-Module CredentialManager
        New-StoredCredential -Target $credentialName -UserName $cred.UserName -Password $cred.Password -Persist LocalMachine
        Write-Host "Credentials stored securely for $credentialName" -ForegroundColor Green
    } else {
        Write-Warning "CredentialManager module not available. Install with: Install-Module CredentialManager"
    }
}

function Get-MigrationCredentials {
    param(
        [string]$TenantName,
        [string]$Purpose
    )
    
    $credentialName = "OneDriveMigration_${TenantName}_${Purpose}"
    
    if (Get-Module -ListAvailable -Name CredentialManager) {
        Import-Module CredentialManager
        $storedCred = Get-StoredCredential -Target $credentialName
        if ($storedCred) {
            return $storedCred
        }
    }
    
    # Fallback to prompt
    return Get-Credential -Message "Enter credentials for $Purpose tenant ($TenantName)"
}

# Usage
Set-MigrationCredentials -TenantName "contoso" -Purpose "Source"
Set-MigrationCredentials -TenantName "fabrikam" -Purpose "Destination"
```

### Audit and Compliance Logging

```powershell
# Enhanced audit logging for compliance
function Write-ComplianceLog {
    param(
        [string]$Action,
        [string]$User,
        [string]$Details,
        [string]$ComplianceLogPath = "C:\Compliance\OneDriveMigration.log"
    )
    
    $logEntry = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Action = $Action
        User = $User
        Details = $Details
        ComputerName = $env:COMPUTERNAME
        UserContext = $env:USERNAME
        SessionId = $Script:SessionId
    }
    
    $logLine = $logEntry | ConvertTo-Json -Compress
    Add-Content -Path $ComplianceLogPath -Value $logLine
    
    # Also log to Windows Event Log
    Write-EventLog -LogName Application -Source "OneDriveMigration" -EventId 1001 -EntryType Information -Message $logLine
}

# Usage throughout migration
Write-ComplianceLog -Action "Migration Started" -User $SourceUserUpn -Details "Source: $SourceTenant, Destination: $DestTenant"
Write-ComplianceLog -Action "File Downloaded" -User $SourceUserUpn -Details "File: $fileName, Size: $fileSize"
Write-ComplianceLog -Action "Migration Completed" -User $SourceUserUpn -Details "Files: $filesTransferred, Status: Success"
```

### Data Encryption and Protection

```powershell
# Encrypt local archive using BitLocker or EFS
function Enable-ArchiveEncryption {
    param([string]$ArchivePath)
    
    # Check if BitLocker is available
    if (Get-Command Enable-BitLocker -ErrorAction SilentlyContinue) {
        try {
            # Enable BitLocker on the drive containing the archive
            $drive = Split-Path -Path $ArchivePath -Qualifier
            Enable-BitLocker -MountPoint $drive -EncryptionMethod Aes256 -UsedSpaceOnly
            Write-Host "BitLocker encryption enabled for $drive" -ForegroundColor Green
        } catch {
            Write-Warning "BitLocker encryption failed: $($_.Exception.Message)"
        }
    } else {
        # Fallback to EFS for folder-level encryption
        try {
            cipher.exe /e /s:$ArchivePath
            Write-Host "EFS encryption enabled for $ArchivePath" -ForegroundColor Green
        } catch {
            Write-Warning "EFS encryption failed: $($_.Exception.Message)"
        }
    }
}

# Usage
$archivePath = "C:\Migration\SecureArchive"
New-Item -Path $archivePath -ItemType Directory -Force | Out-Null
Enable-ArchiveEncryption -ArchivePath $archivePath
```

## Bulk Migration Strategies

### Strategy 1: Department-Based Migration

```powershell
# Organize migrations by department/organizational unit
$departments = @{
    "Sales" = @("sales1@contoso.com", "sales2@contoso.com", "salesmanager@contoso.com")
    "Engineering" = @("dev1@contoso.com", "dev2@contoso.com", "techleader@contoso.com")
    "HR" = @("hr1@contoso.com", "hr2@contoso.com", "hrmanager@contoso.com")
}

foreach ($dept in $departments.Keys) {
    Write-Host "Starting migration for $dept department" -ForegroundColor Cyan
    
    # Create department-specific archive
    $deptArchive = "C:\Migration\Departments\$dept"
    New-Item -Path $deptArchive -ItemType Directory -Force | Out-Null
    
    foreach ($user in $departments[$dept]) {
        Write-Host "Migrating $user ($dept)" -ForegroundColor Yellow
        
        try {
            $result = .\OneDriveMigration.ps1 -Mode Automated `
              -SourceTenant "contoso" `
              -SourceAdminUpn "admin@contoso.com" `
              -SourceUserUpn $user `
              -DestTenant "fabrikam" `
              -DestAdminUpn "admin@fabrikam.com" `
              -DestUserUpn $user.Replace("contoso.com", "fabrikam.com") `
              -LocalArchivePath "$deptArchive\$($user.Split('@')[0])" `
              -LogFile "$deptArchive\${dept}_Migration_$(Get-Date -Format 'yyyyMMdd').csv" `
              -EnableResume -Concise -Yes
            
            if ($result.Success) {
                Write-Host "✓ $user migration completed" -ForegroundColor Green
            } else {
                Write-Host "✗ $user migration failed" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ $user migration error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Generate department summary report
    $deptLogs = Import-Csv "$deptArchive\${dept}_Migration_*.csv"
    $summary = $deptLogs | Group-Object Status | Select-Object Name, Count
    $summary | Export-Csv "$deptArchive\${dept}_Summary_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
    
    Write-Host "$dept department migration completed" -ForegroundColor Green
    Write-Host "Summary: $($summary | ConvertTo-Json)" -ForegroundColor Cyan
}
```

### Strategy 2: Priority-Based Migration

```powershell
# Migrate users based on priority levels
$userPriorities = Import-Csv "UserPriorities.csv"  # user,priority,reason

# Group by priority and sort
$priorityGroups = $userPriorities | Group-Object Priority | Sort-Object Name

foreach ($group in $priorityGroups) {
    $priority = $group.Name
    $users = $group.Group
    
    Write-Host "Processing Priority $priority users ($($users.Count) users)" -ForegroundColor Magenta
    
    # High priority gets enhanced verification and immediate processing
    $verificationLevel = if ($priority -eq "High") { "Enhanced" } else { "Basic" }
    $delayBetweenUsers = if ($priority -eq "High") { 30 } else { 60 }
    
    foreach ($user in $users) {
        Write-Host "Priority $priority: $($user.user) - $($user.reason)" -ForegroundColor Yellow
        
        $result = .\OneDriveMigration.ps1 -Mode Automated `
          -SourceTenant "contoso" `
          -SourceAdminUpn "admin@contoso.com" `
          -SourceUserUpn $user.user `
          -DestTenant "fabrikam" `
          -DestAdminUpn "admin@fabrikam.com" `
          -DestUserUpn $user.user.Replace("contoso.com", "fabrikam.com") `
          -VerificationLevel $verificationLevel `
          -EnableResume -Concise -Yes
        
        # Brief delay between users
        Start-Sleep -Seconds $delayBetweenUsers
    }
    
    Write-Host "Priority $priority group completed" -ForegroundColor Green
    
    # Longer delay between priority groups
    if ($priority -ne "Low") {
        Start-Sleep -Seconds 300  # 5 minutes
    }
}
```

## Error Recovery and Resilience

### Comprehensive Error Recovery System

```powershell
# Advanced error recovery and retry logic
function Invoke-ResilientMigration {
    param(
        [string]$SourceUser,
        [string]$DestUser,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 300
    )
    
    $attempts = 0
    $lastError = $null
    
    while ($attempts -lt $MaxRetries) {
        $attempts++
        Write-Host "Migration attempt $attempts of $MaxRetries for $SourceUser" -ForegroundColor Cyan
        
        try {
            # Attempt migration with progressive fallback strategy
            $migrationParams = @{
                Mode = "Automated"
                SourceTenant = "contoso"
                SourceAdminUpn = "admin@contoso.com"
                SourceUserUpn = $SourceUser
                DestTenant = "fabrikam"
                DestAdminUpn = "admin@fabrikam.com"
                DestUserUpn = $DestUser
                EnableResume = $true
                Concise = $true
                Yes = $true
            }
            
            # Progressive fallback: start with enhanced, fall back to basic
            if ($attempts -eq 1) {
                $migrationParams.VerificationLevel = "Enhanced"
            } else {
                $migrationParams.VerificationLevel = "Basic"
            }
            
            # Execute migration
            $result = .\OneDriveMigration.ps1 @migrationParams
            
            if ($result.Success) {
                Write-Host "✓ Migration successful for $SourceUser on attempt $attempts" -ForegroundColor Green
                return @{
                    Success = $true
                    Attempts = $attempts
                    Result = $result
                }
            } else {
                throw "Migration returned failure status"
            }
            
        } catch {
            $lastError = $_.Exception.Message
            Write-Host "✗ Attempt $attempts failed: $lastError" -ForegroundColor Red
            
            if ($attempts -lt $MaxRetries) {
                Write-Host "Waiting $RetryDelaySeconds seconds before retry..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
                
                # Exponential backoff
                $RetryDelaySeconds *= 2
            }
        }
    }
    
    # All attempts failed
    Write-Host "✗ All $MaxRetries attempts failed for $SourceUser" -ForegroundColor Red
    return @{
        Success = $false
        Attempts = $attempts
        LastError = $lastError
    }
}

# Batch processing with error recovery
$users = Import-Csv "UserMappings.csv"
$results = @()

foreach ($user in $users) {
    $migrationResult = Invoke-ResilientMigration -SourceUser $user.source_user -DestUser $user.dest_user
    
    $results += [PSCustomObject]@{
        SourceUser = $user.source_user
        DestUser = $user.dest_user
        Success = $migrationResult.Success
        Attempts = $migrationResult.Attempts
        Error = $migrationResult.LastError
        Timestamp = Get-Date
    }
}

# Export results for analysis
$results | Export-Csv "MigrationResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation

# Summary report
$summary = $results | Group-Object Success | Select-Object Name, Count
Write-Host "Migration Summary:" -ForegroundColor Cyan
$summary | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
```

### Failed Migration Recovery

```powershell
# Identify and retry failed migrations
function Invoke-FailedMigrationRecovery {
    param(
        [string]$ResultsFile,
        [string]$LogDirectory = "C:\Migration\Logs"
    )
    
    # Load previous results
    $previousResults = Import-Csv $ResultsFile
    $failedMigrations = $previousResults | Where-Object { $_.Success -eq $false }
    
    Write-Host "Found $($failedMigrations.Count) failed migrations to retry" -ForegroundColor Yellow
    
    foreach ($failed in $failedMigrations) {
        Write-Host "Retrying failed migration: $($failed.SourceUser) -> $($failed.DestUser)" -ForegroundColor Cyan
        
        # Analyze failure logs to determine recovery strategy
        $userLogFiles = Get-ChildItem -Path $LogDirectory -Filter "*$($failed.SourceUser.Split('@')[0])*" -Recurse
        $recoveryStrategy = "Standard"
        
        if ($userLogFiles) {
            $logContent = $userLogFiles | ForEach-Object { Import-Csv $_.FullName }
            $largeFileFailures = $logContent | Where-Object { $_.Status -eq "Failed" -and $_.Error -like "*250MB*" }
            
            if ($largeFileFailures.Count -gt 0) {
                Write-Host "  Large file failures detected, using optimized strategy" -ForegroundColor Yellow
                $recoveryStrategy = "LargeFileOptimized"
            }
        }
        
        # Execute recovery based on strategy
        switch ($recoveryStrategy) {
            "LargeFileOptimized" {
                # Use basic verification and accept large file limitations
                $result = .\OneDriveMigration.ps1 -Mode Automated `
                  -SourceTenant "contoso" `
                  -SourceAdminUpn "admin@contoso.com" `
                  -SourceUserUpn $failed.SourceUser `
                  -DestTenant "fabrikam" `
                  -DestAdminUpn "admin@fabrikam.com" `
                  -DestUserUpn $failed.DestUser `
                  -VerificationLevel Basic `
                  -EnableResume -Concise -Yes
            }
            default {
                # Standard retry
                $result = Invoke-ResilientMigration -SourceUser $failed.SourceUser -DestUser $failed.DestUser -MaxRetries 2
            }
        }
        
        if ($result.Success) {
            Write-Host "✓ Recovery successful for $($failed.SourceUser)" -ForegroundColor Green
        } else {
            Write-Host "✗ Recovery failed for $($failed.SourceUser)" -ForegroundColor Red
        }
    }
}
```

## Monitoring and Reporting

### Real-Time Migration Dashboard

```powershell
# Create a real-time monitoring dashboard
function Start-MigrationDashboard {
    param(
        [string]$LogDirectory = "C:\Migration\Logs",
        [int]$RefreshIntervalSeconds = 30
    )
    
    while ($true) {
        Clear-Host
        Write-Host "=== OneDrive Migration Dashboard ===" -ForegroundColor Cyan
        Write-Host "Last Updated: $(Get-Date)" -ForegroundColor Gray
        Write-Host ""
        
        # Aggregate all CSV logs
        $allLogs = Get-ChildItem -Path $LogDirectory -Filter "*.csv" -Recurse | 
                   ForEach-Object { Import-Csv $_.FullName }
        
        if ($allLogs) {
            # Overall statistics
            $totalOperations = $allLogs.Count
            $statusGroups = $allLogs | Group-Object Status
            
            Write-Host "Overall Statistics:" -ForegroundColor Yellow
            foreach ($group in $statusGroups) {
                $percentage = [math]::Round(($group.Count / $totalOperations) * 100, 1)
                Write-Host "  $($group.Name): $($group.Count) ($percentage%)" -ForegroundColor White
            }
            Write-Host ""
            
            # Recent activity (last 10 operations)
            Write-Host "Recent Activity:" -ForegroundColor Yellow
            $recentOps = $allLogs | Sort-Object Timestamp -Descending | Select-Object -First 10
            foreach ($op in $recentOps) {
                $color = switch ($op.Status) {
                    "Success" { "Green" }
                    "Failed" { "Red" }
                    "Skipped" { "Yellow" }
                    default { "White" }
                }
                Write-Host "  $($op.Timestamp) - $($op.ItemName) - $($op.Status)" -ForegroundColor $color
            }
            Write-Host ""
            
            # Error summary
            $errors = $allLogs | Where-Object { $_.Status -eq "Failed" -and $_.Error }
            if ($errors) {
                Write-Host "Common Errors:" -ForegroundColor Red
                $errorGroups = $errors | Group-Object Error | Sort-Object Count -Descending | Select-Object -First 5
                foreach ($errorGroup in $errorGroups) {
                    Write-Host "  $($errorGroup.Count)x: $($errorGroup.Name)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No migration logs found in $LogDirectory" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Press Ctrl+C to exit dashboard" -ForegroundColor Gray
        Start-Sleep -Seconds $RefreshIntervalSeconds
    }
}

# Usage
# Start-MigrationDashboard -LogDirectory "C:\Migration\Logs" -RefreshIntervalSeconds 30
```

### Automated Reporting System

```powershell
# Generate comprehensive migration reports
function New-MigrationReport {
    param(
        [string]$LogDirectory = "C:\Migration\Logs",
        [string]$ReportPath = "C:\Migration\Reports\MigrationReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    )
    
    # Collect all log data
    $allLogs = Get-ChildItem -Path $LogDirectory -Filter "*.csv" -Recurse | 
               ForEach-Object { Import-Csv $_.FullName }
    
    # Generate statistics
    $stats = @{
        TotalOperations = $allLogs.Count
        SuccessfulOperations = ($allLogs | Where-Object { $_.Status -eq "Success" }).Count
        FailedOperations = ($allLogs | Where-Object { $_.Status -eq "Failed" }).Count
        SkippedOperations = ($allLogs | Where-Object { $_.Status -eq "Skipped" }).Count
        UniqueUsers = ($allLogs | Select-Object -ExpandProperty SessionId -Unique).Count
        StartTime = ($allLogs | Sort-Object Timestamp | Select-Object -First 1).Timestamp
        EndTime = ($allLogs | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp
    }
    
    # Calculate success rate
    $stats.SuccessRate = if ($stats.TotalOperations -gt 0) { 
        [math]::Round(($stats.SuccessfulOperations / $stats.TotalOperations) * 100, 2) 
    } else { 0 }
    
    # Generate HTML report
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>OneDrive Migration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 20px; text-align: center; }
        .stats { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { background-color: #f5f5f5; padding: 15px; text-align: center; border-radius: 5px; }
        .stat-number { font-size: 24px; font-weight: bold; color: #0078d4; }
        .success { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .error-list { background-color: #fff3cd; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>OneDrive Migration Report</h1>
        <p>Generated on $(Get-Date)</p>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <div class="stat-number">$($stats.TotalOperations)</div>
            <div>Total Operations</div>
        </div>
        <div class="stat-box">
            <div class="stat-number success">$($stats.SuccessfulOperations)</div>
            <div>Successful</div>
        </div>
        <div class="stat-box">
            <div class="stat-number failed">$($stats.FailedOperations)</div>
            <div>Failed</div>
        </div>
        <div class="stat-box">
            <div class="stat-number skipped">$($stats.SkippedOperations)</div>
            <div>Skipped</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">$($stats.SuccessRate)%</div>
            <div>Success Rate</div>
        </div>
    </div>
    
    <h2>Migration Timeline</h2>
    <p><strong>Start Time:</strong> $($stats.StartTime)</p>
    <p><strong>End Time:</strong> $($stats.EndTime)</p>
    <p><strong>Unique Users:</strong> $($stats.UniqueUsers)</p>
"@
    
    # Add error analysis if there are failures
    if ($stats.FailedOperations -gt 0) {
        $errors = $allLogs | Where-Object { $_.Status -eq "Failed" -and $_.Error }
        $errorGroups = $errors | Group-Object Error | Sort-Object Count -Descending
        
        $html += @"
    <h2>Error Analysis</h2>
    <div class="error-list">
        <h3>Most Common Errors:</h3>
        <ul>
"@
        foreach ($errorGroup in $errorGroups) {
            $html += "<li><strong>$($errorGroup.Count) occurrences:</strong> $($errorGroup.Name)</li>"
        }
        $html += "</ul></div>"
    }
    
    $html += "</body></html>"
    
    # Save report
    $reportDir = Split-Path -Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    
    $html | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "Migration report generated: $ReportPath" -ForegroundColor Green
    
    return $stats
}
```

## Advanced Scenarios

### Cross-Tenant User Mapping

```powershell
# Handle complex user mapping scenarios
function New-UserMappingStrategy {
    param(
        [string]$SourceDomain = "contoso.com",
        [string]$DestDomain = "fabrikam.com",
        [hashtable]$CustomMappings = @{},
        [string]$MappingFile = "UserMappings.csv"
    )
    
    # Load existing mappings if file exists
    $existingMappings = if (Test-Path $MappingFile) {
        Import-Csv $MappingFile
    } else {
        @()
    }
    
    # Create mapping rules
    $mappingRules = @{
        # Standard domain replacement
        Standard = { param($sourceUser) $sourceUser.Replace($SourceDomain, $DestDomain) }
        
        # Department-based mapping
        DepartmentBased = { 
            param($sourceUser) 
            $username = $sourceUser.Split('@')[0]
            if ($username -like "sales*") {
                "sales.$username@$DestDomain"
            } elseif ($username -like "dev*") {
                "engineering.$username@$DestDomain"
            } else {
                $sourceUser.Replace($SourceDomain, $DestDomain)
            }
        }
        
        # Custom mappings (exact matches)
        Custom = { 
            param($sourceUser) 
            if ($CustomMappings.ContainsKey($sourceUser)) {
                $CustomMappings[$sourceUser]
            } else {
                $sourceUser.Replace($SourceDomain, $DestDomain)
            }
        }
    }
    
    # Apply mapping strategy
    $strategy = "Custom"  # Change as needed
    $mappingFunction = $mappingRules[$strategy]
    
    # Generate new mappings
    $newMappings = @()
    foreach ($existing in $existingMappings) {
        $destUser = & $mappingFunction $existing.source_user
        $newMappings += [PSCustomObject]@{
            source_user = $existing.source_user
            dest_user = $destUser
            mapping_strategy = $strategy
            verified = $false
        }
    }
    
    # Export updated mappings
    $newMappings | Export-Csv $MappingFile -NoTypeInformation
    Write-Host "User mappings updated with $strategy strategy" -ForegroundColor Green
    
    return $newMappings
}

# Usage
$customMappings = @{
    "john.doe@contoso.com" = "j.doe@fabrikam.com"
    "jane.smith@contoso.com" = "jane.smith-consultant@fabrikam.com"
}

$mappings = New-UserMappingStrategy -CustomMappings $customMappings
```

### Multi-Tenant Migration Hub

```powershell
# Manage migrations across multiple tenant pairs
function Invoke-MultiTenantMigration {
    param(
        [array]$TenantPairs,  # Array of @{Source="tenant1"; Dest="tenant2"; Users=@()}
        [string]$HubPath = "C:\Migration\Hub"
    )
    
    foreach ($pair in $TenantPairs) {
        $pairId = "$($pair.Source)_to_$($pair.Dest)"
        Write-Host "Processing tenant pair: $pairId" -ForegroundColor Magenta
        
        # Create dedicated folder for this tenant pair
        $pairPath = Join-Path $HubPath $pairId
        New-Item -Path $pairPath -ItemType Directory -Force | Out-Null
        
        # Get credentials for this tenant pair
        $sourceCreds = Get-MigrationCredentials -TenantName $pair.Source -Purpose "Source"
        $destCreds = Get-MigrationCredentials -TenantName $pair.Dest -Purpose "Destination"
        
        foreach ($userMapping in $pair.Users) {
            Write-Host "  Migrating: $($userMapping.source) -> $($userMapping.dest)" -ForegroundColor Yellow
            
            try {
                $result = .\OneDriveMigration.ps1 -Mode Automated `
                  -SourceTenant $pair.Source `
                  -SourceAdminUpn "admin@$($pair.Source).com" `
                  -SourceUserUpn $userMapping.source `
                  -DestTenant $pair.Dest `
                  -DestAdminUpn "admin@$($pair.Dest).com" `
                  -DestUserUpn $userMapping.dest `
                  -LocalArchivePath "$pairPath\$($userMapping.source.Split('@')[0])" `
                  -LogFile "$pairPath\${pairId}_$(Get-Date -Format 'yyyyMMdd').csv" `
                  -EnableResume -Concise -Yes
                
                if ($result.Success) {
                    Write-Host "  ✓ Success" -ForegroundColor Green
                } else {
                    Write-Host "  ✗ Failed" -ForegroundColor Red
                }
            } catch {
                Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Generate pair summary
        $pairLogs = Import-Csv "$pairPath\${pairId}_*.csv"
        $pairSummary = $pairLogs | Group-Object Status | Select-Object Name, Count
        $pairSummary | Export-Csv "$pairPath\${pairId}_Summary.csv" -NoTypeInformation
        
        Write-Host "Tenant pair $pairId completed" -ForegroundColor Green
    }
}

# Usage
$tenantPairs = @(
    @{
        Source = "contoso"
        Dest = "fabrikam"
        Users = @(
            @{source="user1@contoso.com"; dest="user1@fabrikam.com"}
            @{source="user2@contoso.com"; dest="user2@fabrikam.com"}
        )
    }
    @{
        Source = "contoso"
        Dest = "northwind"
        Users = @(
            @{source="user3@contoso.com"; dest="user3@northwind.com"}
        )
    }
)

Invoke-MultiTenantMigration -TenantPairs $tenantPairs
```

## Automation and Scripting

### Automated Migration Pipeline

```powershell
# Complete automated migration pipeline
function Start-MigrationPipeline {
    param(
        [string]$ConfigFile = "MigrationConfig.json",
        [string]$LogLevel = "Info"
    )
    
    # Load configuration
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    
    Write-Host "Starting Migration Pipeline" -ForegroundColor Cyan
    Write-Host "Configuration: $ConfigFile" -ForegroundColor Gray
    
    # Phase 1: Pre-migration validation
    Write-Host "`n=== Phase 1: Pre-migration Validation ===" -ForegroundColor Yellow
    
    $validationResults = @()
    foreach ($user in $config.Users) {
        Write-Host "Validating $($user.source)..." -ForegroundColor Cyan
        
        $sourceValidation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
          -SourceTenant $config.SourceTenant `
          -SourceAdminUpn $config.SourceAdminUpn `
          -SourceUserUpn $user.source
        
        $destValidation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
          -DestTenant $config.DestTenant `
          -DestAdminUpn $config.DestAdminUpn `
          -DestUserUpn $user.dest
        
        $validationResults += @{
            User = $user.source
            SourceValid = $sourceValidation.Success
            DestValid = $destValidation.Success
            SourceFileCount = $sourceValidation.FileCount
        }
    }
    
    # Check if all validations passed
    $failedValidations = $validationResults | Where-Object { -not $_.SourceValid -or -not $_.DestValid }
    if ($failedValidations) {
        Write-Host "Validation failures detected. Stopping pipeline." -ForegroundColor Red
        $failedValidations | ForEach-Object { 
            Write-Host "  Failed: $($_.User)" -ForegroundColor Red 
        }
        return
    }
    
    Write-Host "All validations passed. Proceeding with migration." -ForegroundColor Green
    
    # Phase 2: Migration execution
    Write-Host "`n=== Phase 2: Migration Execution ===" -ForegroundColor Yellow
    
    $migrationResults = @()
    foreach ($user in $config.Users) {
        Write-Host "Migrating $($user.source) -> $($user.dest)..." -ForegroundColor Cyan
        
        $result = .\OneDriveMigration.ps1 -Mode Automated `
          -SourceTenant $config.SourceTenant `
          -SourceAdminUpn $config.SourceAdminUpn `
          -SourceUserUpn $user.source `
          -DestTenant $config.DestTenant `
          -DestAdminUpn $config.DestAdminUpn `
          -DestUserUpn $user.dest `
          -VerificationLevel $config.VerificationLevel `
          -EnableResume -Concise -Yes
        
        $migrationResults += @{
            User = $user.source
            Success = $result.Success
            FilesProcessed = $result.FilesProcessed
            FilesTransferred = $result.FilesDownloaded
            Duration = (Get-Date) - $startTime
        }
        
        if ($result.Success) {
            Write-Host "  ✓ Migration completed" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Migration failed" -ForegroundColor Red
        }
    }
    
    # Phase 3: Post-migration reporting
    Write-Host "`n=== Phase 3: Post-migration Reporting ===" -ForegroundColor Yellow
    
    $summary = @{
        TotalUsers = $migrationResults.Count
        SuccessfulMigrations = ($migrationResults | Where-Object { $_.Success }).Count
        FailedMigrations = ($migrationResults | Where-Object { -not $_.Success }).Count
        TotalFilesProcessed = ($migrationResults | Measure-Object FilesProcessed -Sum).Sum
        TotalFilesTransferred = ($migrationResults | Measure-Object FilesTransferred -Sum).Sum
        PipelineStartTime = $startTime
        PipelineEndTime = Get-Date
    }
    
    Write-Host "Pipeline Summary:" -ForegroundColor Cyan
    $summary | ConvertTo-Json | Write-Host
    
    # Export detailed results
    $migrationResults | Export-Csv "Pipeline_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
    
    Write-Host "`nMigration Pipeline Completed" -ForegroundColor Green
}

# Example configuration file (MigrationConfig.json)
$exampleConfig = @{
    SourceTenant = "contoso"
    SourceAdminUpn = "admin@contoso.com"
    DestTenant = "fabrikam"
    DestAdminUpn = "admin@fabrikam.com"
    VerificationLevel = "Basic"
    Users = @(
        @{source="user1@contoso.com"; dest="user1@fabrikam.com"}
        @{source="user2@contoso.com"; dest="user2@fabrikam.com"}
    )
} | ConvertTo-Json

$exampleConfig | Out-File "MigrationConfig.json"
```

### Scheduled Migration Tasks

```powershell
# Create scheduled migration tasks using Windows Task Scheduler
function New-ScheduledMigration {
    param(
        [string]$TaskName = "OneDriveMigration_Batch",
        [datetime]$StartTime = (Get-Date).AddHours(1),
        [string]$ScriptPath = "C:\Migration\OneDriveMigration.ps1",
        [string]$UserBatchFile = "C:\Migration\CurrentBatch.csv"
    )
    
    # Create PowerShell script for scheduled execution
    $scheduledScript = @"
# Scheduled OneDrive Migration Script
`$ErrorActionPreference = "Continue"

# Load user batch
`$users = Import-Csv "$UserBatchFile"
`$results = @()

foreach (`$user in `$users) {
    try {
        Write-Host "Processing `$(`$user.source_user)..." -ForegroundColor Cyan
        
        `$result = & "$ScriptPath" -Mode Automated ``
          -SourceTenant "contoso" ``
          -SourceAdminUpn "admin@contoso.com" ``
          -SourceUserUpn `$user.source_user ``
          -DestTenant "fabrikam" ``
          -DestAdminUpn "admin@fabrikam.com" ``
          -DestUserUpn `$user.dest_user ``
          -EnableResume -Concise -Yes
        
        `$results += [PSCustomObject]@{
            User = `$user.source_user
            Success = `$result.Success
            Timestamp = Get-Date
            Error = if (`$result.Success) { "" } else { "Migration failed" }
        }
    } catch {
        `$results += [PSCustomObject]@{
            User = `$user.source_user
            Success = `$false
            Timestamp = Get-Date
            Error = `$_.Exception.Message
        }
    }
}

# Export results
`$results | Export-Csv "C:\Migration\Scheduled_Results_`$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation

# Email summary (if configured)
# Send-MailMessage -To "admin@company.com" -Subject "Migration Batch Completed" -Body (`$results | ConvertTo-Html)
"@
    
    # Save scheduled script
    $scheduledScriptPath = "C:\Migration\ScheduledMigration.ps1"
    $scheduledScript | Out-File $scheduledScriptPath -Encoding UTF8
    
    # Create scheduled task
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$scheduledScriptPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At $StartTime
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest
    
    Write-Host "Scheduled task '$TaskName' created for $StartTime" -ForegroundColor Green
    Write-Host "Script path: $scheduledScriptPath" -ForegroundColor Gray
}
```

## Post-Migration Validation

### Comprehensive Validation Suite

```powershell
# Post-migration validation and verification
function Invoke-PostMigrationValidation {
    param(
        [string]$ValidationConfigFile = "ValidationConfig.json",
        [string]$ReportPath = "C:\Migration\Validation"
    )
    
    $config = Get-Content $ValidationConfigFile | ConvertFrom-Json
    $validationResults = @()
    
    foreach ($user in $config.Users) {
        Write-Host "Validating migration for $($user.source) -> $($user.dest)" -ForegroundColor Cyan
        
        # Source validation (should show reduced/empty content)
        $sourceValidation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
          -SourceTenant $config.SourceTenant `
          -SourceAdminUpn $config.SourceAdminUpn `
          -SourceUserUpn $user.source
        
        # Destination validation (should show migrated content)
        $destValidation = .\OneDriveMigration.ps1 -Mode ValidateOnly `
          -DestTenant $config.DestTenant `
          -DestAdminUpn $config.DestAdminUpn `
          -DestUserUpn $user.dest
        
        # Compare file counts
        $migrationSuccess = $destValidation.Success -and ($destValidation.FileCount -gt 0)
        $completenessScore = if ($sourceValidation.FileCount -gt 0) {
            [math]::Round(($destValidation.FileCount / $sourceValidation.FileCount) * 100, 2)
        } else { 100 }
        
        $validationResults += [PSCustomObject]@{
            SourceUser = $user.source
            DestUser = $user.dest
            SourceFileCount = $sourceValidation.FileCount
            DestFileCount = $destValidation.FileCount
            CompletenessScore = $completenessScore
            MigrationSuccess = $migrationSuccess
            ValidationTimestamp = Get-Date
        }
        
        # Individual user report
        Write-Host "  Source files: $($sourceValidation.FileCount)" -ForegroundColor Gray
        Write-Host "  Destination files: $($destValidation.FileCount)" -ForegroundColor Gray
        Write-Host "  Completeness: $completenessScore%" -ForegroundColor $(if ($completenessScore -ge 95) { "Green" } elseif ($completenessScore -ge 80) { "Yellow" } else { "Red" })
    }
    
    # Generate comprehensive validation report
    $reportDir = $ReportPath
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    
    $validationResults | Export-Csv "$reportDir\ValidationResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
    
    # Summary statistics
    $summary = @{
        TotalUsers = $validationResults.Count
        SuccessfulMigrations = ($validationResults | Where-Object { $_.MigrationSuccess }).Count
        AverageCompleteness = [math]::Round(($validationResults | Measure-Object CompletenessScore -Average).Average, 2)
        HighCompleteness = ($validationResults | Where-Object { $_.CompletenessScore -ge 95 }).Count
        MediumCompleteness = ($validationResults | Where-Object { $_.CompletenessScore -ge 80 -and $_.CompletenessScore -lt 95 }).Count
        LowCompleteness = ($validationResults | Where-Object { $_.CompletenessScore -lt 80 }).Count
    }
    
    Write-Host "`nValidation Summary:" -ForegroundColor Yellow
    $summary | ConvertTo-Json | Write-Host
    
    return $validationResults
}
```

---

**Note:** This best practices guide provides advanced patterns and strategies for enterprise OneDrive migrations. Adapt these examples to your specific environment, security requirements, and organizational policies. Always test thoroughly in a non-production environment before implementing in production.