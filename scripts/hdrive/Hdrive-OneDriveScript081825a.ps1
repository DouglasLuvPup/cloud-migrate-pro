<# 08/18/25a
.SYNOPSIS
OneDrive Migration Tool - Enterprise-grade solution for migrating user home directories to SharePoint Online OneDrive with complete Active Directory integration and throttling protection.

.DESCRIPTION
This comprehensive enterprise migration tool automates the transition from on-premises file shares to SharePoint Online OneDrive. 
It provides a complete end-to-end solution with both staged and final migration capabilities, tracking through SharePoint lists, 
full integration with Active Directory, and robust throttling protection.

Key features:
- Multi-phase migration workflow:
  * Stage phase: Initial content copy without AD changes
  * Migration phase: Final content copy with full AD property updates and permissions changes
  * Credential management with stored credentials and reset options
- Multiple data source options:
  * CSV file-based user selection with sophisticated file management and categorization
  * Direct SharePoint list integration for centralized tracking with pagination
  * Interactive file selection UI with filtering, sorting, and pagination
  * Timestamped file renaming for tracking and audit purposes
- Comprehensive OneDrive preparation:
  * Automated user license verification through AD group membership
  * OneDrive provisioning with verification and retry logic
  * Site collection administrator assignments for migration accounts
  * Custom handling for SpecialGroup-designated users
  * UPN validation and error handling
- Extensive Active Directory integration:
  * Update user profile attributes (wwwHomePage, unixHomeDirectory)
  * Clear legacy home directory mappings (HomeDrive, HomeDirectory)
  * Remove from redirection groups based on pattern matching or specific lists
  * Support for SharePoint-defined redirection groups (RedirectGP column)
  * Add to Office 365 target groups
  * Detailed error tracking with categorization by operation type
- Security controls:
  * Automatic ACL modifications for source directories (read-only after migration)
  * Background process handles deep folder structures with retry logic
  * Separate PowerShell processes for ACL operations to prevent blocking
  * Progressive updates of permissions with visual progress indicators
- Complete SharePoint Migration Tool (SPMT) integration:
  * Configurable blocked file extensions
  * Detailed migration reporting and error logging
  * Failure report consolidation and analysis
  * SPMT session cleanup and management
  * Configurable root folder handling
  * Custom character replacement for invalid characters
- Post-migration content organization:
  * Advanced "My Documents" content handling with folder restructuring
  * Intelligent file movement from "My Documents" to "Documents/Documents"
  * Preservation of folder hierarchies during content reorganization
  * Error handling for content reorganization failures
  * Support for nested folder structures within "My Documents"
  * Connection state preservation during reorganization
- Enterprise-ready features:
  * Support for postponed migrations via date tracking
  * Error capture with detailed categorization
  * Secure credential management with local caching
  * Attachment management for error reports with retry logic
  * Robust error handling and connection management
  * Registry optimization for long path support
  * Detailed transcript logging with timestamps
  * Server name tracking for distributed operations
  * Clean-up of stale SPMT sessions
  * PnP connection caching and status verification
  * Robust folder creation with error handling
  * Source path existence verification
  * Multiple field verification with fallback options
  * Start and completion date tracking for migrations
  * Server identification for distributed operations
  * Detailed error categorization in SharePoint list
- SharePoint Online Throttling Protection:
  * Exponential backoff retry mechanism
  * Multi-level throttling detection
  * Operation-specific retry counters
  * Hierarchical retry scopes for operations
  * Detailed throttling event logging

Migration Workflow:
1. Users choose migration operation type and data source through an interactive menu
2. For CSV sources, users select from categorized file lists with filtering options
3. Tool validates user licensing status through AD group membership checks
4. OneDrive is provisioned with multiple verification attempts if needed
5. System creates "Documents" folder structure in OneDrive as needed
6. SharePoint Migration Tool (SPMT) operations execute with file extension filtering
7. Migration errors are captured, categorized, and consolidated into reports
8. Error reports are attached to SharePoint list items with retry logic
9. Active Directory properties are updated for migrated users
10. Source directory permissions are modified to read-only via background process
11. "My Documents" content is reorganized into "Documents/Documents" with hierarchy preservation
12. Migration status is updated in SharePoint tracking list with detailed categorization
13. Detailed logging is maintained for auditing and troubleshooting

Status Tracking:
- Stage: Initial staging marked for processing
- Staged: Successfully completed staging with no errors
- StagedWithErrors: Completed staging with documented errors
- Migrate: Final migration marked for processing
- Migrated: Successfully completed migration with no errors
- ErrorLog: Completed migration with documented errors
- ManualLog: Migration completed but error reporting needs manual review
- Unlicensed: User lacks required O365 license
- Invalid UPN: Missing or invalid user principal name
- Failed: Migration or AD updates failed
- Processing: Currently being processed

.PARAMETER None
This script uses an interactive menu for operation selection.

.EXAMPLE
.\OneDriveMigrationTool.ps1
# Run the script and follow interactive prompts to select migration type and source

.NOTES
Version: 5.2
Created June 03, 2024
Last Updated: April 15, 2025
Author: Douglas Cox [Microsoft CSA)
Requirements:
- PowerShell 5.1 or higher
- SharePoint Online Management Shell
- SharePoint Migration Tool
- PnP.PowerShell module 1.12
- Active Directory module

This script should be run with administrative privileges to ensure proper 
access to file shares and Active Directory objects.

The script is designed to be run on a server with access to:
- User home directories
- Active Directory
- SharePoint Online via modern authentication
- SharePoint Migration Tool

# Throttling Pattern Implementation
# 
# This script implements a consistent pattern for handling SharePoint Online throttling:
#
# 1. Detection: All API calls check for throttling-specific error messages:
#    - Error messages containing "throttled"
#    - HTTP status codes 429 (Too Many Requests) or 503 (Service Unavailable)
#
# 2. Retry Strategy: When throttling is detected, implement exponential backoff
#    - Each retry waits longer than the previous one (base_time * 2^retry_count)
#    - Maintain separate retry counters for different operation types
#    - Maximum retry limits prevent endless loops
#
# 3. Operation Scopes: Throttling protection is implemented at multiple levels:
#    - Individual operation level (e.g., moving a single file) 
#    - Batch operation level (e.g., all files in a folder)
#    - Function level (e.g., the entire Move-MyDocumentsContent process)
#
# 4. Recovery: After a throttling delay, operations are resumed from the appropriate point:
#    - Some operations retry just the failed action
#    - Some operations restart from the beginning when needed
#    - All operations preserve and restore connection state when appropriate
#
# 5. Reporting: Detailed logging of throttling events is maintained:
#    - Clear status messages show wait times and retry attempts
#    - Error logging captures complete information about throttled operations
#    - SharePoint list statuses are updated to reflect throttling-related issues

# Error Handling Strategy
#
# This script implements comprehensive error handling with these key features:
#
# 1. Categorized Errors: All errors are categorized by type for clearer troubleshooting:
#    - LICENSE: Issues related to Office 365 licensing status
#    - UPN: Issues with User Principal Name validation
#    - ONEDRIVE PROVISIONING: OneDrive creation/verification issues
#    - ATTACHMENT: Problems with SharePoint list attachment operations
#    - CONTENT MOVE: Errors during My Documents reorganization
#    - AD ScriptError: Active Directory update issues
#    - PERMISSION ERROR: Access denied scenarios
#    - USER NOT FOUND: Missing AD accounts
#    - GENERAL ERROR: Miscellaneous failures
#
# 2. Persistent Error Recording: All errors are recorded in SharePoint for future analysis:
#    - Errors are stored in the "ScriptError" field of list items
#    - Multiple errors for the same user are appended with proper categorization
#    - Error field updates use the same throttling protection as other operations
#
# 3. Graceful Degradation: On failure, the script attempts to complete other operations:
#    - AD updates occur even if OneDrive provisioning has issues
#    - Error states are properly reflected in SharePoint tracking columns
#    - Migration continues for other users even when individual migrations fail
#
# 4. Detailed Logging: Comprehensive transcript logs capture all operations:
#    - Color-coded console output highlights errors visually
#    - All error messages include exception details and stack traces
#    - Each user migration creates a dedicated log file for later troubleshooting
#
# 5. State Management: The script maintains clean state even after errors:
#    - "Processing" flags are cleared after errors to allow future retry attempts
#    - SharePoint connections are properly restored after errors
#    - SPMT sessions are properly cleaned up even after failures

.LINK
Internal Documentation: will add once completed
#>

$toolversion = "5.2"

# Location for User to Stage/Migrate CSVs
$MigrationUsersLists = "F:\Migration-Users-Lists"

# Site URLs and configuration
$siteUrl = "https://contoso.spo.microsoft.scloud/sites/000001"
$adminUrl = "https://contoso-admin.spo.microsoft.scloud/"
$mySharePointUrl = "https://contoso-my.spo.microsoft.scloud" # Base URL for all OneDrive sites

# Function to generate OneDrive URL for a user
function Get-OneDriveUrl {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName
    )
    
    return "$mySharePointUrl/personal/$($UserPrincipalName.Replace('@', '_').Replace('.', '_'))"
}

# Domain
$domain = "@contoso.gov"

# Groups configuration
$removeGroup = "SecFltr-USR-OneDrive"
$targetGroup = "SecFltr-USR-Office365"
$targetGroup2 = "O365S-AddOn-License"

# Find all groups that match the pattern
#$groupPattern = "*REDIRECTION*"
#$groups = Get-ADGroup -Filter "Name -like '$groupPattern'"

# SharePoint list configuration
$listName = "USER-Hdrive OneDrive Migration Status"
$targetdocumentlibrary = "Documents"

# Site Collection Admin GUIDs
$SCA02 = "c:0t.c|tenant|eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"  # OneDriveAdminGroup
$SCA03 = "c:0t.c|tenant|ffffffff-ffff-ffff-ffff-ffffffffffff"  # TenantAdminsGroup

# Define credential path
$CredentialPath = "$env:USERPROFILE\SPMTCred.xml"
$SPOCredential = $null

$script:PnPConnectionCache = @{}

# ACL Temp Dir
$TempPath = "F:\Temp"
if (-not (Test-Path $TempPath)) {
    New-Item -Path $TempPath -ItemType Directory -Force | Out-Null
}

