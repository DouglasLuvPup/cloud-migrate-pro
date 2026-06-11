<# 05/19/26b
.SYNOPSIS
    Generates a migration status dashboard page for leadership reporting.

.DESCRIPTION
    Creates or updates a SharePoint page with migration pipeline statistics:
    - Size summary: Total Size, 7yr/5yr/3yr Size, Migrated Size, Total UNC Folders
    - Pipeline flow: Awaiting Scan → Awaiting Target → Resolved → Queued → Migrating → Complete
    - Scanned column is cumulative (total items scanned by UNC scanner)
    - Division breakdown table with stats per DIV
    - Migrated Size calculated from YearUsed column (uses appropriate 7yr/5yr/3yr size)
    
    Counts:
    - Scanned: CUMULATIVE - all items that have TotalSize (been through UNC scanner)
    
    Pipeline stages (mutually exclusive):
    - Awaiting Scan: Has SourcePath but no TotalSize (new items, not scanned yet)
    - Awaiting Target: Has TotalSize but no TargetURL (waiting for target resolution)
    - Resolved: Has TargetURL (ready to set Migrate)
    - Queued: Migrate = Stage/Staged/Migrate, Processing empty (awaiting worker)
    - Migrating: Processing not empty (SPMT active)
    - Complete: Migrated + MigratedWithErrors + Failed (includes ValidationFailed, StageFailed)
    
    Run every 2 hours via scheduled task to keep dashboard current.
    Timestamp displayed in EST timezone.

.PARAMETER PageName
    Name of the dashboard page. Default: Dashboard

.EXAMPLE
    .\New-MigrationDashboard.ps1
    # Creates/updates the dashboard page with current statistics

.NOTES
    Version:     2.6.0
    Date:        2026-05-04
    Author:      Douglas Cox [Microsoft CSA]
    Requires:    PnP.PowerShell module
    Environment: USSec / IL6 (.scloud)
#>

param(
    [string]$PageName = "Dashboard"
)

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$siteUrl  = "https://contoso.spo.microsoft.scloud/sites/000001"
$listName = "CommonMigrationStatus"

# App-Only Authentication
$UseAppAuth               = $true
$AppClientId              = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
$AppTenantId              = "dddddddd-dddd-dddd-dddd-dddddddddddd"
$AppCertificateThumbprint = "1111111111111111111111111111111111111111"

# Throttling settings
$ThrottleRetryCount = 5
$ThrottleBaseWaitSeconds = 15

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Gray" }
        default   { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Invoke-WithThrottling {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Operation = "Operation"
    )
    
    $retryCount = 0
    while ($retryCount -lt $ThrottleRetryCount) {
        try {
            return & $ScriptBlock
        }
        catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -like "*throttled*" -or 
                $errorMsg -like "*429*" -or 
                $errorMsg -like "*503*" -or
                $errorMsg -like "*too many requests*") {
                
                $retryCount++
                $waitTime = $ThrottleBaseWaitSeconds * [Math]::Pow(2, $retryCount - 1)
                Write-Log "Throttled on $Operation - waiting $waitTime seconds (attempt $retryCount/$ThrottleRetryCount)" "WARN"
                Start-Sleep -Seconds $waitTime
            }
            else {
                throw
            }
        }
    }
    throw "Max retries exceeded for $Operation"
}

function Format-SizeGB {
    param([double]$SizeGB)
    if ($SizeGB -ge 1024) {
        return "{0:N2} TB" -f ($SizeGB / 1024)
    }
    elseif ($SizeGB -ge 1) {
        return "{0:N2} GB" -f $SizeGB
    }
    elseif ($SizeGB -ge 0.001) {
        return "{0:N0} MB" -f ($SizeGB * 1024)
    }
    else {
        return "< 1 MB"
    }
}

# ============================================================
# MAIN SCRIPT
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Migration Dashboard Generator" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Connect to SharePoint
Write-Log "Connecting to SharePoint..."

