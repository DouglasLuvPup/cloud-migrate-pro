# SPMT-Worker.ps1 04/06/26a
# This script runs SPMT in isolation to avoid PnP assembly conflicts
# Called by CommonDriveMigration_v1.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetSiteUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetList,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetRelativePath = "",
    
    [Parameter(Mandatory=$true)]
    [string]$CredentialPath,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkingFolder,
    
    [Parameter(Mandatory=$false)]
    [string]$BlockedExtensions = "pst,ds_store,tmp,temp",
    
    [Parameter(Mandatory=$false)]
    [string]$DateCutoff = "",  # Empty = migrate all files, otherwise yyyy-MM-dd format
    
    [switch]$DebugMode  # When enabled, shows verbose debug output
)

# Result object to return
$result = @{
    Success = $false
    ReportPath = ""
    ErrorMessage = ""
    StartOutput = ""
}

try {
    # Load credentials
    if (-not (Test-Path $CredentialPath)) {
        $result.ErrorMessage = "Credential file not found: $CredentialPath"
        $result | ConvertTo-Json | Write-Output
        exit 1
    }
    
    $SPOCredential = Import-Clixml -Path $CredentialPath
    
    # Clean up any existing SPMT session
    try {
        Stop-SPMTMigration -ErrorAction SilentlyContinue
        Unregister-SPMTMigration -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } catch { }
    
    # Register SPMT
    $registerParams = @{
        SPOCredential = $SPOCredential
        WorkingFolder = $WorkingFolder
        MigrateWithoutRootFolder = $true
        ReplacementOfInvalidChar = "_"
    }
    
    # Add blocked extensions if specified
    # SPMT expects an ARRAY of extensions (without dots)
    if ($DebugMode) { Write-Host "DEBUG: BlockedExtensions parameter received: '$BlockedExtensions'" -ForegroundColor Magenta }
    if ($BlockedExtensions -and $BlockedExtensions.Length -gt 0) {
        # Convert comma-separated string to array, ensure no dots
        $extensionArray = @(($BlockedExtensions -split ',') | ForEach-Object { $_.Trim().TrimStart('.') } | Where-Object { $_ })
        Write-Host "Blocking file extensions: $($extensionArray -join ', ')" -ForegroundColor Yellow
        if ($DebugMode) { Write-Host "DEBUG: Extension array count: $($extensionArray.Count)" -ForegroundColor Magenta }
        $registerParams.SkipFilesWithExtension = $extensionArray
    } else {
        Write-Host "WARNING: No blocked extensions specified!" -ForegroundColor Red
    }
    
    if ($DebugMode) {
        Write-Host "DEBUG: Register-SPMTMigration params:" -ForegroundColor Magenta
        $registerParams.GetEnumerator() | ForEach-Object { 
            if ($_.Key -eq 'SkipFilesWithExtension') {
                Write-Host "  $($_.Key) = @($($_.Value -join ', '))" -ForegroundColor Magenta
            } else {
                Write-Host "  $($_.Key) = $($_.Value)" -ForegroundColor Magenta
            }
        }
    }
    
    Register-SPMTMigration @registerParams
    
    # Build JSON task definition (works on ALL SPMT versions for date filtering)
    # The -JsonDefinition approach supports MigrateItemsModifiedAfter on all versions
    $taskSettings = @{
        MigrateFileVersionHistory = $true
        KeepFileVersions = 100
        MigrateHiddenItems = $false
        PreservePermission = $false  # Disabled - can cause issues on Team Sites
        EnableIncremental = $false
    }
    
    # Add date filter to settings if specified
    if ($DateCutoff -and $DateCutoff.Trim() -ne "") {
        Write-Host "Date filter: Only migrating files modified after $DateCutoff" -ForegroundColor Cyan
        $taskSettings.MigrateItemsModifiedAfter = $DateCutoff
    } else {
        Write-Host "Date filter: DISABLED - migrating ALL files" -ForegroundColor Cyan
    }
    
    # Build task object
    $taskObject = @{
        SourcePath = $SourcePath
        TargetPath = $TargetSiteUrl
        TargetList = $TargetList
        Settings = $taskSettings
    }
    
    # Add subfolder if specified
    if ($TargetRelativePath -and $TargetRelativePath.Trim() -ne "") {
        Write-Host "Adding SPMT task with subfolder: $TargetRelativePath" -ForegroundColor Cyan
        $taskObject.TargetListRelativePath = $TargetRelativePath
    } else {
        Write-Host "Adding SPMT task to library root" -ForegroundColor Cyan
    }
    
    # Convert to JSON
    $jsonDefinition = ConvertTo-Json $taskObject -Depth 10
    if ($DebugMode) {
        Write-Host "DEBUG: JSON Task Definition:" -ForegroundColor Magenta
        Write-Host $jsonDefinition -ForegroundColor Gray
    }
    
    # Add task using JSON definition (compatible with all SPMT versions)
    Add-SPMTTask -JsonDefinition $jsonDefinition
    
    # Start migration and capture output
    $startOutput = Start-SPMTMigration 2>&1
    $startOutputStr = $startOutput | Out-String
    $result.StartOutput = $startOutputStr
    
    # Get final status
    $finalStatus = Get-SPMTMigration
    $result.ReportPath = $finalStatus.ReportFolderPath
    
    # Check for success
    # Note: "some tasks failed" means partial completion - let main script analyze FatalError reports
    if ($startOutputStr -like "*passed the parameter validation*" -and 
        $startOutputStr -like "*finished successfully*") {
        $result.Success = $true
    }
    elseif ($startOutputStr -like "*did NOT pass*" -or
           $startOutputStr -like "*Credential*invalid*") {
        # These are true failures - validation failed or credentials bad
        $result.Success = $false
        $result.ErrorMessage = $startOutputStr
    }
    elseif ($startOutputStr -like "*some tasks failed*") {
        # Partial failure - let main script process FatalError reports
        $result.Success = $true  # Report as "success" so main script processes reports
        $result.PartialFailure = $true
        $result.ErrorMessage = $startOutputStr
    }
    else {
        # Check report folder for errors
        $result.Success = $true  # Assume success if no obvious failure
    }
    
    # Cleanup
    Unregister-SPMTMigration -ErrorAction SilentlyContinue
}
catch {
    $result.Success = $false
    $result.ErrorMessage = $_.Exception.Message
}

# Output result as JSON for the calling script to parse
$result | ConvertTo-Json -Compress | Write-Output