# Define functions for checking connections
function Is-SPOServiceConnected {
    Write-Host "Checking if there is an active connection to SPO Admin..." -ForegroundColor Green
    try {
        $spoContext = Get-SPOSite -ErrorAction Stop
        if ($spoContext) {
            Write-Host "Active connection to SPO Admin found..." -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "No active connection to SPO Admin..." -ForegroundColor Green
        return $false
    }
}

# Function to check if there is an active connection to PnPOnline
function Is-PnPOnlineConnected {
    Write-Host "Checking if there is an active connection to PnPOnline..." -ForegroundColor Green
    try {
        $pnpContext = Get-PnPConnection -ErrorAction Stop
        if ($pnpContext -and $pnpContext.Url) {
            Write-Host "Active connection to PnPOnline found at $($pnpContext.Url)..." -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "No active connection to PnPOnline... Please Wait..." -ForegroundColor Green
        return $false
    }
}

function Test-SPOCredentials {
    param (
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        # Attempt to connect to SPO service with the credentials
        Write-Host "Validating credentials..." -ForegroundColor Yellow
        $tempAdmin = Connect-SPOService -Url $adminUrl 
        
        # If we get here, credentials were valid
        Write-Host "Credentials validated successfully." -ForegroundColor Green
        
        # Disconnect from the temporary session
        #Disconnect-SPOService
        return $true
    }
    catch {
        Write-Host "Credential validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Purpose: Establishes and validates SharePoint Online connections with throttling awareness
# Creates a reliable connection to SharePoint that can recover from intermittent issues
# and implements proper retry logic for throttled connections.

function Ensure-PnPConnection {
    param (
        [switch]$ForceReconnect,
        [string]$Url = $siteUrl
    )
    
    try {
        # First check if we have a valid context
        $hasValidContext = $false
        try {
            $context = Get-PnPContext -ErrorAction Stop
            if ($context) {
                $hasValidContext = $true
                Write-Host "Current PnP connection has a valid context" -ForegroundColor Green
            }
        } catch {
            Write-Host "Current connection has no valid SharePoint context" -ForegroundColor Yellow
            $hasValidContext = $false
        }
        
        # If we don't have a valid context or forcing reconnect, we need a new connection
        if ($ForceReconnect -or -not $hasValidContext) {
            Write-Host "Establishing new PnP connection to $Url..." -ForegroundColor Yellow
            
            # Disconnect current session if there is one
            try {
                Disconnect-PnPOnline -ErrorAction SilentlyContinue
            } catch {
                # Ignore errors on disconnect
            }
            
            # Connect with a clean session - with throttling retry
            $retryCount = 0
            $maxRetries = 3
            $connectionSuccess = $false
            
            while (-not $connectionSuccess -and $retryCount -lt $maxRetries) {
                try {
                    Connect-PnPOnline -Url $Url -UseWebLogin -ErrorAction Stop
                    
                    # Verify connection worked
                    $context = Get-PnPContext -ErrorAction Stop
                    if (-not $context) {
                        throw "Failed to establish a valid context after connection"
                    }
                    
                    $connectionSuccess = $true
                    Write-Host "PnP connection established successfully to $Url" -ForegroundColor Green
                }
                catch {
                    if ($_.Exception.Message -like "*throttled*" -or 
                        $_.Exception.Message -like "*429*" -or
                        $_.Exception.Message -like "*503*") {
                        
                        $retryCount++
                        $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries -InitialWaitTimeSeconds 10
                        
                        if (-not $shouldRetry) {
                            Write-Host "Failed to establish PnP connection after throttling retries: $($_.Exception.Message)" -ForegroundColor Red
                            return $false
                        }
                    }
                    else {
                        Write-Host "Failed to establish PnP connection: $($_.Exception.Message)" -ForegroundColor Red
                        
                        # Always try one more time with a clean connection on failure
                        try {
                            Write-Host "Attempting one more connection with clean session..." -ForegroundColor Yellow
                            Disconnect-PnPOnline -ErrorAction SilentlyContinue
                            Start-Sleep -Seconds 3
                            Connect-PnPOnline -Url $Url -UseWebLogin -ErrorAction Stop
                            Write-Host "Second connection attempt successful" -ForegroundColor Green
                            return $true
                        } catch {
                            Write-Host "Final connection attempt failed: $($_.Exception.Message)" -ForegroundColor Red
                            return $false
                        }
                    }
                }
            }
            
            return $connectionSuccess
        }
        else {
            Write-Host "Using existing PnP connection with valid context" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "Failed to establish PnP connection: $($_.Exception.Message)" -ForegroundColor Red
        
        # Always try one more time with a clean connection on failure
        try {
            Write-Host "Attempting one more connection with clean session..." -ForegroundColor Yellow
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            Connect-PnPOnline -Url $Url -UseWebLogin -ErrorAction Stop
            Write-Host "Second connection attempt successful" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "Final connection attempt failed: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
}

# Function to save credentials securely to XML (for SPMT)
function Save-SPMTCredentials {
    param (
        [System.Management.Automation.PSCredential]$Credential
    )
    try {
        $Credential | Export-Clixml -Path $CredentialPath
        Write-Host "Credentials saved successfully to $CredentialPath." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to save credentials: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to load saved credentials from XML (for SPMT)
function Load-SPMTCredentials {
    if (Test-Path $CredentialPath) {
        try {
            $script:SPOCredential = Import-Clixml -Path $CredentialPath
            Write-Host "Loaded saved credentials for SPMT: $($script:SPOCredential.UserName)" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Failed to load saved credentials: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    return $false
}

# Try to load saved credentials first
$credResult = Load-SPMTCredentials

# Only prompt for credentials if none were loaded
if (-not $credResult) {
    # Get Credentials for SPO
    $fullUsername = "$domain"
    Write-Host "No saved credentials found. Prompting for SharePoint Online credentials..." -ForegroundColor Yellow
    $SPOCredential = Get-Credential -Message "SPO ADMIN UPN/Pass" -UserName $fullUsername
    
    if ($SPOCredential) {
        if (Test-SPOCredentials -Credential $SPOCredential) {
            Save-SPMTCredentials -Credential $SPOCredential
            Write-Host "Credentials validated and saved for future use." -ForegroundColor Green
        } else {
            Write-Host "Invalid credentials. Please try again." -ForegroundColor Red
            $SPOCredential = $null
        }
    } else {
        Write-Host "No credentials provided. SPMT migrations may fail." -ForegroundColor Red
    }
} else {
    Write-Host "Using saved SPO credentials." -ForegroundColor Green
}

# Check if SPOCredential is already set
if (-not $SPOCredential) {
    # Get Credentials for SPO
    $fullUsername = "$domain"
    $SPOCredential = Get-Credential -Message "SPO ADMIN UPN/Pass" -UserName $fullUsername
    if ($SPOCredential) {
        Save-SPMTCredentials -Credential $SPOCredential
    }
} else {
    Write-Host "Using existing SPO credentials." -ForegroundColor Green
}

# Establish connections with modern authentication
if (-not (Is-SPOServiceConnected)) {
    Write-Host "Connecting to SPO Admin interactively (MFA Required)..." -ForegroundColor Yellow
    try {
        Connect-SPOService -Url $adminUrl -ErrorAction Stop  # Interactive login
        Write-Host "Connected to SPO Admin successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to connect to SPO Admin: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
}
else {
    Write-Host "Using existing SPO Admin connection." -ForegroundColor Green
}

# Function to silently stop any running SPMT migrations and unregister any existing sessions
function Invoke-SilentSPMTCommand {
    param (
        [scriptblock]$Command
    )
    try {
        & $Command | Out-Null
    } catch {
        # Silently ignore any errors
    }
}

# Purpose: Implements exponential backoff when SharePoint throttling is detected
# This function calculates appropriate wait times that increase exponentially with each retry
# to comply with SharePoint Online's throttling mechanisms and service limits.

function Handle-SPOThrottling {
    param (
        [int]$RetryCount = 0,
        [int]$MaxRetries = 5,
        [int]$InitialWaitTimeSeconds = 5
    )
    
    if ($RetryCount -ge $MaxRetries) {
        Write-Host "Maximum retry attempts reached. Operation failed." -ForegroundColor Red
        return $false
    }
    
    $waitTime = $InitialWaitTimeSeconds * [Math]::Pow(2, $RetryCount)
    Write-Host "Throttling detected. Waiting for $waitTime seconds before retrying..." -ForegroundColor Yellow
    Start-Sleep -Seconds $waitTime
    return $true
}

function Get-SPOListUsers {
    param (
        [string]$MigrationType
    )
    Write-Host "Getting users set for $MigrationType from SharePoint list" -ForegroundColor Cyan
    
    # First ensure PnP connection is working with a valid context
    if (-not (Ensure-PnPConnection -ForceReconnect)) {
        Write-Host "Failed to establish PnP connection before accessing SharePoint list" -ForegroundColor Red
        return $null
    }
    
    $retryCount = 0
    $maxRetries = 3
    
    while ($retryCount -lt $maxRetries) {
        try {
            # Verify context is valid before proceeding
            try {
                $context = Get-PnPContext -ErrorAction Stop
                if (-not $context) {
                    throw "No valid SharePoint context found"
                }
            } catch {
                Write-Host "Reconnecting due to invalid context..." -ForegroundColor Yellow
                if (-not (Ensure-PnPConnection -ForceReconnect)) {
                    throw "Failed to establish a valid context even after forced reconnection"
                }
            }
            
            # Get all list items with throttling awareness
            $listItems = $null
            try {
                Write-Host "Retrieving list items (with throttling awareness)..." -ForegroundColor Yellow
                $listItems = Get-PnPListItem -List $listName -PageSize 500 -ErrorAction Stop
            }
            catch {
                if ($_.Exception.Message -like "*throttled*" -or 
                    $_.Exception.Message -like "*429*" -or
                    $_.Exception.Message -like "*503*") {
                    
                    $retryCount++
                    $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries -InitialWaitTimeSeconds 15
                    
                    if ($shouldRetry) {
                        continue  # Try again after delay
                    } else {
                        throw "Failed to retrieve list items after throttling retries"
                    }
                }
                else {
                    throw  # Re-throw for non-throttling errors
                }
            }
            
            # Get current date for postpone filter
            $currentDate = Get-Date
            
            # For debugging - show some info about the postpone field in the first item
            if ($listItems.Count -gt 0) {
                $firstItem = $listItems[0]
            }
            
            # Filter based on migration type
            $filteredItems = @()
            foreach ($item in $listItems) {
                $migrate = $item["Migrate"]
                $processing = $item["Processing"]
                $sourcePath = $item["SourcePath"]
                $targetURL = $item["TargetURL"]
                $title = $item["Title"]
                
                # Try to get postpone date
                $postponeDate = $null
                foreach ($fieldName in @("Postpone", "postpone", "POSTPONE", "PostPone")) {
                    if ($null -ne $item[$fieldName]) {
                        $postponeDate = $item[$fieldName]
                        break
                    }
                }
                
                # Basic filtering
                if ($MigrationType -eq "Stage" -and 
                    $migrate -eq "Stage" -and 
                    $processing -ne "Processing" -and
                    -not [string]::IsNullOrWhiteSpace($sourcePath) -and
                    -not [string]::IsNullOrWhiteSpace($targetURL)) {
                    
                    # Postpone check
                    if ($postponeDate -and $postponeDate -gt $currentDate) {
                        Write-Host "Filtering out $title - postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
                    } else {
                        $filteredItems += $item
                    }
                }
                elseif ($MigrationType -eq "Migrate" -and 
                        $migrate -eq "Migrate" -and 
                        $processing -ne "Processing" -and
                        -not [string]::IsNullOrWhiteSpace($sourcePath) -and
                        -not [string]::IsNullOrWhiteSpace($targetURL)) {
                    
                    # Postpone check
                    if ($postponeDate -and $postponeDate -gt $currentDate) {
                        Write-Host "Filtering out $title - postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
                    } else {
                        $filteredItems += $item
                    }
                }
            }
            
            Write-Host "Found $($filteredItems.Count) users set for $MigrationType" -ForegroundColor Green
            return $filteredItems
        }
        catch {
            if ($_.Exception.Message -like "*throttled*" -or 
                $_.Exception.Message -like "*429*" -or
                $_.Exception.Message -like "*503*") {
                
                $retryCount++
                $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries -InitialWaitTimeSeconds 15
                
                if ($shouldRetry) {
                    continue  # Try again after delay
                }
            }
            
            Write-Host "Error getting users from SharePoint list: $($_.Exception.Message)" -ForegroundColor Red
            
            # Try one more time with a forced reconnection
            Write-Host "Attempting one more connection..." -ForegroundColor Yellow
            if (-not (Ensure-PnPConnection -ForceReconnect)) {
                Write-Host "Failed to re-establish connection. Cannot access SharePoint list." -ForegroundColor Red
                return $null
            }
            
            try {
                $listItems = Get-PnPListItem -List $listName -PageSize 2000 -ErrorAction Stop
                # Continue with processing using the same filtering logic
                
                # Get current date for postpone filter
                $currentDate = Get-Date
                
                # Filter based on migration type
                $filteredItems = @()
                foreach ($item in $listItems) {
                    $migrate = $item["Migrate"]
                    $processing = $item["Processing"]
                    $sourcePath = $item["SourcePath"]
                    $targetURL = $item["TargetURL"]
                    $title = $item["Title"]
                    
                    # Try to get postpone date
                    $postponeDate = $null
                    foreach ($fieldName in @("Postpone", "postpone", "POSTPONE", "PostPone")) {
                        if ($null -ne $item[$fieldName]) {
                            $postponeDate = $item[$fieldName]
                            break
                        }
                    }
                    
                    # Basic filtering - same logic as above
                    if ($MigrationType -eq "Stage" -and 
                        $migrate -eq "Stage" -and 
                        $processing -ne "Processing" -and
                        -not [string]::IsNullOrWhiteSpace($sourcePath) -and
                        -not [string]::IsNullOrWhiteSpace($targetURL)) {
                        
                        # Postpone check
                        if ($postponeDate -and $postponeDate -gt $currentDate) {
                            Write-Host "Filtering out $title - postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
                        } else {
                            $filteredItems += $item
                        }
                    }
                    elseif ($MigrationType -eq "Migrate" -and 
                            $migrate -eq "Migrate" -and 
                            $processing -ne "Processing" -and
                            -not [string]::IsNullOrWhiteSpace($sourcePath) -and
                            -not [string]::IsNullOrWhiteSpace($targetURL)) {
                        
                        # Postpone check
                        if ($postponeDate -and $postponeDate -gt $currentDate) {
                            Write-Host "Filtering out $title - postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
                        } else {
                            $filteredItems += $item
                        }
                    }
                }
                
                Write-Host "Found $($filteredItems.Count) users set for $MigrationType after reconnection" -ForegroundColor Green
                return $filteredItems
            }
            catch {
                Write-Host "Final attempt failed: $($_.Exception.Message)" -ForegroundColor Red
                return $null
            }
        }
    }
    
    # If we get here, we've exhausted our retries
    Write-Host "Maximum retries exceeded when getting users from SharePoint list" -ForegroundColor Red
    return $null
}

# Centralized function to get postpone date from SharePoint list item
function Get-PostponeDate {
    param (
        [Parameter(Mandatory=$true)]
        $ListItem
    )
    
    $postponeDate = $null
    
    # Try multiple field name variations (prioritize the actual field name "PostPone")
    $fieldVariations = @("PostPone", "Postpone", "postpone", "POSTPONE", "Postponed", "DelayUntil")
    
    foreach ($fieldName in $fieldVariations) {
        try {
            $value = $ListItem[$fieldName]
            if ($null -ne $value -and $value -ne "") {
                # Handle different date formats
                if ($value -is [DateTime]) {
                    $postponeDate = $value
                    Write-Host "Found postpone date using field '$fieldName': $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Green
                    break
                } elseif ($value -is [string]) {
                    # Try to parse string as date
                    $parsedDate = $null
                    if ([DateTime]::TryParse($value, [ref]$parsedDate)) {
                        $postponeDate = $parsedDate
                        Write-Host "Found postpone date (parsed from string) using field '$fieldName': $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Green
                        break
                    }
                }
            }
        } catch {
            # Continue to next field variation
            continue
        }
    }
    
    return $postponeDate
}

# Centralized function to check if an item should be postponed
function Test-IsPostponed {
    param (
        [Parameter(Mandatory=$true)]
        $ListItem,
        [Parameter(Mandatory=$false)]
        [DateTime]$CurrentDate = (Get-Date)
    )
    
    $postponeDate = Get-PostponeDate -ListItem $ListItem
    
    if ($null -eq $postponeDate) {
        return $false
    }
    
    # Compare dates (ignore time component for day-based comparison)
    $postponeDateOnly = $postponeDate.Date
    $currentDateOnly = $CurrentDate.Date
    
    $isPostponed = $postponeDateOnly -gt $currentDateOnly
    
    if ($isPostponed) {
        $username = if ($ListItem["Title"]) { $ListItem["Title"] } else { "Unknown User" }
        Write-Host "User $username is postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
    }
    
    return $isPostponed
}

# Add this function to reset processing status for postponed users
function Reset-PostponedUserStatus {
    param (
        [Parameter(Mandatory=$true)]
        $ListItem,
        [Parameter(Mandatory=$true)]
        [string]$ListName
    )
    
    try {
        Set-PnPListItem -List $ListName -Identity $ListItem.Id -Values @{
            "Processing" = ""
        }
        $username = if ($ListItem["Title"]) { $ListItem["Title"] } else { "Unknown User" }
        Write-Host "Reset Processing status for postponed user $username" -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "Error resetting Processing status: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to clear saved credentials
function Clear-SavedCredentials {
    if (Test-Path $CredentialPath) {
        try {
            Remove-Item -Path $CredentialPath -Force
            Write-Host "Saved credentials successfully deleted from $CredentialPath" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Failed to delete credentials: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "No saved credentials found at $CredentialPath" -ForegroundColor Yellow
        return $true
    }
}

# Present enhanced migration type selection menu with SPO List options
Clear-Host
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "      OneDrive Migration Tool v$toolversion" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Select Migration Type:" -ForegroundColor Yellow
Write-Host "1: CSV Stage Only" -ForegroundColor Green
Write-Host "2: CSV Migrate Only" -ForegroundColor Green
Write-Host "3: SPO List Stage" -ForegroundColor Green
Write-Host "4: SPO List Migrate (special group)" -ForegroundColor Green
Write-Host "5: Clear Saved Credentials" -ForegroundColor Yellow
Write-Host ""

do {
    $selection = Read-Host "Enter your selection (1-5)"
    switch ($selection) {
        "1" { $MigrationType = "Stage"; $SourceType = "CSV" }
        "2" { $MigrationType = "Migrate"; $SourceType = "CSV" }
        "3" { $MigrationType = "Stage"; $SourceType = "SPOList" }
        "4" { $MigrationType = "Migrate"; $SourceType = "SPOList" }
        "5" { $MigrationType = "ClearCreds" }
        default { 
            Write-Host "Invalid selection. Please enter 1-5" -ForegroundColor Red 
            $MigrationType = $null
        }
    }
} while ($null -eq $MigrationType)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Running script in $MigrationType mode" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($MigrationType -eq "ClearCreds") {
    if (Clear-SavedCredentials) {
        Write-Host "Credentials have been cleared." -ForegroundColor Green
        Write-Host "Please enter new credentials:" -ForegroundColor Yellow
        
        # Prompt for new credentials
        $fullUsername = "$domain"
        $SPOCredential = Get-Credential -Message "SPO ADMIN UPN/Pass" -UserName $fullUsername
        
        if ($SPOCredential) {
            # Add validation here
            if (Test-SPOCredentials -Credential $SPOCredential) {
                Save-SPMTCredentials -Credential $SPOCredential
                Write-Host "New credentials validated and saved. Continuing to migration selection." -ForegroundColor Green
                
                # Ensure PnP connection is still active after credential change
                Write-Host "Reconnecting to PnP Online with new credentials..." -ForegroundColor Yellow
                    if (-not (Ensure-PnPConnection -ForceReconnect)) {
                Write-Host "Failed to establish PnP connection with new credentials. Please restart the script." -ForegroundColor Red
            exit
            }
                # Prompt again for migration type
                Write-Host ""
                Write-Host "Select Migration Type:" -ForegroundColor Yellow
                Write-Host "1: Stage Only (CSV)" -ForegroundColor Green
                Write-Host "2: Migrate Only (CSV)" -ForegroundColor Green
                Write-Host "3: Process Users Set to Stage (SPO List)" -ForegroundColor Green
                Write-Host "4: Process Users Set to Migrate (SPO List)" -ForegroundColor Green
                Write-Host ""
                
                do {
                    $selection = Read-Host "Enter your selection (1-4)"
                    switch ($selection) {
                        "1" { $MigrationType = "Stage"; $SourceType = "CSV" }
                        "2" { $MigrationType = "Migrate"; $SourceType = "CSV" }
                        "3" { $MigrationType = "Stage"; $SourceType = "SPOList" }
                        "4" { $MigrationType = "Migrate"; $SourceType = "SPOList" }
                        default { 
                            Write-Host "Invalid selection. Please enter 1-4" -ForegroundColor Red 
                            $MigrationType = $null
                        }
                    }
                } while ($null -eq $MigrationType)
            
            } else {
                Write-Host "Invalid credentials. Please restart the script and try again." -ForegroundColor Red
                exit
            }
            
            Write-Host ""
            Write-Host "============================================" -ForegroundColor Cyan
            Write-Host "Running script in $MigrationType mode" -ForegroundColor Cyan
            Write-Host "============================================" -ForegroundColor Cyan
            Write-Host ""
        } else {
            Write-Host "No credentials provided. Exiting script." -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "Failed to clear credentials. You may need to manually delete $CredentialPath" -ForegroundColor Red
        exit
    }
}

# Function to prompt for credentials if needed
function Get-UserCredentials {
    # Default domain for credential prompt
    $fullUsername = "$domain"
    
    Write-Host "Prompting for SharePoint Online credentials..." -ForegroundColor Yellow
    $cred = Get-Credential -Message "SPO ADMIN UPN/Pass" -UserName $fullUsername
    if ($cred) {
        $script:SPOCredential = $cred
        Save-SPMTCredentials -Credential $cred
        return $cred
    }
    return $null
}

# Filtered menu function based on migration type with an option to see all files
function Select-CSVFile {
    param (
        [string]$MigrationType,
        [string]$CsvFolder = $MigrationUsersLists
    )
    
    # Ensure the CSV folder exists
    if (-not (Test-Path $CsvFolder)) {
        Write-Host "Error: CSV folder not found at $CsvFolder" -ForegroundColor Red
        return $null
    }
    
    # Get all CSV files in the folder
    $csvFiles = Get-ChildItem -Path $CsvFolder -Filter "*.csv"
    
    if ($csvFiles.Count -eq 0) {
        Write-Host "No CSV files found in $CsvFolder" -ForegroundColor Red
        return $null
    }
    
    # Group files by type
    $stagedFiles = $csvFiles | Where-Object { $_.Name -like "Staged_*" }
    $migratedFiles = $csvFiles | Where-Object { $_.Name -like "Migrated_*" }
    $unprocessedFiles = $csvFiles | Where-Object { 
        ($_.Name -notlike "Staged_*") -and ($_.Name -notlike "Migrated_*") 
    }
    
    # Initially filter files based on MigrationType
    $filesToShow = @()
    $viewMode = "Filtered"
    
    if ($MigrationType -eq "Stage") {
        # For Stage, show only unprocessed files
        $filesToShow = $unprocessedFiles
    }
    elseif ($MigrationType -eq "Migrate") {
        # For Migrate, show only staged files
        $filesToShow = $stagedFiles
    }
    
    # Store file info in custom objects
    function Get-FileInfo {
        param (
            [System.IO.FileInfo[]]$Files,
            [string]$Category
        )
        
        $fileInfoArray = @()
        
        foreach ($file in $Files) {
            # Get record count
            $recordCount = 0
            try {
                $csvContent = Import-Csv -Path $file.FullName
                $recordCount = ($csvContent | Measure-Object).Count
            } catch {
                $recordCount = "Error"
            }
            
            $fileInfo = [PSCustomObject]@{
                Category = $Category
                Name = $file.Name
                LastModified = $file.LastWriteTime
                Records = $recordCount
                File = $file
            }
            
            $fileInfoArray += $fileInfo
        }
        
        return $fileInfoArray
    }
    
    # Process files into info objects
    $unprocessedFileInfo = Get-FileInfo -Files $unprocessedFiles -Category "NEW"
    $stagedFileInfo = Get-FileInfo -Files $stagedFiles -Category "STAGED"
    $migratedFileInfo = Get-FileInfo -Files $migratedFiles -Category "MIGRATED"
    
    # Function to display the compact menu
    function Show-FilteredMenu {
        param (
            [array]$FilesToDisplay,
            [string]$ViewMode,
            [int]$Page = 1,
            [int]$PageSize = 6
        )
        
        Clear-Host
        
        # Create index map for selection
        $global:fileIndexMap = @{}
        $displayedFiles = @()
        $index = 1
        
        # Calculate total pages
        $totalFiles = $FilesToDisplay.Count
        $totalPages = [math]::Ceiling($totalFiles / $PageSize)
        
        # Handle empty results
        if ($totalFiles -eq 0) {
            $totalPages = 1
        }
        
        # Ensure page is within bounds
        if ($Page -lt 1) { $Page = 1 }
        if ($Page -gt $totalPages) { $Page = $totalPages }
        
        # Display simplified header
        Write-Host "===== OneDrive Migration Tool v$toolversion =====" -ForegroundColor Cyan
        Write-Host "Mode: $MigrationType | View: $ViewMode | Files: $totalFiles | Pg $Page/$totalPages" -ForegroundColor White
        Write-Host "---------------------------------------------" -ForegroundColor Cyan
        
        if ($ViewMode -ne "Filtered") {
            Write-Host "Showing ALL files. Press [F] to filter by migration type." -ForegroundColor Yellow
        }
        else {
            if ($MigrationType -eq "Stage") {
                Write-Host "Showing NEW files only. Press [A] to view all files." -ForegroundColor Yellow
            }
            elseif ($MigrationType -eq "Migrate") {
                Write-Host "Showing STAGED files only. Press [A] to view all files." -ForegroundColor Yellow
            }
        }
        
        # Determine which files to display on current page
        if ($totalFiles -gt 0) {
            $startIdx = ($Page - 1) * $PageSize
            $endIdx = [Math]::Min($startIdx + $PageSize - 1, $totalFiles - 1)
            $displayedFiles = $FilesToDisplay[$startIdx..$endIdx]
        }
        
        $currentCategory = ""
        
        # Display files with category headers
        if ($displayedFiles.Count -gt 0) {
            foreach ($info in $displayedFiles) {
                # Check if we need to show a new category header
                if ($info.Category -ne $currentCategory) {
                    $currentCategory = $info.Category
                    
                    # Select background color based on category
                    $bgColor = switch ($currentCategory) {
                        "NEW" { "DarkBlue" }
                        "STAGED" { "DarkGreen" }
                        "MIGRATED" { "DarkMagenta" }
                        default { "DarkGray" }
                    }
                    
                    Write-Host "$($info.Category):" -ForegroundColor White -BackgroundColor $bgColor
                }
                
                # Display file info
                Write-Host "$index : " -NoNewline -ForegroundColor Cyan
                Write-Host "$($info.Name)" -ForegroundColor White
                Write-Host "   " -NoNewline
                Write-Host "$($info.LastModified.ToString('MM/dd HH:mm'))" -NoNewline -ForegroundColor Yellow
                Write-Host " | Records: " -NoNewline
                Write-Host "$($info.Records)" -ForegroundColor Yellow
                
                # Store in index map
                $global:fileIndexMap[$index] = $info.File
                $index++
            }
        }
        else {
            if ($MigrationType -eq "Stage" -and $ViewMode -eq "Filtered") {
                Write-Host "`nNo NEW files found to stage." -ForegroundColor Yellow
                Write-Host "Press [A] to view all files." -ForegroundColor Cyan
            }
            elseif ($MigrationType -eq "Migrate" -and $ViewMode -eq "Filtered") {
                Write-Host "`nNo STAGED files found to migrate." -ForegroundColor Yellow
                Write-Host "Press [A] to view all files." -ForegroundColor Cyan
            }
            else {
                Write-Host "`nNo files found matching your criteria." -ForegroundColor Yellow
            }
        }
        
        # Display simplified navigation
        Write-Host "---------------------------------------------" -ForegroundColor Cyan
        $navOptions = "[#] Select, [N]ext, [P]rev"
        if ($ViewMode -eq "Filtered") {
            $navOptions += ", [A]ll files"
        }
        else {
            $navOptions += ", [F]ilter files"
        }
        Write-Host "Enter: $navOptions" -ForegroundColor White
    }
    
    # Initial file list based on migration type
    $filesToDisplay = switch ($viewMode) {
        "Filtered" {
            if ($MigrationType -eq "Stage") { 
                $unprocessedFileInfo 
            }
            elseif ($MigrationType -eq "Migrate") { 
                $stagedFileInfo 
            }
            else {
                $unprocessedFileInfo + $stagedFileInfo + $migratedFileInfo
            }
        }
        default { 
            $unprocessedFileInfo + $stagedFileInfo + $migratedFileInfo
        }
    }
    
    # Initial display
    $currentPage = 1
    $pageSize = 6
    Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
    
    # Process user input for navigation and selection
    do {
        $input = Read-Host ">"
        
        switch -Regex ($input) {
            "^[nN]$" {
                # Next page
                $currentPage++
                Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
            }
            "^[pP]$" {
                # Previous page
                $currentPage--
                Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
            }
            "^[aA]$" {
                # Show all files
                $viewMode = "All"
                $filesToDisplay = $unprocessedFileInfo + $stagedFileInfo + $migratedFileInfo
                $currentPage = 1
                Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
            }
            "^[fF]$" {
                # Filter files by migration type
                $viewMode = "Filtered"
                $filesToDisplay = if ($MigrationType -eq "Stage") {
                    $unprocessedFileInfo
                }
                elseif ($MigrationType -eq "Migrate") {
                    $stagedFileInfo
                }
                else {
                    $unprocessedFileInfo + $stagedFileInfo + $migratedFileInfo
                }
                $currentPage = 1
                Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
            }
            "^\d+$" {
                # Select file by number
                $selectedIndex = [int]$input
                
                if ($global:fileIndexMap.ContainsKey($selectedIndex)) {
                    $selectedFile = $global:fileIndexMap[$selectedIndex]
                    
                    # Create the new filename with migration type, original name and timestamp
                    $timestamp = Get-Date -Format "MM-dd-yy_HHmm"
                    $originalFileName = [System.IO.Path]::GetFileNameWithoutExtension($selectedFile.Name)
                    $newFileName = if ($MigrationType -eq "Stage") {
                    "Staged_${originalFileName}_${timestamp}.csv"
    } elseif ($MigrationType -eq "Migrate") {
                    "Migrated_${originalFileName}_${timestamp}.csv"
    } else {
                    "${MigrationType}_${originalFileName}_${timestamp}.csv"
}
                    $newFilePath = Join-Path -Path $CsvFolder -ChildPath $newFileName
                    $newFilePath = Join-Path -Path $CsvFolder -ChildPath $newFileName
                    
                    # Confirm selection in a compact way
                    Clear-Host
                    Write-Host "===== Confirm Selection =====" -ForegroundColor Cyan
                    Write-Host "Selected: " -NoNewline
                    Write-Host "$($selectedFile.Name)" -ForegroundColor Yellow
                    Write-Host "Rename to: " -NoNewline
                    Write-Host "$newFileName" -ForegroundColor Green
                    Write-Host "Confirm? (Y/N): " -NoNewline
                    
                    $confirm = Read-Host
                    if ($confirm -match "^[yY]$") {
                        # Rename the selected file
                        Rename-Item -Path $selectedFile.FullName -NewName $newFileName
                        Write-Host "`nRenamed to: $newFileName" -ForegroundColor Green
                        # Return the new file path
                        return $newFilePath
                    }
                    else {
                        # Return to menu if not confirmed
                        Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
                    }
                }
                else {
                    Write-Host "Invalid selection." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                    Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
                }
            }
            default {
                Write-Host "Invalid input." -ForegroundColor Red
                Start-Sleep -Seconds 1
                Show-FilteredMenu -FilesToDisplay $filesToDisplay -ViewMode $viewMode -Page $currentPage -PageSize $pageSize
            }
        }
    } while ($true)
}

# Initialize processing arrays
$itemsToProcess = @()

# Process based on source type (UPDATED CSV SECTION)
if ($SourceType -eq "CSV") {
    # CSV processing logic
    $selectedCsvPath = Select-CSVFile -MigrationType $MigrationType
    if (-not $selectedCsvPath) {
        Write-Host "No CSV file selected. Exiting script." -ForegroundColor Red
        exit
    }
    
    # Get the selected CSV filename for use in logs
    $selectedCsvName = Split-Path -Path $selectedCsvPath -Leaf
    Write-Host "Using CSV file: $selectedCsvName" -ForegroundColor Green
    
    # Load users from selected CSV file
    Write-Host "Loading users from CSV: $selectedCsvPath" -ForegroundColor Cyan
    $csvUsers = Import-Csv -Path $selectedCsvPath
    Write-Host "Found $(($csvUsers | Measure-Object).Count) users in CSV file" -ForegroundColor Green
    
    # Ensure PnP connection is active before getting list items
    if (-not (Ensure-PnPConnection)) {
        Write-Host "Failed to establish PnP connection. Exiting script." -ForegroundColor Red
        exit
    }
    
    # Get SharePoint list items
    try {
        Write-Host "Getting SharePoint list items..." -ForegroundColor Cyan
        $listItems = Get-PnPListItem -List $listName -PageSize 2000 -ErrorAction Stop
        Write-Host "Retrieved $(($listItems | Measure-Object).Count) items from SharePoint list" -ForegroundColor Green
    }
    catch {
        Write-Host "Error getting SharePoint list items: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
    
    # Process users from CSV
    foreach ($csvUser in $csvUsers) {
        # Find corresponding list item for each user in the CSV
        $username = $csvUser.Username
        if ([string]::IsNullOrWhiteSpace($username)) {
            Write-Host "Error: Found empty username in CSV. Skipping this entry." -ForegroundColor Red
            continue
        }
        
        Write-Host "Processing user: $username" -ForegroundColor Yellow
        $item = $listItems | Where-Object { $_["Title"] -eq $username }
        
        if ($null -eq $item) {
            Write-Host "Error: User $username not found in SharePoint list. Skipping this user." -ForegroundColor Red
            continue
        }
        
        $site = $item["SourcePath"]
        
        # Check for postpone using the centralized function
        if (Test-IsPostponed -ListItem $item) {
            Write-Host "Skipping $username - postponed" -ForegroundColor Yellow
            continue
        }
                
        # Add to items to process
        if ($MigrationType -eq "Stage") {
            if ($item["Migrate"] -ne "Stage" -and $item["Migrate"] -ne "Staged" -and $item["Processing"] -ne "Processing") {
                $itemsToProcess += [PSCustomObject]@{
                    SourcePath = $site
                    Username = $username
                    ItemId = $item.Id
                }
                Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                    "Migrate" = "Stage"
                    "Processing" = "Processing"
                    "Server" = $Env:COMPUTERNAME
                }
                Write-Host "Added $username to Stage queue" -ForegroundColor Green
            } else {
                Write-Host "Skipping $username - already processed or in progress (Status: $($item["Migrate"]))" -ForegroundColor Yellow
            }
        } elseif ($MigrationType -eq "Migrate") {
            if ($item["Migrate"] -ne "Migrate" -and $item["Migrate"] -ne "Migrated" -and $item["Processing"] -ne "Processing") {
                $itemsToProcess += [PSCustomObject]@{
                    SourcePath = $site
                    Username = $username
                    ItemId = $item.Id
                }
                Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                    "Migrate" = "Migrate"
                    "Processing" = "Processing"
                    "Server" = $Env:COMPUTERNAME
                }
                Write-Host "Added $username to Migrate queue" -ForegroundColor Green
            } else {
                Write-Host "Skipping $username - already processed or in progress (Status: $($item["Migrate"]))" -ForegroundColor Yellow
            }
        }
    }
} else {

# SPO List processing (UPDATED)
    $selectedUsers = Get-SPOListUsers -MigrationType $MigrationType
    if ($null -eq $selectedUsers -or $selectedUsers.Count -eq 0) {
        Write-Host "No eligible users found in SPO list. Exiting script." -ForegroundColor Red
        exit
    }

    # Refresh list item data - this is important!
    $listItems = Get-PnPListItem -List $listName -PageSize 2000

    # Add to items to process
    $itemsToProcess = @()
    foreach ($user in $selectedUsers) {
        # First find the full list item to access all fields reliably
        $listItem = $listItems | Where-Object { $_.Id -eq $user.Id }
        
        if ($null -eq $listItem) {
            continue
        }
        
        # Now get user data from the full list item
        $username = $listItem["Title"]
        $sourcePath = $listItem["SourcePath"]
        
        # Final postpone check using centralized function
        if (Test-IsPostponed -ListItem $listItem) {
            Write-Host "Skipping $username - postponed" -ForegroundColor Yellow
            continue
        }
        
        # Store information
        $itemInfo = [PSCustomObject]@{
            SourcePath = $sourcePath
            Username = $username
            ItemId = $listItem.Id
        }
        
        # Update the Processing status
        try {
            Set-PnPListItem -List $listName -Identity $listItem.Id -Values @{
                "Processing" = "Processing"
                "Server" = $Env:COMPUTERNAME
            }
            Write-Host "Updated $username status to Processing" -ForegroundColor Green
            $itemsToProcess += $itemInfo
        }
        catch {
            Write-Host "Error updating SPO List for Processing: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "Added $(($itemsToProcess | Measure-Object).Count) users to process queue" -ForegroundColor Green

# For SPO List processing option (options 3 & 4), ensure we also have list items
if ($SourceType -eq "SPOList" -and $itemsToProcess.Count -gt 0) {
    # We need to get the list items again if we don't have them yet
    if ($null -eq $listItems) {
        $listItems = Get-PnPListItem -List $listName -PageSize 2000
    }
    
    # Get direct matches to ensure we have full item data
    Write-Host "Verifying items from SPO List against full list item collection..." -ForegroundColor Cyan
    $verifiedItems = @()
    
    foreach ($itemInfo in $itemsToProcess) {
        $site = $itemInfo.SourcePath
        $username = $itemInfo.Username
        $itemId = $itemInfo.ItemId
        
        Write-Host "Trying to verify: Username=$username, ID=$itemId, Path=$site" -ForegroundColor Yellow
        
        # First try to look up by ID which is more reliable
        $matchItem = $null
        if ($null -ne $itemId -and $itemId -gt 0) {
            try {
                $matchItem = Get-PnPListItem -List $listName -Id $itemId -ErrorAction SilentlyContinue
                
                if ($null -ne $matchItem) {
                    # Verify it's the right user as a double-check
                    if ($matchItem["Title"] -eq $username) {
                        # Additional postpone check
                        $postponeDate = $matchItem["Postpone"]
                        $currentDate = Get-Date
                        if ($postponeDate -and $postponeDate -gt $currentDate) {
                            Write-Host "Skipping verification for $username - postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
                            continue
                        }
                        
                        $verifiedItems += $itemInfo  # Keep the full object
                        Write-Host "Verified item by ID for username: $username (ID: $itemId)" -ForegroundColor Green
                        continue
                    }
                }
            } catch {
                Write-Host "Error looking up by ID: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # If we get here, we couldn't find by ID, so try by username and path
        foreach ($listItem in $listItems) {
            try {
                # Match on BOTH path AND username
                if ($listItem["SourcePath"] -eq $site -and 
                    $listItem["Title"] -eq $username) {
                    
                    # Additional postpone check
                    $postponeDate = $listItem["Postpone"]
                    $currentDate = Get-Date
                    if ($postponeDate -and $postponeDate -gt $currentDate) {
                        Write-Host "Skipping verification for $username - postponed until $($postponeDate.ToString('MM/dd/yyyy'))" -ForegroundColor Yellow
                        break
                    }
                    
                    $matchItem = $listItem
                    $verifiedItems += $itemInfo  # Keep the full object
                    Write-Host "Verified item by path/name for source path: $site and username: $username" -ForegroundColor Green
                    break
                }
            } catch {
                # Continue to next item if there's an issue accessing this one
                continue
            }
        }
        
        if ($null -eq $matchItem) {
            Write-Host "Warning: Could not find or verify item for source path $site and username $username in SharePoint list." -ForegroundColor Red
            # Reset processing status for this user if we can find it
            try {
                if ($null -ne $itemId -and $itemId -gt 0) {
                    Set-PnPListItem -List $listName -Identity $itemId -Values @{
                        "Processing" = ""
                    }
                    Write-Host "Reset Processing status for unverified user $username" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error resetting Processing status: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Use only verified items
    $itemsToProcess = $verifiedItems
    Write-Host "Verified $(($itemsToProcess | Measure-Object).Count) items for processing" -ForegroundColor Green
}

# Function to check and set required registry keys
function Set-RequiredRegistryKeys {
    Write-Host "Checking and setting required registry keys..." -ForegroundColor Cyan
    
    try {
        $netFrameworkPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\AppContext"
        if (-not (Test-Path $netFrameworkPath)) {
            New-Item -Path $netFrameworkPath -Force | Out-Null
            Write-Host "Created .NETFramework\AppContext registry key" -ForegroundColor Green
        }

        $blockLongPathsValue = (Get-ItemProperty -Path $netFrameworkPath -Name "Switch.System.IO.BlockLongPaths" -ErrorAction SilentlyContinue)."Switch.System.IO.BlockLongPaths"
        if ($blockLongPathsValue -ne "false") {
            Set-ItemProperty -Path $netFrameworkPath -Name "Switch.System.IO.BlockLongPaths" -Value "false" -Type String
            Write-Host "Set Switch.System.IO.BlockLongPaths to false" -ForegroundColor Green
        } else {
            Write-Host "Switch.System.IO.BlockLongPaths already set to false" -ForegroundColor Green
        }

        $useLegacyPathValue = (Get-ItemProperty -Path $netFrameworkPath -Name "Switch.System.IO.UseLegacyPathHandling" -ErrorAction SilentlyContinue)."Switch.System.IO.UseLegacyPathHandling"
        if ($useLegacyPathValue -ne "false") {
            Set-ItemProperty -Path $netFrameworkPath -Name "Switch.System.IO.UseLegacyPathHandling" -Value "false" -Type String
            Write-Host "Set Switch.System.IO.UseLegacyPathHandling to false" -ForegroundColor Green
        } else {
            Write-Host "Switch.System.IO.UseLegacyPathHandling already set to false" -ForegroundColor Green
        }

        $fileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        $longPathsValue = (Get-ItemProperty -Path $fileSystemPath -Name "LongPathsEnabled" -ErrorAction SilentlyContinue).LongPathsEnabled
        if ($longPathsValue -ne 1) {
            Set-ItemProperty -Path $fileSystemPath -Name "LongPathsEnabled" -Value 1 -Type DWord
            Write-Host "Set LongPathsEnabled to 1" -ForegroundColor Green
        } else {
            Write-Host "LongPathsEnabled already set to 1" -ForegroundColor Green
        }

        Write-Host "All registry keys verified and set successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error setting registry keys: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Call the function to set registry keys
if (-not (Set-RequiredRegistryKeys)) {
    Write-Host "Failed to set required registry keys. Script may encounter issues with long paths." -ForegroundColor Red
}

# Function to check if a module is loaded, and if not, load it
function Ensure-Module {
    param (
        [string]$ModuleName
    )    
    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Write-Host "Module $ModuleName not found. Installing...." -ForegroundColor Green
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
    }
    Import-Module -Name $ModuleName
}

# Purpose: Updates error information in SharePoint list items with throttling protection
# Provides consistent error tracking and categorization while implementing
# retry logic for throttled SharePoint operations.

function Update-ScriptErrorField {
    param (
        [string]$ListName,
        [int]$ItemId,
        [string]$ErrorCategory,
        [string]$ErrorMessage,
        [bool]$Append = $true
    )
    
    # Initialize retry counter
    $retryCount = 0
    $maxRetries = 3
    
    while ($retryCount -lt $maxRetries) {
        try {
            # Get current item to retrieve existing ScriptError content
            $listItem = Get-PnPListItem -List $ListName -Id $ItemId -ErrorAction Stop
            $currentErrors = $listItem["ScriptError"]
            
            # Format the new error with category
            $formattedError = "---$ErrorCategory ERROR---`n$ErrorMessage"
            
            # Append or replace errors based on parameter
            $updatedErrors = if ($Append -and -not [string]::IsNullOrEmpty($currentErrors)) {
                "$currentErrors`n$formattedError"
            } else {
                $formattedError
            }
            
            # Update the SharePoint list item
            Set-PnPListItem -List $ListName -Identity $ItemId -Values @{
                "ScriptError" = $updatedErrors
            } -ErrorAction Stop
            
            Write-Host "Updated ScriptError field for item $ItemId with $ErrorCategory error information" -ForegroundColor Yellow
            return $true
        }
        catch {
            if ($_.Exception.Message -like "*throttled*" -or 
                $_.Exception.Message -like "*429*" -or
                $_.Exception.Message -like "*503*") {
                
                $retryCount++
                $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                
                if ($shouldRetry) {
                    # Continue the loop after throttling delay
                    continue
                }
            }
            
            Write-Host "Failed to update ScriptError field: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # If we get here, we've exhausted our retries
    Write-Host "Maximum retries exceeded when updating ScriptError field" -ForegroundColor Red
    return $false
}

# Purpose: Manages migration report attachments in SharePoint lists with throttling awareness
# Handles the cleanup of old reports and attachment of new ones while protecting
# against throttling and maintaining detailed error logs.

function Handle-MigrationReport {
    param (
        [string]$ListName,
        [int]$ItemId,
        [string]$ReportPath,
        [string]$LogPath,
        [string]$Username,
        [int]$MaxRetries = 2
    )
    
    try {
        # First verify file exists before trying anything
        if (-not (Test-Path $ReportPath)) {
            Write-Host "Report file not found at $ReportPath - cannot attach" -ForegroundColor Red
            Update-ScriptErrorField -ListName $ListName -ItemId $ItemId -ErrorCategory "ATTACHMENT" -ErrorMessage "Report file not found at $ReportPath"
            return $false
        }
        
        # Try to remove previous attachment - just one attempt
        try {
            Write-Host "Attempting to remove previous attachment..." -ForegroundColor Yellow
            Remove-PnPListItemAttachment -List $ListName -Identity $ItemId -FileName "FailureSummaryReport2.csv" -Force -ErrorAction SilentlyContinue
            Write-Host "Removed previous attachment (if it existed)" -ForegroundColor Green
        } catch {
            # Just log and continue
            Write-Host "Note: Could not remove previous attachment: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Add delay between operations
        Start-Sleep -Seconds 5
        
        # Try to add the new attachment - limited attempts
        $attachmentAdded = $false
        $retryCount = 0
        
        while (-not $attachmentAdded -and $retryCount -lt $MaxRetries) {
            $retryCount++
            try {
                # Add the new attachment
                Write-Host "Attempting to add attachment (try $retryCount of $MaxRetries)..." -ForegroundColor Yellow
                Add-PnPListItemAttachment -List $ListName -Id $ItemId -Path $ReportPath -ErrorAction Stop
                $attachmentAdded = $true
                Write-Host "Successfully attached migration report" -ForegroundColor Green
            } catch {
                # Handle errors
                if ($_.Exception.Message -like "*throttled*" -or 
                    $_.Exception.Message -like "*429*" -or
                    $_.Exception.Message -like "*503*") {
                    
                    $waitTime = 30 * $retryCount
                    Write-Host "Throttling detected. Waiting $waitTime seconds before retrying..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $waitTime
                } else {
                    Write-Host "Error adding attachment: $($_.Exception.Message)" -ForegroundColor Red
                    
                    if ($retryCount -ge $MaxRetries) {
                        Write-Host "Maximum attachment attempts reached. Moving on." -ForegroundColor Red
                        break
                    }
                    
                    Start-Sleep -Seconds 10
                }
            }
        }
        
        # Update LOG field if attachment was added
        if ($attachmentAdded) {
            $logUpdated = $false
            $retryCount = 0
            
            while (-not $logUpdated -and $retryCount -lt $MaxRetries) {
                $retryCount++
                try {
                    Set-PnPListItem -List $ListName -Identity $ItemId -Values @{
                        "LOG" = "Migration Log: $ReportPath ; Transcript: $LogPath"
                    } -ErrorAction Stop
                    
                    $logUpdated = $true
                    Write-Host "Successfully updated LOG field" -ForegroundColor Green
                } catch {
                    # Handle errors
                    if ($_.Exception.Message -like "*throttled*" -or 
                        $_.Exception.Message -like "*429*" -or
                        $_.Exception.Message -like "*503*") {
                        
                        $waitTime = 15 * $retryCount
                        Write-Host "Throttling detected during LOG update. Waiting $waitTime seconds..." -ForegroundColor Yellow
                        Start-Sleep -Seconds $waitTime
                    } else {
                        Write-Host "Error updating LOG field: $($_.Exception.Message)" -ForegroundColor Red
                        
                        if ($retryCount -ge $MaxRetries) {
                            Write-Host "Maximum LOG update attempts reached. Moving on." -ForegroundColor Red
                            break
                        }
                        
                        Start-Sleep -Seconds 5
                    }
                }
            }
            
            # Even if LOG update failed, consider it a success if attachment was added
            return $true
        } else {
            # Attachment failed
            Write-Host "Failed to attach migration report after $MaxRetries attempts" -ForegroundColor Red
            Update-ScriptErrorField -ListName $ListName -ItemId $ItemId -ErrorCategory "ATTACHMENT" -ErrorMessage "Failed to attach migration report after $MaxRetries attempts"
            return $false
        }
    } catch {
        Write-Host "Fatal error in Handle-MigrationReport: $($_.Exception.Message)" -ForegroundColor Red
        Update-ScriptErrorField -ListName $ListName -ItemId $ItemId -ErrorCategory "ATTACHMENT" -ErrorMessage "Fatal error in attachment handling: $($_.Exception.Message)"
        return $false
    }
}

# Ensure required modules are loaded
Ensure-Module -ModuleName "Microsoft.Online.SharePoint.PowerShell"
Ensure-Module -ModuleName "Microsoft.SharePoint.MigrationTool.PowerShell"
Ensure-Module -ModuleName "ActiveDirectory"
Ensure-Module -ModuleName "PnP.PowerShell"

# Ensure PnP connection is active before getting list items
if (-not (Ensure-PnPConnection)) {
    Write-Host "Failed to establish PnP connection. Exiting script." -ForegroundColor Red
    exit
}

else {
    Write-Host "Using existing PnPOnline connection." -ForegroundColor Green
}

# Purpose: Reorganizes user content from "My Documents" to "Documents/Documents" folder related to legacy folder redirection
# This is a post-migration cleanup step that ensures consistent folder structure in OneDrive
# while preserving all content hierarchies and handling errors appropriately.

function Move-MyDocumentsContent {
    param (
        [Parameter(Mandatory=$true)]
        [string]$targetUrl,
        [Parameter(Mandatory=$true)]
        [string]$userPrincipalName,
        [string]$siteUrl = $siteUrl,
        [int]$ItemId = 0  
    )
    
    $logPath = Join-Path -Path $LogBasePath -ChildPath "MyDocsMove_$($userPrincipalName.Split('@')[0])_$timestamp.log"
    Start-Transcript -Path $logPath
    
    try {
        # ALWAYS make a fresh connection to the target URL
        Write-Host "Connecting to user's OneDrive: $targetUrl" -ForegroundColor Cyan
        
        # Store the current connection to restore later
        $currentConnection = Get-PnPConnection -ErrorAction SilentlyContinue
        
        # Disconnect any existing PnP connection to avoid context issues
        try {
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
        } catch {
            # Ignore errors during disconnect
        }
        
        # Make a fresh connection with full login
        Connect-PnPOnline -Url $targetUrl -UseWebLogin -ErrorAction Stop
        Write-Host "Connected to OneDrive successfully" -ForegroundColor Green
        
        # First create Documents folder inside Documents library if it doesn't exist
        Write-Host "Creating 'Documents' folder inside Documents library..." -ForegroundColor Yellow
        try {
            Add-PnPFolder -Name "Documents" -Folder "Documents" -ErrorAction Stop
            Write-Host "Documents folder created successfully inside Documents library" -ForegroundColor Green
        } 
        catch {
            # If error says folder exists, that's fine
            if ($_.Exception.Message -like "*already exists*") {
                Write-Host "Documents folder already exists inside Documents library" -ForegroundColor Green
            }
            else {
                Write-Host "Error creating Documents folder: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "Will attempt to continue anyway..." -ForegroundColor Yellow
            }
        }
        
        # Now check for My Documents folder
        Write-Host "Checking for 'My Documents' folder in OneDrive..." -ForegroundColor Yellow
        
        # Initialize retry counter for throttling
        $retryCount = 0
        $maxRetries = 5
        $operationSuccess = $false
        
        while (-not $operationSuccess -and $retryCount -lt $maxRetries) {
            try {
                $myDocsFolder = Get-PnPFolder -Url "Documents/My Documents" -ErrorAction SilentlyContinue
                
                if ($myDocsFolder) {
                    Write-Host "Found 'My Documents' folder in OneDrive, proceeding with content move" -ForegroundColor Green
                    $items = Get-PnPFolderItem -FolderSiteRelativeUrl "Documents/My Documents"
                    $totalItems = ($items | Measure-Object).Count
                    Write-Host "Found $totalItems items to move" -ForegroundColor Yellow
                    
                    $movedCount = 0
                    $errorCount = 0
                    $itemRetryCount = 0
                    $processNextItem = $true
                    
                    foreach ($item in $items) {
                        # Skip this item if we need to retry the entire operation
                        if (-not $processNextItem) {
                            break
                        }
                        
                        try {
                            $targetPath = "/personal/$($userPrincipalName.Replace('@','_').Replace('.','_'))/Documents/Documents/$($item.Name)"
                            
                            if ($item.FileSystemObjectType -eq "Folder") {
                                Write-Host "Processing folder: $($item.Name)" -ForegroundColor Yellow
                                $sourceItems = Get-PnPFolderItem -FolderSiteRelativeUrl ($item.ServerRelativeUrl.Replace($siteUrl, ''))
                
                                foreach ($sourceItem in $sourceItems) {
                                    $folderTargetPath = "$targetPath/$($sourceItem.Name)"
                                    
                                    # Try moving the file with throttling handling
                                    $itemMoveRetries = 0
                                    $itemMoveSuccess = $false
                                    
                                    while (-not $itemMoveSuccess -and $itemMoveRetries -lt 3) {
                                        try {
                                            Move-PnPFile -ServerRelativeUrl $sourceItem.ServerRelativeUrl -TargetUrl $folderTargetPath -Force -Overwrite -ErrorAction Stop
                                            $movedCount++
                                            Write-Host "Moved $($sourceItem.Name) to $folderTargetPath ($movedCount items)" -ForegroundColor Green
                                            $itemMoveSuccess = $true
                                        }
                                        catch {
                                            if ($_.Exception.Message -like "*throttled*" -or 
                                                $_.Exception.Message -like "*429*" -or
                                                $_.Exception.Message -like "*503*") {
                                                
                                                $itemMoveRetries++
                                                $shouldRetry = Handle-SPOThrottling -RetryCount $itemMoveRetries -MaxRetries 3 -InitialWaitTimeSeconds 10
                                                
                                                if (-not $shouldRetry) {
                                                    throw  # Re-throw to be caught by outer catch
                                                }
                                            }
                                            else {
                                                # For non-throttling errors, throw immediately
                                                throw
                                            }
                                        }
                                    }
                                }
                            }
                            else {
                                # Try moving the file with throttling handling
                                $itemMoveRetries = 0
                                $itemMoveSuccess = $false
                                
                                while (-not $itemMoveSuccess -and $itemMoveRetries -lt 3) {
                                    try {
                                        Move-PnPFile -ServerRelativeUrl $item.ServerRelativeUrl -TargetUrl $targetPath -Force -Overwrite -ErrorAction Stop
                                        $movedCount++
                                        Write-Host "Moved $($item.Name) to root ($movedCount of $totalItems)" -ForegroundColor Green
                                        $itemMoveSuccess = $true
                                    }
                                    catch {
                                        if ($_.Exception.Message -like "*throttled*" -or 
                                            $_.Exception.Message -like "*429*" -or
                                            $_.Exception.Message -like "*503*") {
                                            
                                            $itemMoveRetries++
                                            $shouldRetry = Handle-SPOThrottling -RetryCount $itemMoveRetries -MaxRetries 3 -InitialWaitTimeSeconds 10
                                            
                                            if (-not $shouldRetry) {
                                                throw  # Re-throw to be caught by outer catch
                                            }
                                        }
                                        else {
                                            # For non-throttling errors, throw immediately
                                            throw
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            $errorCount++
                            Write-Host "Error processing $($item.Name): $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                            
                            # Check if this was a throttling error that persisted after retry attempts
                            if ($_.Exception.Message -like "*throttled*" -or 
                                $_.Exception.Message -like "*429*" -or
                                $_.Exception.Message -like "*503*") {
                                
                                $retryCount++
                                $processNextItem = $false  # Skip to retry the entire operation
                                
                                $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries -InitialWaitTimeSeconds 15
                                if (-not $shouldRetry) {
                                    # Max retries reached, exit the loop
                                    break
                                }
                            }
                        }
                    }
                    
                    # If we processed all items without needing to break for throttling retry
                    if ($processNextItem) {
                        Write-Host "Content move completed. Moved: $movedCount, Errors: $errorCount" -ForegroundColor Cyan
                        $operationSuccess = $true
                    }
                }
                else {
                    Write-Host "No 'My Documents' folder found in OneDrive - nothing to move" -ForegroundColor Yellow
                    $operationSuccess = $true  # No work to do, so mark as success
                }
            }
            catch {
                # Handle throttling for the entire operation
                if ($_.Exception.Message -like "*throttled*" -or 
                    $_.Exception.Message -like "*429*" -or
                    $_.Exception.Message -like "*503*") {
                    
                    $retryCount++
                    $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries -InitialWaitTimeSeconds 15
                    
                    if (-not $shouldRetry) {
                        Write-Host "Error during content move after max retries: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                        
                        # Update ScriptError field if ItemId is provided
                        if ($ItemId -gt 0) {
                            Update-ScriptErrorField -ListName $listName -ItemId $ItemId -ErrorCategory "CONTENT MOVE" -ErrorMessage "Error during content move after max retries: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)"
                        }
                        break  # Exit the retry loop
                    }
                }
                else {
                    # Non-throttling error
                    Write-Host "Error during content move: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                    
                    # Update ScriptError field if ItemId is provided
                    if ($ItemId -gt 0) {
                        Update-ScriptErrorField -ListName $listName -ItemId $ItemId -ErrorCategory "CONTENT MOVE" -ErrorMessage "Error during content move: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)"
                    }
                    break  # Exit the retry loop
                }
            }
        }
        
        # Return to original connection if we had one
        try {
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
            if ($currentConnection) {
                Connect-PnPOnline -Url $currentConnection.Url -UseWebLogin -ErrorAction SilentlyContinue
                Write-Host "Reconnected to original site: $($currentConnection.Url)" -ForegroundColor Green
            }
        } catch {
            Write-Host "Warning: Could not restore original connection: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        return $operationSuccess
    }
    catch {
        Write-Host "Error during content move: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        
        # Update ScriptError field if ItemId is provided and we have the Update-ScriptErrorField function
        if ($ItemId -gt 0 -and (Get-Command -Name "Update-ScriptErrorField" -ErrorAction SilentlyContinue)) {
            Update-ScriptErrorField -ListName $listName -ItemId $ItemId -ErrorCategory "CONTENT MOVE" -ErrorMessage "Error during content move: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)"
        }
        
        # Try to restore the original connection
        try {
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
            if ($currentConnection) {
                Connect-PnPOnline -Url $currentConnection.Url -UseWebLogin -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignore any errors during restoration
        }
        
        return $false
    }
    finally {
        Stop-Transcript
    }
}

# Helper function to ensure a folder exists
function Ensure-PnPFolder {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SiteRelativePath
    )
    
    $folderParts = $SiteRelativePath.Split('/')
    $currentPath = ""
    
    foreach ($part in $folderParts) {
        if ([string]::IsNullOrEmpty($part)) { continue }
        
        $currentPath += "/$part"
        $folder = Get-PnPFolder -Url $currentPath.TrimStart('/') -ErrorAction SilentlyContinue
        
        if (-not $folder) {
            Write-Host "Creating folder: $currentPath" -ForegroundColor Yellow
            $parentPath = $currentPath.Substring(0, $currentPath.LastIndexOf('/'))
            if ([string]::IsNullOrEmpty($parentPath)) { $parentPath = "/" }
            
            Resolve-PnPFolder -SiteRelativePath $currentPath.TrimStart('/')
        }
    }
    
    return Get-PnPFolder -Url $SiteRelativePath.TrimStart('/')
}

# Purpose: Safely removes SharePoint list attachments with throttling protection
# Implements multiple retry attempts when SharePoint throttling occurs to ensure
# reliable attachment management even during high-load periods.

function Remove-PnPAttachmentWithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$List,
        [Parameter(Mandatory=$true)]
        [int]$Identity,
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [int]$MaxRetries = 3
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $errorLogPath = "F:\SPMTLOGS\attachment_errors_${Username}_${timestamp}.log"

    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            Remove-PnPListItemAttachment -List $List -Identity $Identity -FileName $FileName -Force
            return $true
        }
        catch {
            # Check if this is a throttling error
            if ($_.Exception.Message -like "*throttled*" -or 
                $_.Exception.Message -like "*429*" -or
                $_.Exception.Message -like "*503*") {
                
                # Use throttling handler with different retry count
                $shouldRetry = Handle-SPOThrottling -RetryCount $i -MaxRetries $MaxRetries -InitialWaitTimeSeconds 10
                if (-not $shouldRetry) {
                    # Log final failure
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $errorDetails = @"
==================
Time: $timestamp
Attempt: $($i+1)
List: $List
ItemId: $Identity
FileName: $FileName
Username: $Username
Error Type: Throttling
Error Message: $($_.Exception.Message)
Stack Trace: $($_.Exception.StackTrace)
==================

"@
                    Add-Content -Path $errorLogPath -Value $errorDetails
                    Write-Host "Failed to remove attachment after $MaxRetries throttling-aware attempts" -ForegroundColor Red
                    return $false
                }
                # Continue the loop after throttling delay
                continue
            }
            
            # For non-throttling errors, log normally
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $errorDetails = @"
==================
Time: $timestamp
Attempt: $($i+1)
List: $List
ItemId: $Identity
FileName: $FileName
Username: $Username
Error Type: $($_.Exception.GetType().FullName)
Error Message: $($_.Exception.Message)
Stack Trace: $($_.Exception.StackTrace)
==================

"@
            Add-Content -Path $errorLogPath -Value $errorDetails

            Write-Host "Attempt $($i+1) failed. Error logged to: $errorLogPath" -ForegroundColor Red

            if ($i -eq ($MaxRetries - 1)) {
                Write-Host "Failed to remove attachment after $MaxRetries attempts" -ForegroundColor Red
                return $false
            }
            
            # For non-throttling errors, use simpler backoff
            Start-Sleep -Seconds (2 * ($i + 1))
        }
    }
}

# Enhance SPMT cleanup with more aggressive termination
Write-Host "Cleaning up any existing SPMT sessions..." -ForegroundColor Green
Try {
    Stop-SPMTMigration -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
    Unregister-SPMTMigration -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 20
    
    # Forcibly kill any remaining SPMT processes
    Get-Process -Name "Microsoft.SharePoint.Migration*" -ErrorAction SilentlyContinue | 
        Stop-Process -Force -ErrorAction SilentlyContinue
    
    Write-Host "SPMT cleanup completed." -ForegroundColor Green
} Catch {
    Write-Host "SPMT cleanup encountered errors: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Continuing anyway..." -ForegroundColor Yellow
}

# SPMT Working Folder and migrations logs 
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runFolder = "Run_$timestamp"
$LoggingSharePointMigration = Join-Path -Path "F:\SPMTLOGS" -ChildPath $runFolder

if (-not (Test-Path $LoggingSharePointMigration)) {
    New-Item -Path $LoggingSharePointMigration -ItemType Directory -Force | Out-Null
    Write-Host "Created new SPMT logging directory: $LoggingSharePointMigration" -ForegroundColor Green
}

# Logging folder for console output
$LoggingTranscript = "F:\SPMTTranscripts"
if (-not (Test-Path $LoggingTranscript)) {
    New-Item -Path $LoggingTranscript -ItemType Directory -Force | Out-Null
    Write-Host "Created transcript logging directory: $LoggingTranscript" -ForegroundColor Green
}

$logFileName = "Log_${Env:COMPUTERNAME}_${timestamp}.log"
$logFilePath = Join-Path -Path $LoggingTranscript -ChildPath $logFileName
Start-Transcript -Path $logFilePath

$LogBasePath = $LoggingTranscript 

# Define blocked extensions
$BlockedExtensions = @("pst")

# Get SharePoint list items
$listItems = Get-PnPListItem -List $listName -PageSize 2000 -ErrorAction Stop

# Initialize arrays
$userEmails = @()

function Provision-OneDrive {
    param (
        [string[]]$userEmails
    )

    foreach ($userEmail in $userEmails) {
        $oneDriveUrl = Get-OneDriveUrl -UserPrincipalName $userEmail
        
        # Suppress error output and just check if the site exists
        try {
            $site = Get-SPOSite -Identity $oneDriveUrl -ErrorAction SilentlyContinue
            
            if ($null -eq $site) {
                Write-Host "OneDrive site not provisioned for $userEmail. Provisioning now..." -ForegroundColor Yellow
                Request-SPOPersonalSite -UserEmails $userEmail
                Write-Host "Waiting 120 seconds for OneDrive provisioning to complete..." -ForegroundColor Yellow
                Start-Sleep -Seconds 120
                Write-Host "OneDrive provisioned for $userEmail" -ForegroundColor Green
            } else {
                Write-Host "OneDrive already exists for $userEmail" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "OneDrive site not provisioned for $userEmail. Provisioning now..." -ForegroundColor Yellow
            Request-SPOPersonalSite -UserEmails $userEmail
            Write-Host "Waiting 120 seconds for OneDrive provisioning to complete..." -ForegroundColor Yellow
            Start-Sleep -Seconds 120
            Write-Host "OneDrive provisioned for $userEmail" -ForegroundColor Green
        }
    }
}

# Function to verify OneDrive provisioning with retry
function Verify-OneDriveProvisioning {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName,
        [int]$RetryCount,
        [int]$MaxRetries,
        [ref]$ProvisionedRef
    )
    
    $oneDriveUrl = Get-OneDriveUrl -UserPrincipalName $UserPrincipalName
    
    try {
        $oneDriveSite = Get-SPOSite -Identity $oneDriveUrl -ErrorAction SilentlyContinue
        
        if ($null -eq $oneDriveSite) {
            $RetryCount++
            Write-Host "OneDrive not yet provisioned for $UserPrincipalName. Retry attempt $RetryCount of $MaxRetries" -ForegroundColor Yellow
            
            if ($RetryCount -lt $MaxRetries) {
                # Wait longer between each retry (exponential backoff)
                $delaySeconds = 60 * $RetryCount
                Write-Host "Waiting $delaySeconds seconds before checking again..." -ForegroundColor Yellow
                Start-Sleep -Seconds $delaySeconds
                
                # Try to provision again
                Write-Host "Attempting to provision OneDrive again..." -ForegroundColor Yellow
                Provision-OneDrive -userEmails @($UserPrincipalName)
                
                # Return updated retry count
                return $RetryCount
            }
            return $RetryCount  # Max retries reached
        } else {
            $ProvisionedRef.Value = $true
            Write-Host "OneDrive successfully provisioned for $UserPrincipalName" -ForegroundColor Green
            return $RetryCount
        }
    } catch {
        # If an error occurs, it means the site doesn't exist
        $RetryCount++
        Write-Host "OneDrive not yet provisioned for $UserPrincipalName. Retry attempt $RetryCount of $MaxRetries" -ForegroundColor Yellow
        
        if ($RetryCount -lt $MaxRetries) {
            # Wait longer between each retry (exponential backoff)
            $delaySeconds = 60 * $RetryCount
            Write-Host "Waiting $delaySeconds seconds before checking again..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delaySeconds
            
            # Try to provision again
            Write-Host "Attempting to provision OneDrive again..." -ForegroundColor Yellow
            Provision-OneDrive -userEmails @($UserPrincipalName)
        }
        return $RetryCount
    }
}

function Is-UserGroupMember {
    param (
        [string]$targetgroup2,
        $item
    )
    
    $username = $item.FieldValues["Title"]
    
    try {
        Write-Host "Checking membership/O365 License status, $username is member of $targetgroup2" -ForegroundColor Cyan
        
        $user = Get-ADUser -Identity $username -Properties MemberOf -ErrorAction Stop
        $group = Get-ADGroup -Identity $targetgroup2 -ErrorAction Stop
        $groupDN = $group.DistinguishedName

        $isMember = $user.MemberOf -contains $groupDN

        if ($isMember) {
            return $true
        } else {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $username is NOT licensed for O365. Contact UCSU to have user email migrated prior to migrating OneDrive." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        throw
    }
}

# Purpose: Executes SharePoint Migration Tool operations with throttling awareness
# The main migration function that handles licensing verification, OneDrive provisioning,
# content migration, and error reporting with comprehensive throttling protection.

function Invoke-SPMTMigration {
   param(
       $item,
       $site,
       $targeturl,
       $listName,
       [switch]$IsStaged
   )

   $currentDate = (Get-Date).AddHours(0).ToString('MM/dd/yyyy HH:mm:ss')
   
   # Update start date with throttling awareness
   $retryCount = 0
   $maxRetries = 3
   $startDateUpdated = $false
   
   while (-not $startDateUpdated -and $retryCount -lt $maxRetries) {
       try {
           Set-PnPListItem -List $listName -Identity $item.Id -Values @{"StartDate" = $currentDate}
           $startDateUpdated = $true
       }
       catch {
           if ($_.Exception.Message -like "*throttled*" -or 
               $_.Exception.Message -like "*429*" -or
               $_.Exception.Message -like "*503*") {
               
               $retryCount++
               $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
               
               if (-not $shouldRetry) {
                   Write-Host "Failed to update StartDate after throttling retries" -ForegroundColor Red
                   break
               }
           }
           else {
               Write-Host "Failed to update StartDate: $($_.Exception.Message)" -ForegroundColor Red
               break
           }
       }
   }
   
   $username = $item.FieldValues["Title"]

   Write-Host "Initiating migration for $username" -ForegroundColor Cyan
   Write-Host "Source Path: $site" -ForegroundColor Yellow
   Write-Host "Target URL: $targeturl" -ForegroundColor Yellow
   Write-Host "Migration Type: $(if ($IsStaged) {'Staged'} else {'Final'})" -ForegroundColor Yellow
   
   # For Stage operations, perform license check and OneDrive provisioning
   if ($IsStaged) {
       Write-Host "Performing license check for staging operation" -ForegroundColor Yellow
       $isLicensed = $null
       try {
           $isLicensed = Is-UserGroupMember -targetgroup2 $targetGroup2 -item $item
       }
       catch {
           Write-Host "Error checking group membership for $username : $_" -ForegroundColor Red
           $isLicensed = $null
       }

       if ($isLicensed -eq $false) {
           Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - User $username is NOT licensed for O365." -ForegroundColor Yellow
           
           # Update ScriptError field with license error with throttling awareness
           $errorUpdated = $false
           $retryCount = 0
           
           while (-not $errorUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "LICENSE" -ErrorMessage "User is NOT licensed for O365. Contact UCSU to have user email migrated prior to migrating OneDrive." -Append $false
                   $errorUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update ScriptError field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update ScriptError field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }
           
           # Update status field with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "Unlicensed"
                       "Processing" = ""
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }
           
           return $false
       }

       # If we get here, user is licensed for O365
       Write-Host "User $username is licensed for O365. Proceeding with OneDrive provisioning." -ForegroundColor Green
       
       # Provision OneDrive during staging
       $userPrincipalName = $item.FieldValues.UPN
       if (![string]::IsNullOrWhiteSpace($userPrincipalName)) {
           $userEmails = @($userPrincipalName)
           
           # Provision OneDrive before staging
           Write-Host "Provisioning OneDrive for $userPrincipalName" -ForegroundColor Cyan
           Provision-OneDrive -userEmails $userEmails

           # Add a retry mechanism to check for OneDrive provisioning with delay
           $maxProvisionRetries = 3
           $retryCount = 0
           $oneDriveProvisioned = $false

           while (-not $oneDriveProvisioned -and $retryCount -lt $maxProvisionRetries) {
               # Use the verification function
               $retryCount = Verify-OneDriveProvisioning -UserPrincipalName $userPrincipalName -RetryCount $retryCount -MaxRetries $maxProvisionRetries -ProvisionedRef ([ref]$oneDriveProvisioned)
           }

           # Add site collection admins after OneDrive provisioning
           Write-Host "Adding site collection admins..." -ForegroundColor Cyan

           # Add OneDriveAdminGroup to site collection admins
    try {
           Set-SPOUser -Site $targeturl -LoginName $SCA02 -IsSiteCollectionAdmin $true -ErrorAction Stop
           Write-Host "Successfully added OneDriveAdminGroup to OneDrive Site Collection Admin" -ForegroundColor Green
} 
catch {
           Write-Host "Failed to add OneDriveAdminGroup to Site Collection Admin: $($_.Exception.Message)" -ForegroundColor Red
           Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "SITE ADMIN" -ErrorMessage "Failed to add OneDriveAdminGroup: $($_.Exception.Message)"
}

           # Check if SpecialGroup is marked as Yes
if ($item["SpecialGroup"] -eq "Yes") {
    try {
        Set-SPOUser -Site $targeturl -LoginName $SCA03 -IsSiteCollectionAdmin $true -ErrorAction Stop
        Write-Host "Successfully added SpecialGroup ITS to OneDrive Site Collection Admin" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to add SpecialGroup ITS to Site Collection Admin: $($_.Exception.Message)" -ForegroundColor Red
        Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "SITE ADMIN" -ErrorMessage "Failed to add SpecialGroup ITS: $($_.Exception.Message)"
    }
}

if (-not $oneDriveProvisioned) {
               Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error: OneDrive provisioning failed for $userPrincipalName after $maxProvisionRetries attempts. Marking as Unlicensed." -ForegroundColor Red
               
               # Update ScriptError field with provisioning error
               Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "ONEDRIVE PROVISIONING" -ErrorMessage "OneDrive provisioning failed after $maxProvisionRetries attempts - likely unlicensed" -Append $false
               
               # Update status fields with throttling awareness
               $statusUpdated = $false
               $retryCount = 0
               
               while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
                   try {
                       Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                           "Migrate" = "Unlicensed"
                           "Processing" = ""
                           "LOG" = "OneDrive provisioning failed after multiple attempts"
                       }
                       $statusUpdated = $true
                   }
                   catch {
                       if ($_.Exception.Message -like "*throttled*" -or 
                           $_.Exception.Message -like "*429*" -or
                           $_.Exception.Message -like "*503*") {
                           
                           $retryCount++
                           $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                           
                           if (-not $shouldRetry) {
                               Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                               break
                           }
                       }
                       else {
                           Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                           break
                       }
                   }
               }
               
               return $false
           }
       } else {
           Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error: UPN is empty for $username. Cannot provision OneDrive." -ForegroundColor Red
           
           # Update ScriptError field with UPN error
           Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "UPN" -ErrorMessage "UPN is empty or invalid. Cannot provision OneDrive without a valid UPN." -Append $false
           
           # Update status fields with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "Invalid UPN"
                       "Processing" = ""
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }
           
           return $false
       }
   }
   
   # Execute SharePoint Migration
   Write-Host "Registering SPMT Migration..." -ForegroundColor Cyan
   Register-SPMTMigration -SPOCredential $SPOCredential -SkipFilesWithExtension $BlockedExtensions -WorkingFolder $LoggingSharePointMigration -MigrateWithoutRootFolder -ReplacementOfInvalidChar "_"

   Write-Host "Adding migration task..." -ForegroundColor Cyan
   Add-SPMTTask -FileShareSource $site -TargetSiteUrl $targeturl -TargetList $targetdocumentlibrary
   
   Write-Host "Starting migration..." -ForegroundColor Cyan
   Start-SPMTMigration

   $migrationStatus = Get-SPMTMigration
   Write-Host "Migration Report Path: $($migrationStatus.ReportFolderPath)" -ForegroundColor Cyan
   Write-Host "ItemReport Location(s):" -ForegroundColor Cyan
   Get-ChildItem -Path $migrationStatus.ReportFolderPath -Recurse -Filter "ItemReport_R1*.csv" | ForEach-Object {
       Write-Host $_.FullName -ForegroundColor Yellow
   }

   # Add a delay to ensure reports are fully written
   Write-Host "Waiting for reports to be finalized..." -ForegroundColor Yellow
   Start-Sleep -Seconds 30

   $currentDate2 = (Get-Date).AddHours(0).ToString('MM/dd/yyyy HH:mm:ss')

   # Look for all TaskReport folders and process ItemReports
    Write-Host "Looking in path: $($migrationStatus.ReportFolderPath)" -ForegroundColor Green
    Push-Location $migrationStatus.ReportFolderPath
    $taskReportFolders = Get-ChildItem -Path . -Directory | Where-Object { $_.Name -like "TaskReport_*" }
    Write-Host "Found $($taskReportFolders.Count) TaskReport folders" -ForegroundColor Cyan
    $allErrors = @()
    $fatalErrorFound = $false
    $fatalErrorMessages = @()

    foreach ($taskFolder in $taskReportFolders) {
        Write-Host "Processing folder: $($taskFolder.FullName)" -ForegroundColor Green
    
        $itemReports = Get-ChildItem -Path "$($taskFolder.FullName)" -File -Filter "ItemReport_R1*.csv"
        Write-Host "ItemReport path being checked: $($taskFolder.FullName)" -ForegroundColor Green
    
        foreach ($report in $itemReports) {
            Write-Host "Processing report: $($report.FullName)" -ForegroundColor Cyan
            $content = Get-Content $report.FullName
        
            $errors = Import-Csv $report.FullName | 
                Where-Object { $_.status -eq "skipped" -or $_.status -eq "failed" } |
                ForEach-Object {
                    Write-Host "Found error/skip: Status=$($_.status), Item=$($_.'Item name')" -ForegroundColor Red
                    $_
                } |
                Select-Object Status, "Item name", Source, Message, "Result category"
            Write-Host "Found $(($errors | Measure-Object).Count) errors in this report" -ForegroundColor Red
            $allErrors += $errors
        }
    
        # NEW: Process FatalError files
        $fatalErrorReports = Get-ChildItem -Path "$($taskFolder.FullName)" -File -Filter "FatalError_*.csv"
    
        if ($fatalErrorReports.Count -gt 0) {
            $fatalErrorFound = $true
            Write-Host "Found $($fatalErrorReports.Count) FatalError report(s) in $($taskFolder.Name)" -ForegroundColor Red
        
            foreach ($fatalReport in $fatalErrorReports) {
                Write-Host "Processing fatal error report: $($fatalReport.FullName)" -ForegroundColor Red
            
                try {
                    $fatalErrors = Import-Csv $fatalReport.FullName
                
                    # Extract messages from the fatal error report - only from Message column
                    foreach ($fatalError in $fatalErrors) {
                        if (-not [string]::IsNullOrWhiteSpace($fatalError.Message)) {
                            $fatalErrorMessages += $fatalError.Message
                            Write-Host "Fatal Error Message: $($fatalError.Message)" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    Write-Host "Error reading fatal error report $($fatalReport.FullName): $($_.Exception.Message)" -ForegroundColor Red
                    $fatalErrorMessages += "Error reading fatal error report: $($_.Exception.Message)"
                }
            }
        }
    }

   $newReportPath = Join-Path -Path $migrationStatus.ReportFolderPath -ChildPath "FailureSummaryReport2.csv"
       # Update ScriptError field if fatal errors were found
    if ($fatalErrorFound) {
        Write-Host "Fatal errors detected during migration!" -ForegroundColor Red
    
        # Combine all fatal error messages
        $combinedFatalMessages = $fatalErrorMessages -join " | "
    
        # Update ScriptError field with fatal error information
        $fatalErrorText = "Fatal Error - $combinedFatalMessages"
        Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "FATAL ERROR" -ErrorMessage $fatalErrorText -Append $true
    
        Write-Host "Fatal error messages added to ScriptError field" -ForegroundColor Yellow
    }
   if ($allErrors.Count -gt 0) {
       Write-Host "Total errors found: $($allErrors.Count)" -ForegroundColor Red
       $allErrors | Export-Csv $newReportPath -NoTypeInformation
       Write-Host "Created combined report at: $newReportPath" -ForegroundColor Green

       # Remove previous FailureSummaryReport if exists and attach new report
       $attachmentHandled = Handle-MigrationReport -ListName $listName -ItemId $item.Id -ReportPath $newReportPath -LogPath $logFilePath -Username $username

       if (-not $attachmentHandled) {
           Write-Host "Attachment handling failed - setting status to ManualLog" -ForegroundColor Red
           
           # Update ScriptError field with attachment error
           Update-ScriptErrorField -ListName $listName -ItemId $item.Id -ErrorCategory "ATTACHMENT" -ErrorMessage "Attachment handling failed - manual review required"
           
           # For staged migrations, skip My Documents move
           if ($IsStaged) {
               # Update status fields with throttling awareness
               $statusUpdated = $false
               $retryCount = 0
               
               while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
                   try {
                       Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                           "Migrate" = "ManualLog"
                           "Processing" = ""
                           "CompletedDate" = $currentDate2
                           "LOG" = "Migration Log: $($migrationstatus.ReportFolderPath) ; Transcript: $logFilePath"
                       }
                       $statusUpdated = $true
                   }
                   catch {
                       if ($_.Exception.Message -like "*throttled*" -or 
                           $_.Exception.Message -like "*429*" -or
                           $_.Exception.Message -like "*503*") {
                           
                           $retryCount++
                           $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                           
                           if (-not $shouldRetry) {
                               Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                               break
                           }
                       }
                       else {
                           Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                           break
                       }
                   }
               }
               
               Write-Host "Item marked for manual log review. Continuing to next item." -ForegroundColor Yellow
               
               # Clean up SPMT session
               Start-Sleep -Seconds 30
               Stop-SPMTMigration
               Unregister-SPMTMigration
               return $false
           }

           # For full migrations, proceed with normal ManualLog handling with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "ManualLog"
                       "Processing" = ""
                       "CompletedDate" = $currentDate2
                       "LOG" = "Migration Log: $($migrationstatus.ReportFolderPath) ; Transcript: $logFilePath"
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }

           # Continue with My Documents move only for full migrations with throttling-aware function
           Move-MyDocumentsContent -targetUrl $targeturl -userPrincipalName $userPrincipalName -ItemId $item.Id
           
           Write-Host "Item marked for manual log review. Continuing to next item." -ForegroundColor Yellow
           
           # Clean up SPMT session
           Start-Sleep -Seconds 30
           Stop-SPMTMigration
           Unregister-SPMTMigration
           return $false
       }

       # If attachment was handled successfully, update appropriate status
       if ($IsStaged) {
           # Update status fields with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "StagedWithErrors"
                       "Processing" = ""
                       "CompletedDate" = $currentDate2
                       "LOG" = "Migration Log: $($migrationstatus.ReportFolderPath) ; Transcript: $logFilePath"
                       # Don't update ScriptError since migration errors are in the CSV attachment
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }
           
           Write-Host "*** Migration completed with errors in staging mode ***" -ForegroundColor Yellow
       } else {
           # Update status fields with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "ErrorLog"
                       "Processing" = ""
                       "CompletedDate" = $currentDate2
                       "LOG" = "Migration Log: $($migrationstatus.ReportFolderPath) ; Transcript: $logFilePath"
                       # Don't update ScriptError since migration errors are in the CSV attachment
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }

           if (-not $IsStaged) {
               Write-Host "Moving My Documents content after setting ErrorLog status..." -ForegroundColor Yellow
               Move-MyDocumentsContent -targetUrl $targeturl -userPrincipalName $userPrincipalName -ItemId $item.Id
           }
       }

       Write-Host "*** Migration errors reported, see Failure Summary Report for this user ***" -ForegroundColor Red

       Start-Sleep -Seconds 30
       Stop-SPMTMigration
       Unregister-SPMTMigration
       return $false
   } else {
       # No errors found - successful migration
       if ($IsStaged) {
           # Update status fields with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "Staged"
                       "Processing" = ""
                       "CompletedDate" = $currentDate2
                       "LOG" = "Migration Log: $($migrationstatus.ReportFolderPath) ; Transcript: $logFilePath"
                       "ScriptError" = ""  # Clear any existing errors
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }
       } else {
           # Update status fields with throttling awareness
           $statusUpdated = $false
           $retryCount = 0
           
           while (-not $statusUpdated -and $retryCount -lt $maxRetries) {
               try {
                   Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                       "Migrate" = "Migrated"
                       "Processing" = ""
                       "CompletedDate" = $currentDate2
                       "LOG" = "Migration Log: $($migrationstatus.ReportFolderPath) ; Transcript: $logFilePath"
                       "ScriptError" = ""  # Clear any existing errors
                   }
                   $statusUpdated = $true
               }
               catch {
                   if ($_.Exception.Message -like "*throttled*" -or 
                       $_.Exception.Message -like "*429*" -or
                       $_.Exception.Message -like "*503*") {
                       
                       $retryCount++
                       $shouldRetry = Handle-SPOThrottling -RetryCount $retryCount -MaxRetries $maxRetries
                       
                       if (-not $shouldRetry) {
                           Write-Host "Failed to update status field after throttling retries" -ForegroundColor Red
                           break
                       }
                   }
                   else {
                       Write-Host "Failed to update status field: $($_.Exception.Message)" -ForegroundColor Red
                       break
                   }
               }
           }

           # Only move My Documents content for full migrations, AFTER the status is updated
           Write-Host "Migration completed successfully. Now moving My Documents content..." -ForegroundColor Green
           Move-MyDocumentsContent -targetUrl $targeturl -userPrincipalName $userPrincipalName -ItemId $item.Id
       }
       
       Write-Host "*** NO migration errors ***" -ForegroundColor Green

       Start-Sleep -Seconds 30
       Stop-SPMTMigration
       Unregister-SPMTMigration
       return $true
   }
} # End of Invoke-SPMTMigration

# Get fresh list of items to process in its own scope
Write-Host "Refreshing SharePoint list items before processing queue..." -ForegroundColor Cyan

Ensure-PnPConnection

$listItems = Get-PnPListItem -List $listName -PageSize 2000

Write-Host "Processing $(($itemsToProcess | Measure-Object).Count) items with $(($listItems | Measure-Object).Count) list references..." -ForegroundColor Green

# Main migration loop
foreach ($itemInfo in $itemsToProcess) {
    $site = $itemInfo.SourcePath
    $username = $itemInfo.Username
    
    # More robust item lookup with error handling
    $item = $null
    foreach ($listItem in $listItems) {
        try {
            # Match on BOTH path AND username to avoid confusion
            if ($listItem.FieldValues.SourcePath -eq $site -and 
                $listItem.FieldValues.Title -eq $username) {
                
                # Final postpone check using centralized function
                if (Test-IsPostponed -ListItem $listItem) {
                    Write-Host "Skipping migration for $username - postponed" -ForegroundColor Yellow
                    Reset-PostponedUserStatus -ListItem $listItem -ListName $listName
                    continue 2  # Skip to next iteration of outer loop
                }
                
                $item = $listItem
                break
            }
        } catch {
            # Continue to next item if there's an issue accessing this one
            continue
        }
    }
    
    if ($null -eq $item) {
        Write-Host "Error: Could not find SharePoint list item with SourcePath: $site and Username: $username. Skipping this item." -ForegroundColor Red
        continue
    }
    
    # From here, the rest of your existing code remains the same
    $targeturl = $item.FieldValues.TargetURL
    if ([string]::IsNullOrWhiteSpace($targeturl)) {
        Write-Host "Error: TargetURL is empty for source path $site. Skipping this item." -ForegroundColor Red
        continue
    }

    # Check if source path exists
if (-not (Test-Path $site)) {
    Write-Host "Error: Source path $site does not exist for user $username. Skipping migration." -ForegroundColor Red
    
    # Update status
    Set-PnPListItem -List $listName -Identity $item.Id -Values @{
        "Migrate" = "Failed"
        "Processing" = ""
        "ScriptError" = "Source path not found: $site"
    }
    continue
}    
    $userPrincipalName = $item.FieldValues.UPN
    
    if ([string]::IsNullOrWhiteSpace($item.FieldValues.Title)) {
        Write-Host "Error: Username is null or empty for site $site. Skipping this item for migration." -ForegroundColor Red
        continue
    }
# Process according to migration type
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Processing $MigrationType migration for $($item.FieldValues["Title"])" -ForegroundColor Cyan

# Handle each migration type differently
if ($MigrationType -eq "Stage") {
    # For stage operations, the license check and OneDrive provisioning happen in the Invoke-SPMTMigration function
    $migrationResult = Invoke-SPMTMigration -item $item -site $site -targeturl $targeturl -listName $listName -IsStaged
    continue  # Skip the rest of the processing
}

# If we reach here, it's a Migrate operation - we need to provision OneDrive first (ADD THIS SECTION)
$userPrincipalName = $item.FieldValues.UPN

# Check if user is licensed for O365 (add this for Migrate operations)
Write-Host "Performing license check for migrate operation" -ForegroundColor Yellow
$isLicensed = $null
try {
    $isLicensed = Is-UserGroupMember -targetgroup2 $targetGroup2 -item $item
}
catch {
    Write-Host "Error checking group membership for $($item.FieldValues["Title"]): $_" -ForegroundColor Red
    $isLicensed = $null
}

if ($isLicensed -eq $false) {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - User $($item.FieldValues["Title"]) is NOT licensed for O365." -ForegroundColor Yellow
    
    # Get current ScriptError content
    $currentErrors = $item.FieldValues.ScriptError
    
    # New error message
    $newError = "User is not licensed for Office 365. Contact UCSU to have user email migrated prior to migrating OneDrive."
    
    # Append to existing errors, if any
    $updatedErrors = if ([string]::IsNullOrEmpty($currentErrors)) {
        $newError
    } else {
        "$currentErrors`n---LICENSE ERROR---`n$newError"
    }
    
    Set-PnPListItem -List $listName -Identity $item.Id -Values @{
        "Migrate" = "Unlicensed"
        "Processing" = ""
        "ScriptError" = $updatedErrors
    }
    continue
}

# If we get here, user is licensed for O365
Write-Host "User $($item.FieldValues["Title"]) is licensed for O365. Proceeding with OneDrive provisioning." -ForegroundColor Green

# Provision OneDrive during migration
if (![string]::IsNullOrWhiteSpace($userPrincipalName)) {
    $userEmails = @($userPrincipalName)
    
    # Provision OneDrive before migration
    Write-Host "Provisioning OneDrive for $userPrincipalName" -ForegroundColor Cyan
    Provision-OneDrive -userEmails $userEmails

    # Add a retry mechanism to check for OneDrive provisioning with delay
    $maxProvisionRetries = 3
    $retryCount = 0
    $oneDriveProvisioned = $false

    while (-not $oneDriveProvisioned -and $retryCount -lt $maxProvisionRetries) {
# Verify OneDrive provisioning was successful
$oneDriveSiteUrl = Get-OneDriveUrl -UserPrincipalName $userPrincipalName
try {
    $oneDriveSite = Get-SPOSite -Identity $oneDriveSiteUrl -ErrorAction SilentlyContinue
    
    if ($null -eq $oneDriveSite) {
        $retryCount++
        Write-Host "OneDrive not yet provisioned for $userPrincipalName. Retry attempt $retryCount of $maxProvisionRetries" -ForegroundColor Yellow
        
        if ($retryCount -lt $maxProvisionRetries) {
            # Wait longer between each retry (exponential backoff)
            $delaySeconds = 60 * $retryCount
            Write-Host "Waiting $delaySeconds seconds before checking again..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delaySeconds
            
            # Try to provision again
            Write-Host "Attempting to provision OneDrive again..." -ForegroundColor Yellow
            Provision-OneDrive -userEmails $userEmails
        }
    } else {
        $oneDriveProvisioned = $true
        Write-Host "OneDrive successfully provisioned for $userPrincipalName" -ForegroundColor Green
    }
} catch {
    # If an error occurs, it means the site doesn't exist
    $retryCount++
    Write-Host "OneDrive not yet provisioned for $userPrincipalName. Retry attempt $retryCount of $maxProvisionRetries" -ForegroundColor Yellow
    
    if ($retryCount -lt $maxProvisionRetries) {
        # Wait longer between each retry (exponential backoff)
        $delaySeconds = 60 * $retryCount
        Write-Host "Waiting $delaySeconds seconds before checking again..." -ForegroundColor Yellow
        Start-Sleep -Seconds $delaySeconds
        
        # Try to provision again
        Write-Host "Attempting to provision OneDrive again..." -ForegroundColor Yellow
        Provision-OneDrive -userEmails $userEmails
    }
}
    }

    if (-not $oneDriveProvisioned) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error: OneDrive provisioning failed for $userPrincipalName after $maxProvisionRetries attempts. Marking as Unlicensed." -ForegroundColor Red
        
        Set-PnPListItem -List $listName -Identity $item.Id -Values @{
            "Migrate" = "Unlicensed"
            "Processing" = ""
            "LOG" = "OneDrive provisioning failed after multiple attempts - likely unlicensed"
        }
        continue
    }
} else {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error: UPN is empty for $($item.FieldValues["Title"]). Cannot provision OneDrive." -ForegroundColor Red

# Get current ScriptError content
$currentErrors = $item.FieldValues.ScriptError

# New error message
$newError = "UPN is empty or invalid. Cannot provision OneDrive without a valid UPN."

# Append to existing errors, if any
$updatedErrors = if ([string]::IsNullOrEmpty($currentErrors)) {
    $newError
} else {
    "$currentErrors`n---UPN ERROR---`n$newError"
}

Set-PnPListItem -List $listName -Identity $item.Id -Values @{
    "Migrate" = "Invalid UPN"
    "Processing" = ""
    "ScriptError" = $updatedErrors
}
continue
}

# Now continue with the existing AD updates and ACL modifications
try {
    # Continue with AD changes first
    Write-Host "Starting AD updates for $($item.FieldValues["Title"])" -ForegroundColor Cyan           
       # Now that OneDrive is confirmed provisioned, start ACL modification
       $domain = $env:USERDOMAIN
       $username = "$domain\$($item.FieldValues["Title"])"

       Write-Host "Starting ACL modification for $($item.FieldValues["Title"]) in background" -ForegroundColor Cyan

# Create the ACL modification script
# Create the ACL modification script
$aclScriptTemplate = @"
param(
   [string]`$username,
   [string]`$site,
   [string]`$siteUrl = "$siteUrl",
   [string]`$listName = "$listName",
   [string]`$itemTitle
)

`$ErrorActionPreference = 'Stop'
Write-Host "Starting ACL modification for `$username on `$site" -ForegroundColor Cyan

# The issue is with variable handling - we need to properly handle the site path
if ([string]::IsNullOrEmpty(`$site)) {
   Write-Host "Error: Home directory path is null or empty." -ForegroundColor Red
   exit 1
}

if (-not (Test-Path `$site)) {
   Write-Host "Error: Home directory path does not exist: `$site" -ForegroundColor Red
   exit 1
}

function Update-ACL {
   param(
       [string]`$path,
       [System.Security.AccessControl.FileSystemSecurity]`$aclTemplate
   )
   
   try {
       Set-Acl -Path `$path -AclObject `$aclTemplate -ErrorAction Stop
       Write-Host "Successfully updated ACL for: `$path" -ForegroundColor Green
       return `$true
   } catch {
       Write-Host "Failed to update ACL for: `$path" -ForegroundColor Red
       Write-Host `$_.Exception.Message -ForegroundColor Red
       return `$false
   }
}

try {
   Write-Host "`nStep 1: Getting current ACL for `$site" -ForegroundColor Yellow
   `$acl = Get-Acl `$site
   
   Write-Host "`nStep 2: Removing existing permissions for `$username" -ForegroundColor Yellow
   `$removedEntries = `$acl.Access | Where-Object { `$_.IdentityReference.Value -eq `$username }
   foreach (`$entry in `$removedEntries) {
       `$acl.RemoveAccessRule(`$entry)
       Write-Host "Removed access rule for `$(`$entry.IdentityReference)" -ForegroundColor Green
   }

   Write-Host "`nStep 3: Adding new read-only permission for `$username" -ForegroundColor Yellow
   `$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
       `$username,
       "ReadAndExecute",
       "ContainerInherit,ObjectInherit",
       "None",
       "Allow"
   )
   `$acl.AddAccessRule(`$rule)
   Write-Host "Added new read-only access rule" -ForegroundColor Green

   Write-Host "`nStep 4: Applying new ACL to root directory" -ForegroundColor Yellow
   `$success = Update-ACL -path `$site -aclTemplate `$acl
   
   if (`$success) {
       Write-Host "`nStep 5: Applying ACL to all subdirectories and files" -ForegroundColor Yellow
       `$items = Get-ChildItem -Path `$site -Recurse
       `$totalItems = `$items.Count
       `$current = 0
       
       foreach (`$item in `$items) {
           `$current++
           Write-Progress -Activity "Updating ACLs" -Status "Processing `$(`$item.FullName)" -PercentComplete ((`$current / `$totalItems) * 100)
           Update-ACL -path `$item.FullName -aclTemplate `$acl
       }
       
       Write-Progress -Activity "Updating ACLs" -Completed
       
       Write-Host "`nStep 6: Verifying final permissions" -ForegroundColor Yellow
       `$finalAcl = Get-Acl `$site
       Write-Host "Final permissions for `$site" -ForegroundColor Green
       `$finalAcl.Access | Format-Table IdentityReference, FileSystemRights, AccessControlType -AutoSize
       
       Write-Host "`nACL modification completed successfully" -ForegroundColor Green
       return `$true
   } else {
       return `$false
   }
} catch {
   Write-Host "Error modifying ACL: `$(`$_.Exception.Message)" -ForegroundColor Red
   Write-Host "Stack Trace: `$(`$_.ScriptStackTrace)" -ForegroundColor Red
   return `$false
} finally {
   Write-Host "`n===============================================" -ForegroundColor Yellow
   Write-Host "ACL Script Execution Complete" -ForegroundColor Green
}
"@

# First, check if variables are properly defined
Write-Host "Using siteUrl: $siteUrl" -ForegroundColor Cyan
Write-Host "Using listName: $listName" -ForegroundColor Cyan

# Create the ACL modification script using string replacement instead of formatting
$aclScript = $aclScriptTemplate.Replace("{0}", $siteUrl).Replace("{1}", $listName)

# Create temporary script file in custom temp location
$tempScriptPath = Join-Path -Path $TempPath -ChildPath "ACLModification_$timestamp.ps1"
$aclScript | Out-File -FilePath $tempScriptPath -Encoding utf8         

# Launch ACL modification and log any issues
try {
    $shortUsername = $item.FieldValues["Title"]
    
    # Verify temp script exists
    if (-not (Test-Path $tempScriptPath)) {
        Write-Host "ERROR: ACL script file not found at $tempScriptPath" -ForegroundColor Red
    } else {
        Write-Host "ACL script exists at $tempScriptPath" -ForegroundColor Green
    }
    
    # Fix command line arguments with proper quoting
    $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$tempScriptPath`" -username `"$username`" -site `"$site`" -itemTitle `"$shortUsername`""
    
    Write-Host "Launching ACL script with arguments: $arguments" -ForegroundColor Yellow
    
# Create a batch file wrapper that closes automatically
$batchFile = Join-Path -Path $TempPath -ChildPath "RunACL_$timestamp.bat"
@"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "$tempScriptPath" -username "$username" -site "$site" -itemTitle "$shortUsername"
"@ | Out-File -FilePath $batchFile -Encoding ascii

# Launch the batch file
$process = Start-Process "cmd.exe" -ArgumentList "/c `"$batchFile`"" -WindowStyle Minimized -PassThru 
    if ($null -eq $process -or $null -eq $process.Id) {
        Write-Host "ERROR: Failed to start ACL modification process for $shortUsername." -ForegroundColor Red
    } else {
        Write-Host "Started ACL modification for $shortUsername (Process ID: $($process.Id))" -ForegroundColor Green
    }
}
catch {
    Write-Host "ERROR launching ACL modification: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
    
    
       # Update SharePoint list to indicate ACL modification started
       try {
           Set-PnPListItem -List $listName -Identity $item.Id -Values @{"HReadOnly" = "Updated"}
           Write-Host "Successfully updated SharePoint list HReadOnly column for $shortUsername" -ForegroundColor Green
       }
       catch {
           Write-Host "Failed to update SharePoint list: $($_.Exception.Message)" -ForegroundColor Red
       }

# Continue with AD changes immediately
Write-Host "Starting AD updates while ACL modification runs in background" -ForegroundColor Cyan
$adModificationSuccess = $true

# Initialize error tracking
$errorMessages = @()

# Add OneDriveAdminGroup to site collection admins
try {
    Set-SPOUser -Site $targeturl -LoginName $SCA02 -IsSiteCollectionAdmin $true -ErrorAction Stop
    Write-Host "Successfully added OneDriveAdminGroup to OneDrive Site Collection Admin" -ForegroundColor Green
} 
catch {
    $adModificationSuccess = $false
    $errorMessage = "Failed to add OneDriveAdminGroup to Site Collection Admin: $($_.Exception.Message)"
    $errorMessages += $errorMessage
    Write-Host $errorMessage -ForegroundColor Red
}

# Check if SpecialGroup is marked as Yes
if ($item["SpecialGroup"] -eq "Yes") {
    try {
        Set-SPOUser -Site $targeturl -LoginName $SCA03 -IsSiteCollectionAdmin $true -ErrorAction Stop
        Write-Host "Successfully added SpecialGroup ITS to OneDrive Site Collection Admin" -ForegroundColor Green
    }
    catch {
        $adModificationSuccess = $false
        $errorMessage = "Failed to add SpecialGroup ITS to Site Collection Admin: $($_.Exception.Message)"
        $errorMessages += $errorMessage
        Write-Host $errorMessage -ForegroundColor Red
    }
}

# Update user's wwwHomePage attribute
try {
    Write-Host "Setting $($item.FieldValues["Title"]) wwwHomePage to $targeturl" -ForegroundColor Yellow
    Set-ADUser $($item.FieldValues["Title"]) -Replace @{wwwHomePage=$targeturl} -ErrorAction Stop
    Write-Host "Successfully updated $($item.FieldValues["Title"]) AD wwwHomePage property to $targeturl" -ForegroundColor Green
}
catch {
    $adModificationSuccess = $false
    $errorMessage = "Failed to update wwwHomePage attribute: $($_.Exception.Message)"
    $errorMessages += $errorMessage
    Write-Host $errorMessage -ForegroundColor Red
}

# Run redirection groups removal using groups from the RedirectGP column in SharePoint list
Write-Host "Starting REDIRECTION Group removal for $($item.FieldValues["Title"])" -ForegroundColor Cyan
$username = $item.FieldValues["Title"]
$redirectionSuccess = $true

try {
    # Get redirection groups from the SharePoint list RedirectGP column
    $redirectionGroupsFromSPO = $item.FieldValues["RedirectGP"]
    
    # Check if RedirectGP column has values
    if (-not [string]::IsNullOrWhiteSpace($redirectionGroupsFromSPO)) {
        # First split by newlines
        $lineGroups = $redirectionGroupsFromSPO -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        
        # Initialize array for all group names
        $redirectionGroupNames = @()
        
        # Process each line to handle comma-separated values within lines
        foreach ($line in $lineGroups) {
            # Split each line by comma and add to the group names
            $commaGroups = $line -split "," | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $redirectionGroupNames += $commaGroups
        }
        
        Write-Host "Found $($redirectionGroupNames.Count) redirection groups in SharePoint list for user $username" -ForegroundColor Green
        foreach ($group in $redirectionGroupNames) {
            Write-Host "  - $group" -ForegroundColor Cyan
        }
    } else {
        # If RedirectGP is empty, just continue with the rest of the script
        Write-Host "No redirection groups specified in SharePoint list for $username - continuing" -ForegroundColor Yellow
    }

    # Process each redirection group
    $removedCount = 0
    $failedCount = 0
    
    if (-not [string]::IsNullOrWhiteSpace($redirectionGroupsFromSPO) -and $redirectionGroupNames.Count -gt 0) {
        # Process each redirection group
        foreach ($groupName in $redirectionGroupNames) {
            try {
                # Directly attempt to remove the user from each group specified in the SPO list
                Write-Host "Removing $username from $groupName..." -ForegroundColor Yellow
                Remove-ADGroupMember -Identity $groupName -Members $username -Confirm:$false -ErrorAction Stop
                $removedCount++
                Write-Host "Successfully removed $username from $groupName" -ForegroundColor Green
            } catch {
                # If the error is specifically that the user is not a member, don't count as failure
                if ($_.Exception.Message -like "*is not a member of the group*") {
                    Write-Host "User $username is not a member of $groupName - skipping" -ForegroundColor Yellow
                } else {
                    # Otherwise count as a failure
                    $redirectionSuccess = $false
                    $failedCount++
                    $errorMessage = $_.Exception.Message
                    Write-Host "Error removing $username from $groupName : $errorMessage" -ForegroundColor Red
                    $errorMessages += "Error removing from $groupName : $errorMessage"
                }
            }
        }
        
        # Update SharePoint list based on success/failure
        $removalSummary = "Groups processed: $($redirectionGroupNames.Count), Removed: $removedCount, Failed: $failedCount"
        Write-Host $removalSummary -ForegroundColor Cyan
        
        # Update the SharePoint list status based on success/failure
        if (-not $redirectionSuccess) {
            try {
                Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                    "Redirect" = "Failed"
                }
                Write-Host "Updated SharePoint list Redirect status to 'Failed'" -ForegroundColor Red
            } catch {
                Write-Host "Failed to update SharePoint list Redirect status: $($_.Exception.Message)" -ForegroundColor Red
            }
            $adModificationSuccess = $false
        } else {
            try {
                Set-PnPListItem -List $listName -Identity $item.Id -Values @{
                    "Redirect" = "Removed"
                }
                Write-Host "Updated SharePoint list Redirect status to 'Removed'" -ForegroundColor Green
            } catch {
                Write-Host "Failed to update SharePoint list Redirect status: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-Host "Error during redirection group removal: $errorMessage" -ForegroundColor Red
    $errorMessages += "Error during redirection group removal: $errorMessage"
    
    # Update SPO list with failure
    try {
        Set-PnPListItem -List $listName -Identity $item.Id -Values @{
            "Redirect" = "Failed"
        }
        Write-Host "Updated SharePoint list Redirect status to 'Failed'" -ForegroundColor Red
    } catch {
        Write-Host "Failed to update SharePoint list Redirect status: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $adModificationSuccess = $false
    $redirectionSuccess = $false
}

# Add to target group
try {
    Add-ADGroupMember -Identity $targetGroup -Members $($item.FieldValues["Title"]) -ErrorAction Stop
    Write-Host "Successfully added $($item.FieldValues["Title"]) to $targetGroup" -ForegroundColor Green
}
catch {
    $adModificationSuccess = $false
    $errorMessage = "Failed to add user to $targetGroup : $($_.Exception.Message)"
    $errorMessages += $errorMessage
    Write-Host $errorMessage -ForegroundColor Red
}

# Update unixHomeDirectory with Homedir
try {
    Set-ADUser -Identity $($item.FieldValues["Title"]) -Replace @{unixHomeDirectory = $site} -ErrorAction Stop
    Write-Host "HomeDirectory copied to unixHomeDirectory for $($item.FieldValues["Title"])" -ForegroundColor Green
}
catch {
    $adModificationSuccess = $false
    $errorMessage = "Failed to update unixHomeDirectory: $($_.Exception.Message)"
    $errorMessages += $errorMessage
    Write-Host $errorMessage -ForegroundColor Red
}
       
# Clear HomeDrive and HomeDirectory
try {
    Set-ADUser -Identity $($item.FieldValues["Title"]) -Clear HomeDrive, HomeDirectory -ErrorAction Stop
    Write-Host "Cleared HomeDrive and HomeDirectory for $($item.FieldValues["Title"])" -ForegroundColor Green
}
catch {
    $adModificationSuccess = $false
    $errorMessage = "Failed to clear HomeDrive and HomeDirectory: $($_.Exception.Message)"
    $errorMessages += $errorMessage
    Write-Host $errorMessage -ForegroundColor Red
}

# Update AD Properties status based on success/failure
try {
    if ($adModificationSuccess) {
        Set-PnPListItem -List $listName -Identity $item.Id -Values @{"AD_x002d_Properties" = "Updated"}
        Write-Host "Updated AD_Properties status to 'Updated' in SharePoint list" -ForegroundColor Green
    } else {
        # Get current ScriptError content
        $currentErrors = $item.FieldValues.ScriptError
        
        # Format error messages
        $errorText = $errorMessages -join "`n"
        
        # Append to existing errors, if any
        $updatedErrors = if ([string]::IsNullOrEmpty($currentErrors)) {
            "---AD ScriptError---`n$errorText"
        } else {
            "$currentErrors`n---AD ScriptError---`n$errorText"
        }
        
        Set-PnPListItem -List $listName -Identity $item.Id -Values @{
            "AD_x002d_Properties" = "Failed"
            "ScriptError" = $updatedErrors
        }
        Write-Host "Updated AD_Properties status to 'Failed' in SharePoint list" -ForegroundColor Red
    }
}
catch {
    Write-Host "Failed to update AD_Properties status in SharePoint list: $($_.Exception.Message)" -ForegroundColor Red
}
       # Cleanup temp script at the end
       Remove-Item -Path $tempScriptPath -Force

       # Now perform the migration
       $migrationResult = Invoke-SPMTMigration -item $item -site $site -targeturl $targeturl -listName $listName
   }
   catch [System.UnauthorizedAccessException] {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error: You do not have permission to update this user $($item.FieldValues["Title"]) in Active Directory" -ForegroundColor Red
    
    # Get current ScriptError content
    $currentErrors = $item.FieldValues.ScriptError
    
    # New error message
    $newError = "Permission error: You do not have permission to update this user in Active Directory"
    
    # Append to existing errors, if any
    $updatedErrors = if ([string]::IsNullOrEmpty($currentErrors)) {
        $newError
    } else {
        "$currentErrors`n---PERMISSION ERROR---`n$newError"
    }
    
    Set-PnPListItem -List $listName -Identity $item.Id -Values @{
        "Migrate" = "Failed"
        "Processing" = ""
        "AD_x002d_Properties" = "Failed"
        "ScriptError" = $updatedErrors
    }
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error: The specified user $($item.FieldValues["Title"]) could not be found" -ForegroundColor Red
    
    # Get current ScriptError content
    $currentErrors = $item.FieldValues.ScriptError
    
    # New error message
    $newError = "User not found: The specified user could not be found in Active Directory"
    
    # Append to existing errors, if any
    $updatedErrors = if ([string]::IsNullOrEmpty($currentErrors)) {
        $newError
    } else {
        "$currentErrors`n---USER NOT FOUND---`n$newError"
    }
    
    Set-PnPListItem -List $listName -Identity $item.Id -Values @{
        "Migrate" = "Failed"
        "Processing" = ""
        "AD_x002d_Properties" = "Failed"
        "ScriptError" = $updatedErrors
    }
}
catch {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') *** Error in processing: $_" -ForegroundColor Red
    
    # Get current ScriptError content
    $currentErrors = $item.FieldValues.ScriptError
    
    # New error message
    $newError = "General error during AD processing: $_"
    
    # Append to existing errors, if any
    $updatedErrors = if ([string]::IsNullOrEmpty($currentErrors)) {
        $newError
    } else {
        "$currentErrors`n---GENERAL ERROR---`n$newError"
    }
    
    Set-PnPListItem -List $listName -Identity $item.Id -Values @{
        "Migrate" = "Failed"
        "Processing" = ""
        "AD_x002d_Properties" = "Failed"
        "ScriptError" = $updatedErrors
    }
}
} 

Stop-Transcript
Exit