try {
    if ($UseAppAuth) {
        Connect-PnPOnline -Url $siteUrl `
            -ClientId $AppClientId `
            -Tenant $AppTenantId `
            -Thumbprint $AppCertificateThumbprint `
            -ErrorAction Stop
    } else {
        Connect-PnPOnline -Url $siteUrl -UseWebLogin -ErrorAction Stop
    }
    Write-Log "Connected to $siteUrl" "SUCCESS"
}
catch {
    Write-Log "Failed to connect: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Get all list items
Write-Log "Loading migration data..."

$allItems = Invoke-WithThrottling -Operation "Get list items" -ScriptBlock {
    Get-PnPListItem -List $listName -PageSize 500 -ErrorAction Stop
}

Write-Log "Loaded $($allItems.Count) items" "SUCCESS"

# ============================================================
# CALCULATE STATISTICS
# ============================================================

Write-Log "Calculating statistics..."

# Helper to parse formatted size strings like "1.23 TB (12345 files)" and convert to GB
function ConvertTo-GB {
    param([string]$SizeString)
    if ([string]::IsNullOrWhiteSpace($SizeString)) { return 0 }
    
    # Extract numeric value and unit from strings like "1.23 TB" or "456.78 GB (1234 files)"
    if ($SizeString -match '^([\d.,]+)\s*(TB|GB|MB|KB|B)') {
        $value = [double]($Matches[1] -replace ',', '')
        $unit = $Matches[2]
        
        switch ($unit) {
            'TB' { return $value * 1024 }
            'GB' { return $value }
            'MB' { return $value / 1024 }
            'KB' { return $value / 1024 / 1024 }
            'B'  { return $value / 1024 / 1024 / 1024 }
            default { return 0 }
        }
    }
    
    # Try raw number (assume bytes or MB depending on magnitude)
    $num = 0
    if ([double]::TryParse($SizeString, [ref]$num)) {
        # If it's a small number, assume it's already in GB
        if ($num -lt 10000) { return $num }
        # Otherwise assume bytes
        return $num / 1024 / 1024 / 1024
    }
    
    return 0
}

# Initialize totals
# CUMULATIVE counts = running totals of items that have reached each milestone
# PIPELINE counts = where items are currently waiting (mutually exclusive)
$globalStats = @{
    TotalItems = 0
    TotalSizeGB = 0
    SevenYrSizeGB = 0
    FiveYrSizeGB = 0
    ThreeYrSizeGB = 0
    MigratedSizeGB = 0    # Based on YearUsed column
    # CUMULATIVE
    Scanned = 0           # All items with TotalSize (been through UNC scanner)
    Resolved = 0          # All items with TargetURL (target assigned)
    Complete = 0          # All items with terminal status (migrated/failed)
    # PIPELINE STAGES (mutually exclusive)
    AwaitingScan = 0      # No TotalSize yet
    AwaitingTarget = 0    # Has TotalSize, no TargetURL yet
    WaitingResolved = 0   # Has TargetURL, not queued/migrating/complete
    Queued = 0            # Migrate set, Processing empty
    Migrating = 0         # Processing not empty
    # COMPLETE BREAKDOWN
    Migrated = 0
    MigratedWithErrors = 0
    Failed = 0
}

# Stats by DIV
$divStats = @{}

foreach ($item in $allItems) {
    # Get field values with null safety
    $div = if ($item["DIV"]) { $item["DIV"].ToString().Trim().ToUpper() } else { "UNKNOWN" }
    $migrate = if ($item["Migrate"]) { $item["Migrate"].ToString().Trim() } else { "" }
    $processing = if ($item["Processing"]) { $item["Processing"].ToString().Trim() } else { "" }
    
    # Size fields - parse formatted strings like "1.23 TB (12345 files)"
    $totalSize = 0
    if ($item["TotalSize"]) {
        $totalSize = ConvertTo-GB $item["TotalSize"].ToString()
    }
    
    # Check if scanned using Date field (set when scan completes), not TotalSize
    # This correctly handles zero-size folders that have been scanned
    $hasScanned = ($null -ne $item["Date"])
    
    # 7yr field - prefer Size7YrMB (raw MB) if available, otherwise parse _x0037_yr
    $sevenYrSize = 0
    if ($item["Size7YrMB"]) {
        $mb = 0
        if ([double]::TryParse($item["Size7YrMB"].ToString(), [ref]$mb)) {
            $sevenYrSize = $mb / 1024  # Convert MB to GB
        }
    }
    else {
        foreach ($fieldName in @("_x0037_yr", "7yr", "_x0037_yr_")) {
            if ($item[$fieldName]) {
                $val = $item[$fieldName].ToString()
                if (-not [string]::IsNullOrWhiteSpace($val) -and $val -ne "0") {
                    $sevenYrSize = ConvertTo-GB $val
                    break
                }
            }
        }
    }
    
    # 5yr field - prefer Size5YrMB (raw MB) if available, otherwise parse _x0035_yr
    $fiveYrSize = 0
    if ($item["Size5YrMB"]) {
        $mb = 0
        if ([double]::TryParse($item["Size5YrMB"].ToString(), [ref]$mb)) {
            $fiveYrSize = $mb / 1024  # Convert MB to GB
        }
    }
    else {
        foreach ($fieldName in @("_x0035_yr", "5yr", "_x0035_yr_")) {
            if ($item[$fieldName]) {
                $val = $item[$fieldName].ToString()
                if (-not [string]::IsNullOrWhiteSpace($val) -and $val -ne "0") {
                    $fiveYrSize = ConvertTo-GB $val
                    break
                }
            }
        }
    }
    
    # 3yr field - prefer Size3YrMB (raw MB) if available, otherwise parse _x0033_yr
    $threeYrSize = 0
    if ($item["Size3YrMB"]) {
        $mb = 0
        if ([double]::TryParse($item["Size3YrMB"].ToString(), [ref]$mb)) {
            $threeYrSize = $mb / 1024  # Convert MB to GB
        }
    }
    else {
        foreach ($fieldName in @("_x0033_yr", "3yr", "_x0033_yr_")) {
            if ($item[$fieldName]) {
                $val = $item[$fieldName].ToString()
                if (-not [string]::IsNullOrWhiteSpace($val) -and $val -ne "0") {
                    $threeYrSize = ConvertTo-GB $val
                    break
                }
            }
        }
    }
    
    # YearUsed - determines which size to use for migrated calculation
    $yearUsed = 0
    if ($item["YearUsed"]) {
        [int]::TryParse($item["YearUsed"].ToString(), [ref]$yearUsed) | Out-Null
    }
    
    # TargetURL
    $hasTargetURL = $false
    foreach ($fieldName in @("TargetURL", "TargetUrl", "targeturl")) {
        if ($item[$fieldName]) {
            $val = $item[$fieldName].ToString().Trim()
            if (-not [string]::IsNullOrWhiteSpace($val)) {
                $hasTargetURL = $true
                break
            }
        }
    }
    
    # StorageAvailable (positive means OK, negative or zero means low)
    $storageOK = $false
    $storageAvailable = 0
    if ($item["StorageAvailable"]) {
        $val = $item["StorageAvailable"].ToString()
        if ([double]::TryParse($val, [ref]$storageAvailable) -and $storageAvailable -gt 0) {
            $storageOK = $true
        }
    }
    
    # Initialize DIV stats if not exists
    if (-not $divStats.ContainsKey($div)) {
        $divStats[$div] = @{
            TotalItems = 0
            TotalSizeGB = 0
            SevenYrSizeGB = 0
            FiveYrSizeGB = 0
            ThreeYrSizeGB = 0
            MigratedSizeGB = 0
            # CUMULATIVE
            Scanned = 0
            Resolved = 0
            Complete = 0
            # PIPELINE
            AwaitingScan = 0
            AwaitingTarget = 0
            WaitingResolved = 0
            Queued = 0
            Migrating = 0
            # COMPLETE BREAKDOWN
            Migrated = 0
            MigratedWithErrors = 0
            Failed = 0
        }
    }
    
    # Count totals
    $globalStats.TotalItems++
    $divStats[$div].TotalItems++
    
    # Total size and year-based sizes
    $globalStats.TotalSizeGB += $totalSize
    $divStats[$div].TotalSizeGB += $totalSize
    $globalStats.SevenYrSizeGB += $sevenYrSize
    $divStats[$div].SevenYrSizeGB += $sevenYrSize
    $globalStats.FiveYrSizeGB += $fiveYrSize
    $divStats[$div].FiveYrSizeGB += $fiveYrSize
    $globalStats.ThreeYrSizeGB += $threeYrSize
    $divStats[$div].ThreeYrSizeGB += $threeYrSize
    
    # Migrated size - based on YearUsed for completed items
    $isComplete = $migrate -in @("Migrated", "MigratedWithErrors", "Failed", "StageFailed", "ValidationFailed")
    $isMigratedSuccess = $migrate -in @("Migrated", "MigratedWithErrors")
    
    if ($isMigratedSuccess) {
        # Use appropriate size based on YearUsed
        $migratedSize = switch ($yearUsed) {
            7 { $sevenYrSize }
            5 { $fiveYrSize }
            3 { $threeYrSize }
            default { $sevenYrSize }  # fallback to 7yr if not set
        }
        $globalStats.MigratedSizeGB += $migratedSize
        $divStats[$div].MigratedSizeGB += $migratedSize
    }
    
    # CUMULATIVE COUNTS - running totals of items that have reached each milestone
    # Scanned: has TotalSize (been through UNC scanner)
    if ($hasScanned) {
        $globalStats.Scanned++
        $divStats[$div].Scanned++
    }
    
    # Resolved: has TargetURL (target has been assigned)
    if ($hasTargetURL) {
        $globalStats.Resolved++
        $divStats[$div].Resolved++
    }
    
    # Complete: migration finished (any terminal status)
    if ($isComplete) {
        $globalStats.Complete++
        $divStats[$div].Complete++
    }
    
    # PIPELINE STAGES - mutually exclusive, shows where items are NOW
    $isMigrating = (-not [string]::IsNullOrWhiteSpace($processing))
    $isQueued = ($migrate -in @("Migrate", "Stage", "Staged", "StagedWithErrors")) -and (-not $isMigrating) -and (-not $isComplete)
    
    if ($isComplete) {
        # Complete stage - count by status
        switch ($migrate) {
            "Migrated" {
                $globalStats.Migrated++
                $divStats[$div].Migrated++
            }
            "MigratedWithErrors" {
                $globalStats.MigratedWithErrors++
                $divStats[$div].MigratedWithErrors++
            }
            { $_ -in @("Failed", "StageFailed", "ValidationFailed") } {
                $globalStats.Failed++
                $divStats[$div].Failed++
            }
        }
    }
    elseif ($isMigrating) {
        # Migrating stage
        $globalStats.Migrating++
        $divStats[$div].Migrating++
    }
    elseif ($isQueued) {
        # Queued stage
        $globalStats.Queued++
        $divStats[$div].Queued++
    }
    elseif ($hasTargetURL) {
        # Waiting at Resolved stage (has target, not queued/migrating/complete)
        $globalStats.WaitingResolved++
        $divStats[$div].WaitingResolved++
    }
    elseif ($hasScanned) {
        # Awaiting Target stage (has size, no target yet)
        $globalStats.AwaitingTarget++
        $divStats[$div].AwaitingTarget++
    }
    else {
        # Awaiting Scan (no TotalSize yet)
        $globalStats.AwaitingScan++
        $divStats[$div].AwaitingScan++
    }
}

# Complete breakdown already counted above

Write-Log "Statistics calculated" "SUCCESS"

# ============================================================
# LOOK UP ACTUAL VIEW URLs FROM SHAREPOINT
# ============================================================
# Views are created by Import-MigrationSources.ps1. SharePoint may sanitize
# the .aspx filename (strip hyphens, etc.) so we cannot assume <DIV>.aspx.
# Read the real ServerRelativeUrl for each view and use that for row hrefs.

Write-Log "Looking up view URLs..."

$viewUrlMap = @{}
try {
    $existingViews = Invoke-WithThrottling -Operation "Get list views" -ScriptBlock {
        Get-PnPView -List $listName -ErrorAction Stop
    }
    foreach ($v in $existingViews) {
        if (-not [string]::IsNullOrWhiteSpace($v.Title) -and `
            -not [string]::IsNullOrWhiteSpace($v.ServerRelativeUrl) -and `
            -not $viewUrlMap.ContainsKey($v.Title)) {
            $viewUrlMap[$v.Title] = $v.ServerRelativeUrl
        }
    }
    Write-Log "Mapped $($viewUrlMap.Count) view URL(s)" "SUCCESS"
}
catch {
    Write-Log "View lookup failed: $($_.Exception.Message)" "WARN"
    Write-Log "Falling back to guessed <DIV>.aspx URLs" "WARN"
}

# ============================================================
# GENERATE HTML
# ============================================================

Write-Log "Generating dashboard HTML..."

# Convert to EST timezone
$estZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
$estTime = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $estZone)
$updateTime = $estTime.ToString("MM-dd-yyyy h") + $estTime.ToString("tt").ToLower() + " EST (updated every 2 hrs)"
$sitePath = ([Uri]$siteUrl).AbsolutePath  # e.g. /sites/000001

# Build DIV rows sorted by name
$divRowsHtml = ""
$rowNum = 0
foreach ($div in ($divStats.Keys | Sort-Object)) {
    $stats = $divStats[$div]
    $rowNum++
    $rowBg = if ($rowNum % 2 -eq 0) { "background: #fafafa;" } else { "" }
    
    # Calculate complete for this DIV (already tracked cumulatively)
    $divComplete = $stats.Complete

    # Prefer the real ServerRelativeUrl reported by SharePoint; fall back to
    # the legacy <DIV>.aspx guess only if no view is mapped.
    $divViewUrl = if ($viewUrlMap.ContainsKey($div)) {
        $viewUrlMap[$div]
    } else {
        "$sitePath/Lists/$listName/$div.aspx"
    }

    $divRowsHtml += @"
                    <tr style="border-bottom: 1px solid #dee2e6; $rowBg">
                        <td style="padding: 10px 6px; font-weight: bold;"><a href="$divViewUrl" style="color: #0078d4; text-decoration: none;">$div</a></td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $stats.TotalSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $stats.SevenYrSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $stats.FiveYrSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $stats.ThreeYrSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right; color: #28a745; font-weight: bold;">$(Format-SizeGB $stats.MigratedSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #495057;">$($stats.AwaitingScan)</td>
                        <td style="padding: 10px 6px; text-align: center;">$($stats.Scanned)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #007bff;">$($stats.Resolved)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #fd7e14;">$($stats.Queued)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #e65100;">$($stats.Migrating)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #28a745; font-weight: bold;">$($stats.Migrated)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #ffc107;">$($stats.MigratedWithErrors)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #dc3545;">$($stats.Failed)</td>
                    </tr>
"@
}

$dashboardHtml = @"
<div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; max-width: 1400px; margin: 0 auto;">
    
    <!-- Header -->
    <div style="background: linear-gradient(180deg, #002868 0%, #0a1628 100%); color: white; padding: 30px; border-radius: 8px; margin-bottom: 30px; box-shadow: 0 4px 16px rgba(0,0,0,0.4);">
        <h1 style="margin: 0 0 10px 0; font-size: 28px; color: #d4af37; text-transform: uppercase; letter-spacing: 2px;">Common Drive Migration Dashboard</h1>
        <p style="margin: 0; font-size: 14px; color: #8b9ab8;">Last Updated $updateTime</p>
    </div>
    
    <!-- Size Summary (Scanned Items Only) -->
    <div style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 30px;">
        <div style="flex: 1; min-width: 180px; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #17a2b8;">
            <div style="font-size: 14px; color: #666; margin-bottom: 5px;">Total Size (Scanned)</div>
            <div style="font-size: 28px; font-weight: bold; color: #17a2b8;">$(Format-SizeGB $globalStats.TotalSizeGB)</div>
        </div>
        <div style="flex: 1; min-width: 180px; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #0078d4;">
            <div style="font-size: 14px; color: #666; margin-bottom: 5px;">7yr Size</div>
            <div style="font-size: 28px; font-weight: bold; color: #0078d4;">$(Format-SizeGB $globalStats.SevenYrSizeGB)</div>
        </div>
        <div style="flex: 1; min-width: 180px; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #6f42c1;">
            <div style="font-size: 14px; color: #666; margin-bottom: 5px;">5yr Size</div>
            <div style="font-size: 28px; font-weight: bold; color: #6f42c1;">$(Format-SizeGB $globalStats.FiveYrSizeGB)</div>
        </div>
        <div style="flex: 1; min-width: 180px; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #e83e8c;">
            <div style="font-size: 14px; color: #666; margin-bottom: 5px;">3yr Size</div>
            <div style="font-size: 28px; font-weight: bold; color: #e83e8c;">$(Format-SizeGB $globalStats.ThreeYrSizeGB)</div>
        </div>
        <div style="flex: 1; min-width: 180px; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #28a745;">
            <div style="font-size: 14px; color: #666; margin-bottom: 5px;">Migrated</div>
            <div style="font-size: 28px; font-weight: bold; color: #28a745;">$(Format-SizeGB $globalStats.MigratedSizeGB)</div>
        </div>
        <div style="flex: 1; min-width: 180px; background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #6c757d;">
            <div style="font-size: 14px; color: #666; margin-bottom: 5px;">UNC Folders Scanned</div>
            <div style="font-size: 28px; font-weight: bold; color: #6c757d;">$($globalStats.Scanned)</div>
        </div>
    </div>
    
    <!-- Pipeline Flow -->
    <div style="background: white; border-radius: 8px; padding: 25px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 30px;">
        <h2 style="margin: 0 0 20px 0; font-size: 18px; color: #333;">Migration Pipeline</h2>
        <div style="display: flex; align-items: stretch; gap: 0; justify-content: center;">
            
            <!-- Awaiting Scan -->
            <div style="flex: 1; max-width: 180px; text-align: center;">
                <div style="background: #495057; color: white; padding: 10px; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: bold;">Awaiting Scan</div>
                <div style="background: #e9ecef; border: 2px solid #495057; border-top: none; padding: 20px 10px; min-height: 80px;">
                    <div style="font-size: 36px; font-weight: bold; color: #495057;">$($globalStats.AwaitingScan)</div>
                    <div style="font-size: 11px; color: #666; margin-top: 8px;">New Items<br>Entered</div>
                </div>
            </div>
            
            <!-- Arrow -->
            <div style="display: flex; align-items: center; padding: 0 5px; color: #adb5bd; font-size: 24px;">&#8594;</div>
            
            <!-- Awaiting Target -->
            <div style="flex: 1; max-width: 180px; text-align: center;">
                <div style="background: #6c757d; color: white; padding: 10px; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: bold;">Awaiting Target</div>
                <div style="background: #f8f9fa; border: 2px solid #6c757d; border-top: none; padding: 20px 10px; min-height: 80px;">
                    <div style="font-size: 36px; font-weight: bold; color: #6c757d;">$($globalStats.AwaitingTarget)</div>
                    <div style="font-size: 11px; color: #666; margin-top: 8px;">Scanned, Needs<br>Target Resolution</div>
                </div>
            </div>
            
            <!-- Arrow -->
            <div style="display: flex; align-items: center; padding: 0 5px; color: #adb5bd; font-size: 24px;">&#8594;</div>
            
            <!-- Target Resolved -->
            <div style="flex: 1; max-width: 180px; text-align: center;">
                <div style="background: #007bff; color: white; padding: 10px; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: bold;">Resolved</div>
                <div style="background: #e7f1ff; border: 2px solid #007bff; border-top: none; padding: 20px 10px; min-height: 80px;">
                    <div style="font-size: 36px; font-weight: bold; color: #007bff;">$($globalStats.Resolved)</div>
                    <div style="font-size: 11px; color: #666; margin-top: 8px;">Have Target URL<br>(cumulative)</div>
                </div>
            </div>
            
            <!-- Arrow -->
            <div style="display: flex; align-items: center; padding: 0 5px; color: #adb5bd; font-size: 24px;">&#8594;</div>
            
            <!-- Queued -->
            <div style="flex: 1; max-width: 180px; text-align: center;">
                <div style="background: #fd7e14; color: white; padding: 10px; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: bold;">Queued</div>
                <div style="background: #fff8e6; border: 2px solid #fd7e14; border-top: none; padding: 20px 10px; min-height: 80px;">
                    <div style="font-size: 36px; font-weight: bold; color: #fd7e14;">$($globalStats.Queued)</div>
                    <div style="font-size: 11px; color: #666; margin-top: 8px;">Awaiting Processing</div>
                </div>
            </div>
            
            <!-- Arrow -->
            <div style="display: flex; align-items: center; padding: 0 5px; color: #adb5bd; font-size: 24px;">&#8594;</div>
            
            <!-- Migrating -->
            <div style="flex: 1; max-width: 180px; text-align: center;">
                <div style="background: #e65100; color: white; padding: 10px; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: bold;">Migrating</div>
                <div style="background: #fff3cd; border: 2px solid #e65100; border-top: none; padding: 20px 10px; min-height: 80px;">
                    <div style="font-size: 36px; font-weight: bold; color: #e65100;">$($globalStats.Migrating)</div>
                    <div style="font-size: 11px; color: #666; margin-top: 8px;">Active</div>
                    <div style="font-size: 9px; color: #999; margin-top: 4px; font-style: italic;">*May be low during day</div>
                </div>
            </div>
            
            <!-- Arrow -->
            <div style="display: flex; align-items: center; padding: 0 5px; color: #adb5bd; font-size: 24px;">&#8594;</div>
            
            <!-- Complete -->
            <div style="flex: 1; max-width: 180px; text-align: center;">
                <div style="background: #28a745; color: white; padding: 10px; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: bold;">Complete</div>
                <div style="background: #e8f5e9; border: 2px solid #28a745; border-top: none; padding: 20px 10px; min-height: 80px;">
                    <div style="font-size: 36px; font-weight: bold; color: #28a745;">$($globalStats.Complete)</div>
                    <div style="font-size: 11px; margin-top: 8px;">
                        <span style="color: #28a745;" title="Migrated">&#10003;$($globalStats.Migrated)</span> 
                        <span style="color: #ffc107;" title="MigratedWithErrors">&#9888;$($globalStats.MigratedWithErrors)</span> 
                        <span style="color: #dc3545;" title="Failed">&#10007;$($globalStats.Failed)</span>
                    </div>
                </div>
            </div>
            
        </div>
    </div>
    
    <!-- DIV Details Table -->
    <div style="background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h2 style="margin: 0 0 15px 0; font-size: 18px; color: #333;">Division Breakdown</h2>
        <div style="overflow-x: auto;">
            <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
                <thead>
                    <tr style="background: #f8f9fa; border-bottom: 2px solid #dee2e6;">
                        <th style="padding: 10px 6px; text-align: left;">Division</th>
                        <th style="padding: 10px 6px; text-align: right;">Total</th>
                        <th style="padding: 10px 6px; text-align: right;">7yr</th>
                        <th style="padding: 10px 6px; text-align: right;">5yr</th>
                        <th style="padding: 10px 6px; text-align: right;">3yr</th>
                        <th style="padding: 10px 6px; text-align: right; background: #d4edda;">Migrated</th>
                        <th style="padding: 10px 6px; text-align: center; background: #e9ecef;">Await</th>
                        <th style="padding: 10px 6px; text-align: center; background: #f8f9fa;">Scan</th>
                        <th style="padding: 10px 6px; text-align: center; background: #e7f1ff;">Res</th>
                        <th style="padding: 10px 6px; text-align: center; background: #fff8e6;">Q</th>
                        <th style="padding: 10px 6px; text-align: center; background: #fff3cd;">Mig</th>
                        <th style="padding: 10px 6px; text-align: center; background: #d4edda;">&#10003;</th>
                        <th style="padding: 10px 6px; text-align: center; background: #fff3cd;">&#9888;</th>
                        <th style="padding: 10px 6px; text-align: center; background: #f8d7da;">&#10007;</th>
                    </tr>
                </thead>
                <tbody>
$divRowsHtml
                </tbody>
                <tfoot>
                    <tr style="background: #e9ecef; font-weight: bold; border-top: 2px solid #dee2e6;">
                        <td style="padding: 10px 6px;">TOTAL</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $globalStats.TotalSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $globalStats.SevenYrSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $globalStats.FiveYrSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right;">$(Format-SizeGB $globalStats.ThreeYrSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: right; color: #28a745;">$(Format-SizeGB $globalStats.MigratedSizeGB)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #495057;">$($globalStats.AwaitingScan)</td>
                        <td style="padding: 10px 6px; text-align: center;">$($globalStats.Scanned)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #007bff;">$($globalStats.Resolved)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #fd7e14;">$($globalStats.Queued)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #e65100;">$($globalStats.Migrating)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #28a745;">$($globalStats.Migrated)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #ffc107;">$($globalStats.MigratedWithErrors)</td>
                        <td style="padding: 10px 6px; text-align: center; color: #dc3545;">$($globalStats.Failed)</td>
                    </tr>
                </tfoot>
            </table>
        </div>
        <div style="margin-top: 10px; font-size: 12px; color: #666; text-align: right;">
            <strong>Legend:</strong> &#10003; Migrated | &#9888; Migrated w/Errors | &#10007; Failed
        </div>
    </div>
    
    <!-- Footer -->
    <div style="margin-top: 20px; padding: 15px; text-align: center; color: #666; font-size: 12px;">
        <p>Dashboard refreshes every 2 hours. Click a division name to view details.</p>
        <p><a href="$sitePath/SitePages/MigrationStatus.aspx" style="color: #0078d4;">Return to Landing Page</a> | <a href="$sitePath/Lists/$listName/AllItems.aspx" style="color: #0078d4;">View All Items</a></p>
    </div>
    
</div>
"@

# ============================================================
# CREATE/UPDATE PAGE
# ============================================================

Write-Log "Creating/updating dashboard page..."

# Check if page exists
$existingPage = Invoke-WithThrottling -Operation "Check page exists" -ScriptBlock {
    Get-PnPPage -Identity $PageName -ErrorAction SilentlyContinue
}

if ($existingPage) {
    Write-Log "Page exists - removing for recreation" "DEBUG"
    Invoke-WithThrottling -Operation "Remove existing page" -ScriptBlock {
        Remove-PnPPage -Identity $PageName -Force -ErrorAction Stop
    }
}

# Create new page
Write-Log "Creating page: $PageName"
Invoke-WithThrottling -Operation "Create page" -ScriptBlock {
    Add-PnPPage -Name $PageName -LayoutType Home -ErrorAction Stop | Out-Null
}

# Remove the default header image/banner
Write-Log "Configuring page header..."
Invoke-WithThrottling -Operation "Set page header" -ScriptBlock {
    Set-PnPPage -Identity $PageName -HeaderLayoutType NoImage -Title "Migration Dashboard" -ErrorAction Stop
}

# Add text web part with dashboard HTML
Write-Log "Adding dashboard content..."
Invoke-WithThrottling -Operation "Add content" -ScriptBlock {
    Add-PnPPageTextPart -Page $PageName -Text $dashboardHtml -ErrorAction Stop
}

# Publish page
Write-Log "Publishing page..."
Invoke-WithThrottling -Operation "Publish page" -ScriptBlock {
    Set-PnPPage -Identity $PageName -Publish -ErrorAction Stop
}

# Disconnect
Disconnect-PnPOnline -ErrorAction SilentlyContinue

# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   DASHBOARD UPDATED" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Page: $siteUrl/SitePages/$PageName.aspx" -ForegroundColor White
Write-Host "  Divisions: $($divStats.Count)" -ForegroundColor White
Write-Host "  Total Items: $($globalStats.TotalItems)" -ForegroundColor White
Write-Host "  Complete: $($globalStats.Complete) (Migrated: $($globalStats.Migrated), Errors: $($globalStats.MigratedWithErrors), Failed: $($globalStats.Failed))" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
