<# 4/29/a
.SYNOPSIS
    Creates the SIMPLIFIED Common Drive Migration User Manual page on SharePoint Online.

.DESCRIPTION
    Deploys a simpler, easier-to-read version of the user manual with:
    - Quick Start table at the top
    - Process Flow diagram
    - Step-by-step instructions with clear "what to do" focus
    - Migration scheduling documentation (timezone-based windows)
    - Storage capacity check documentation (auto-downgrade 7yr → 5yr → 3yr)
    - Troubleshooting moved to the end

.PARAMETER PageName
    Name of the page to create. Default: "CommonDriveITAdminQuickRefGuide"

.PARAMETER UploadImages
    When specified, uploads ProcessFlow.png to Site Assets.

.PARAMETER ImageSourcePath
    Path to folder containing ProcessFlow.png. Default: Script directory

.EXAMPLE
    .\New-MigrationUserManualPage-Simple.ps1 -UploadImages
    
.NOTES
    Version:     1.4.0
    Date:        2026-04-29
    Author:      Douglas Cox [Microsoft CSA]
#>

param(
    [string]$PageName = "CommonDriveITAdminQuickRefGuide",
    [switch]$UploadImages,
    [string]$ImageSourcePath = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$siteUrl  = "https://contoso.spo.microsoft.scloud/sites/000001"

# App-Only Authentication - UPDATE THESE VALUES
$UseAppAuth               = $true
$AppClientId              = "<your-app-client-id>"           # Azure Portal > App Registrations
$AppTenantId              = "<your-tenant-id>"               # Azure Portal > Overview
$AppCertificateThumbprint = "<your-cert-thumbprint>"         # Cert:\LocalMachine\My

# Colors
$colors = @{
    White      = "#ffffff"
    LightGray  = "#f8f9fa"
    Navy       = "#002868"
    Gold       = "#bf9b30"
    TextDark   = "#212529"
    Border     = "#dee2e6"
    ErrorRed   = "#dc3545"
    SuccessGreen = "#198754"
}

# ============================================================
# CONNECT TO SHAREPOINT
# ============================================================

Write-Host "`n>> Connecting to SharePoint" -ForegroundColor Cyan

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
    Write-Host "   [OK] Connected to $siteUrl" -ForegroundColor Green
}
catch {
    Write-Host "   [X] Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================
# UPLOAD IMAGES
# ============================================================

$imageBaseUrl = "$siteUrl/SiteAssets"

if ($UploadImages) {
    Write-Host "`n>> Uploading images to Site Assets" -ForegroundColor Cyan
    
    $localPath = Join-Path $ImageSourcePath "ProcessFlow.png"
    if (Test-Path $localPath) {
        try {
            Add-PnPFile -Path $localPath -Folder "SiteAssets" -ErrorAction Stop | Out-Null
            Write-Host "   [OK] Uploaded ProcessFlow.png" -ForegroundColor Green
        }
        catch {
            Write-Host "   [!] Failed to upload: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "   [SKIP] ProcessFlow.png not found at: $localPath" -ForegroundColor Gray
    }
}

# ============================================================
# STYLES
# ============================================================

$baseStyles = @"
font-family:'Segoe UI',-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;line-height:1.6;color:$($colors.TextDark);
"@

$sectionStyle = @"
$baseStyles padding:28px;background:$($colors.White);border-radius:4px;margin-top:20px;border:1px solid $($colors.Border);
"@

$headerStyle = @"
font-size:18px;font-weight:600;color:$($colors.Navy);margin:0 0 20px 0;padding-bottom:8px;border-bottom:2px solid $($colors.Gold);
"@

$subHeaderStyle = @"
font-size:15px;font-weight:600;color:$($colors.Navy);margin:24px 0 12px 0;
"@

$tableStyle = @"
width:100%;border-collapse:collapse;margin:16px 0;font-size:14px;
"@

$thStyle = @"
background:$($colors.Navy);color:$($colors.White);padding:10px 12px;text-align:left;border:1px solid $($colors.Navy);font-weight:600;
"@

$tdStyle = @"
padding:10px 12px;border:1px solid $($colors.Border);color:$($colors.TextDark);vertical-align:top;background:$($colors.White);
"@

$tdAltStyle = @"
padding:10px 12px;border:1px solid $($colors.Border);color:$($colors.TextDark);vertical-align:top;background:$($colors.LightGray);
"@

$noteStyle = @"
font-size:14px;color:$($colors.TextDark);background:$($colors.LightGray);padding:12px 16px;border-left:3px solid $($colors.Gold);border-radius:0 4px 4px 0;margin:16px 0;
"@

# ============================================================
# SECTION 1: HEADER
# ============================================================

$headerHtml = @"
<div style="$baseStyles padding:32px;background:$($colors.Navy);border-radius:6px;">
  <div style="text-align:center;">
    <h1 style="font-size:22px;font-weight:600;color:$($colors.White);margin:0 0 6px 0;">Common Drive Migration</h1>
    <p style="color:$($colors.Gold);margin:0;font-size:16px;">Admin IT Guide</p>
    <p style="color:rgba(255,255,255,0.6);margin:8px 0 0 0;">Last Updated: April 27, 2026</p>
  </div>
</div>
"@

# ============================================================
# SECTION 2: PROCESS FLOW IMAGE
# ============================================================

$processFlowHtml = @"
<div style="$sectionStyle text-align:center;">
  <h2 style="$headerStyle text-align:left;">Process Overview</h2>
  <img src="$imageBaseUrl/ProcessFlow.png" alt="Migration Process Flow" style="max-width:100%;height:auto;border:1px solid $($colors.Border);border-radius:4px;" />
</div>
"@

# ============================================================
# SECTION 3: QUICK START
# ============================================================

$quickStartHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Quick Start</h2>
  
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle;width:60px;">Step</th>
      <th style="$thStyle">You Do</th>
      <th style="$thStyle">System Does</th>
    </tr>
    <tr>
      <td style="$tdStyle;text-align:center;font-weight:bold;font-size:18px;">1</td>
      <td style="$tdStyle">Create item: <strong>TimeZone, Title, ITDistro, SourcePath, TeamName</strong></td>
      <td style="$tdStyle;color:#6c757d;">—</td>
    </tr>
    <tr>
      <td style="$tdAltStyle;text-align:center;font-weight:bold;font-size:18px;">2</td>
      <td style="$tdAltStyle">Wait</td>
      <td style="$tdAltStyle">Scans your folder, resolves Teams target</td>
    </tr>
    <tr>
      <td style="$tdStyle;text-align:center;font-weight:bold;font-size:18px;">3</td>
      <td style="$tdStyle">Check: <strong>Errors = 0?</strong> <strong>TargetURL green?</strong></td>
      <td style="$tdStyle;color:#6c757d;">—</td>
    </tr>
    <tr>
      <td style="$tdAltStyle;text-align:center;font-weight:bold;font-size:18px;">4</td>
      <td style="$tdAltStyle">Set <strong>Migrate = "Migrate"</strong></td>
      <td style="$tdAltStyle">Migrates files to Teams site</td>
    </tr>
    <tr>
      <td style="$tdStyle;text-align:center;font-weight:bold;font-size:18px;">5</td>
      <td style="$tdStyle">Check results</td>
      <td style="$tdStyle">Sets source read-only, deletes migrated files + empty folders</td>
    </tr>
  </table>
  
<p style="`$noteStyle"><strong>⏱️ Timing:</strong> Migrations run <strong>5 PM - 4 AM</strong> weekdays, <strong>all day</strong> weekends &amp; federal holidays. Set your <strong>TimeZone</strong> column for correct timing. Use <strong>ANYTIME</strong> for 24/7 processing.</p>
  
  <p style="margin:16px 0 0 0;"><strong>That's it!</strong> The rest of this manual covers what to do when something goes wrong.</p>
</div>
"@

# ============================================================
# SECTION 4: STEP 1 - CREATE ITEM
# ============================================================

$step1Html = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Step 1: Create Your Migration Item</h2>
  
  <p style="margin:0 0 16px 0;"><strong>Go to:</strong> <a href="https://contoso.spo.microsoft.scloud/sites/000001/SitePages/MigrationStatus.aspx" style="color:$($colors.Navy);">Migration Landing Page</a></p>
  
  <p style="margin:0 0 12px 0;"><strong>Fill in these 5 fields:</strong></p>
  
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Field</th>
      <th style="$thStyle">What to Enter</th>
      <th style="$thStyle">Example</th>
    </tr>
    <tr>
      <td style="$tdStyle;background:#cfe2ff;font-weight:bold;">TimeZone</td>
      <td style="$tdStyle">Your local timezone (or ANYTIME for 24/7)</td>
      <td style="$tdStyle">EST, CST, MST, PST, ANYTIME</td>
    </tr>
    <tr>
      <td style="$tdAltStyle;background:#cfe2ff;font-weight:bold;">Title</td>
      <td style="$tdAltStyle">Name for this migration</td>
      <td style="$tdAltStyle;font-family:monospace;">"Unit-13 Archive Data"</td>
    </tr>
    <tr>
      <td style="$tdStyle;background:#cfe2ff;font-weight:bold;">ITDistro</td>
      <td style="$tdStyle">Your IT group (dropdown)</td>
      <td style="$tdStyle">Select from list</td>
    </tr>
    <tr>
      <td style="$tdAltStyle;background:#cfe2ff;font-weight:bold;">SourcePath</td>
      <td style="$tdAltStyle">Full UNC path</td>
      <td style="$tdAltStyle;font-family:monospace;">\\CONTOSO-FS\Shares\Unit-13</td>
    </tr>
    <tr>
      <td style="$tdStyle;background:#cfe2ff;font-weight:bold;">TeamName</td>
      <td style="$tdStyle">Destination Team name</td>
      <td style="$tdStyle">"Unit-13 Team"</td>
    </tr>
  </table>
  
  <p style="$noteStyle">✅ <strong>Done!</strong> Wait for the system to scan your folder.</p>
</div>
"@

# ============================================================
# SECTION 5: STEP 2 - CHECK SCAN RESULTS
# ============================================================

$step2Html = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Step 2: Check Scan Results</h2>
  
  <p style="margin:0 0 16px 0;">After the system processes your item, check these two things:</p>
  
  <h3 style="$subHeaderStyle">Check 1: Errors Column</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">If...</th>
      <th style="$thStyle">Then...</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Errors = 0</strong></td>
      <td style="$tdStyle;color:$($colors.SuccessGreen);">✅ You're good! Go to Step 3</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Errors &gt; 0</strong> <span style="color:$($colors.ErrorRed);">(red)</span></td>
      <td style="$tdAltStyle;color:$($colors.ErrorRed);">⚠️ See <a href="#fixing-errors" style="color:$($colors.Navy);">Fixing Scan Errors</a> below</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Check 2: TargetURL Color</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">If...</th>
      <th style="$thStyle">Then...</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong style="color:$($colors.SuccessGreen);">Green</strong></td>
      <td style="$tdStyle;color:$($colors.SuccessGreen);">✅ Enough storage! Go to Step 3</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong style="color:$($colors.ErrorRed);">Red</strong></td>
      <td style="$tdAltStyle;color:$($colors.ErrorRed);">⚠️ Not enough storage. Request increase or split your data.</td>
    </tr>
  </table>
</div>
"@

# ============================================================
# SECTION 6: STEP 3 - START MIGRATION
# ============================================================

$step3Html = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Step 3: Start Migration</h2>
  
  <p style="margin:0 0 16px 0;">Once Errors = 0 and TargetURL is green:</p>
  
  <ol style="margin:0 0 16px 20px;padding:0;">
    <li style="margin-bottom:8px;">Find the <strong>Migrate</strong> column</li>
    <li style="margin-bottom:8px;">Set it to <strong>"Migrate"</strong></li>
    <li style="margin-bottom:8px;">Done! The system will process your item.</li>
  </ol>
  
  <p style="$noteStyle"><strong>💡 How long?</strong> Check the <strong>7yr</strong> column - that's how much data will migrate. Larger = longer.</p>
  <p style="$noteStyle"><strong>⏰ When?</strong> Migrations run <strong>5 PM - 4 AM</strong> weekdays, <strong>all day</strong> weekends &amp; federal holidays. Set your <strong>TimeZone</strong> column for correct timing. Use <strong>ANYTIME</strong> for 24/7 processing.</p>
</div>
"@

# ============================================================
# SECTION 7: STEP 4 - CHECK RESULTS
# ============================================================

$step4Html = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Step 4: Check Results</h2>
  
  <p style="margin:0 0 16px 0;">After migration completes, the <strong>Migrate</strong> column shows the result:</p>
  
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Result</th>
      <th style="$thStyle">Meaning</th>
      <th style="$thStyle">What to Do</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong style="color:$($colors.SuccessGreen);">Migrated</strong></td>
      <td style="$tdStyle">✅ Complete success</td>
      <td style="$tdStyle">Nothing - you're done!</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong style="color:$($colors.SuccessGreen);">MigratedWithErrors</strong></td>
      <td style="$tdAltStyle">✅ Partial success - most files migrated</td>
      <td style="$tdAltStyle">Check <strong>FailureSummaryReport2.csv</strong> in Attachments, fix issues, set Migrate = "Migrate" again</td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong style="color:$($colors.ErrorRed);">Failed</strong></td>
      <td style="$tdStyle">❌ Did not complete</td>
      <td style="$tdStyle">Check ScriptError column, contact IT if unclear</td>
    </tr>
  </table>
</div>
"@

# ============================================================
# SECTION 8: FIXING SCAN ERRORS
# ============================================================

$errorsHtml = @"
<div id="fixing-errors" style="$sectionStyle">
  <h2 style="$headerStyle">Fixing Scan Errors</h2>
  
  <p style="margin:0 0 16px 0;">If the <strong>Errors</strong> column is red:</p>
  
  <ol style="margin:0 0 16px 20px;padding:0;">
    <li style="margin-bottom:8px;">Click <strong>Attachments</strong> column</li>
    <li style="margin-bottom:8px;">Download the file named <code style="background:#e9ecef;padding:2px 6px;border-radius:3px;">UNCscanErrors*.csv</code></li>
    <li style="margin-bottom:8px;">Open in Excel to see what's wrong</li>
    <li style="margin-bottom:8px;">Fix the issues in your source folder</li>
    <li style="margin-bottom:8px;">Clear the <strong>Date</strong> column to trigger a re-scan</li>
    <li style="margin-bottom:8px;">Wait for next scheduled task run and check again</li>
  </ol>
  
  <h3 style="$subHeaderStyle">Common Error Fixes</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Error</th>
      <th style="$thStyle">How to Fix</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Path Too Long</strong></td>
      <td style="$tdStyle">Shorten folder names or move files up</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Invalid Characters</strong></td>
      <td style="$tdAltStyle">Rename files - remove <code style="background:#e9ecef;padding:2px 6px;border-radius:3px;">" * : &lt; &gt; ? / \ | #</code></td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Access Denied</strong></td>
      <td style="$tdStyle">Contact IT to grant migration service access</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>File In Use</strong></td>
      <td style="$tdAltStyle">Close the application using that file</td>
    </tr>
  </table>
</div>
"@

# ============================================================
# SECTION 9: RE-SCAN / RE-CHECK
# ============================================================

$rescanHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Need to Re-scan or Re-check?</h2>
  
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">To...</th>
      <th style="$thStyle">Clear this column</th>
    </tr>
    <tr>
      <td style="$tdStyle">Re-scan source folder</td>
      <td style="$tdStyle"><strong>Date</strong></td>
    </tr>
    <tr>
      <td style="$tdAltStyle">Re-check Teams/storage</td>
      <td style="$tdAltStyle"><strong>LastChecked</strong></td>
    </tr>
  </table>
  
  <p style="$noteStyle">The system will re-process on the next scheduled task run.</p>
</div>
"@

# ============================================================
# SECTION 9b: MIGRATION SCHEDULING
# ============================================================

$schedulingHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Migration Scheduling</h2>
  
  <p style="margin:0 0 16px 0;">Migrations run <strong>outside business hours</strong> to avoid impacting users. Set your <strong>TimeZone</strong> so migrations start at the right time for your location.</p>
  
  <h3 style="$subHeaderStyle">Migration Window</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Day</th>
      <th style="$thStyle">Migration Runs</th>
    </tr>
    <tr>
      <td style="$tdStyle">Monday - Thursday</td>
      <td style="$tdStyle"><strong>5:00 PM - 4:00 AM</strong> (your local time)</td>
    </tr>
    <tr>
      <td style="$tdAltStyle">Friday 5 PM - Monday 4 AM</td>
      <td style="$tdAltStyle"><strong>All weekend</strong> (continuous)</td>
    </tr>
    <tr>
      <td style="$tdStyle">Federal Holidays</td>
      <td style="$tdStyle"><strong>All day</strong> (until 4 AM next day)</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Timezone Options</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Value</th>
      <th style="$thStyle">Description</th>
    </tr>
    <tr><td style="$tdStyle"><strong>EST</strong></td><td style="$tdStyle">Eastern Time</td></tr>
    <tr><td style="$tdAltStyle"><strong>CST</strong></td><td style="$tdAltStyle">Central Time</td></tr>
    <tr><td style="$tdStyle"><strong>MST</strong></td><td style="$tdStyle">Mountain Time</td></tr>
    <tr><td style="$tdAltStyle"><strong>PST</strong></td><td style="$tdAltStyle">Pacific Time</td></tr>
    <tr><td style="$tdStyle"><strong>AKST</strong></td><td style="$tdStyle">Alaska Time</td></tr>
    <tr><td style="$tdAltStyle"><strong>HST</strong></td><td style="$tdAltStyle">Hawaii Time</td></tr>
    <tr><td style="$tdStyle"><strong>ANYTIME</strong></td><td style="$tdStyle">No restrictions - run 24/7</td></tr>
  </table>
  
  <p style="$noteStyle"><strong>📋 Queue Order:</strong> Items are processed in the order they were queued (first in, first out).</p>
</div>
"@

# ============================================================
# SECTION 10: COLUMN QUICK REFERENCE
# ============================================================

$columnsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">What the Columns Mean</h2>
  
  <h3 style="$subHeaderStyle">You Fill In (Blue columns)</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Column</th>
      <th style="$thStyle">Purpose</th>
    </tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>DIV</strong></td><td style="$tdStyle">Your division</td></tr>
    <tr><td style="$tdAltStyle;background:#cfe2ff;"><strong>Title</strong></td><td style="$tdAltStyle">Name for this migration</td></tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>ITDistro</strong></td><td style="$tdStyle">Your IT group</td></tr>
    <tr><td style="$tdAltStyle;background:#cfe2ff;"><strong>SourcePath</strong></td><td style="$tdAltStyle">Where data is now (UNC path)</td></tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>TeamName</strong></td><td style="$tdStyle">Where data is going (Teams name)</td></tr>
    <tr><td style="$tdAltStyle;background:#cfe2ff;"><strong>TimeZone</strong></td><td style="$tdAltStyle">Your timezone (EST, CST, MST, PST, ANYTIME)</td></tr>
  </table>
  
  <h3 style="$subHeaderStyle">System Fills In - Key Columns to Watch</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Column</th>
      <th style="$thStyle">What it Shows</th>
    </tr>
    <tr><td style="$tdStyle"><strong>7yr / 5yr / 3yr</strong></td><td style="$tdStyle">Data size by age ← <em>System auto-selects based on available storage</em></td></tr>
    <tr><td style="$tdAltStyle"><strong>YearUsed</strong></td><td style="$tdAltStyle">Which year cutoff was used (7, 5, or 3) ← <em>Set during migration</em></td></tr>
    <tr><td style="$tdStyle"><strong>Errors</strong></td><td style="$tdStyle">Scan problems (red = issues to fix)</td></tr>
    <tr><td style="$tdAltStyle"><strong>TargetURL</strong></td><td style="$tdAltStyle">SharePoint site (green = enough storage, red = insufficient)</td></tr>
    <tr><td style="$tdStyle"><strong>Migrate</strong></td><td style="$tdStyle">Status: empty → set to \"Migrate\" → shows result</td></tr>
    <tr><td style="$tdAltStyle"><strong>ScriptError</strong></td><td style="$tdAltStyle">Migration problems or storage downgrade info</td></tr>
    <tr><td style="$tdStyle"><strong>Attachments</strong></td><td style="$tdStyle">Error reports and logs</td></tr>
  </table>
  
  <p style="$noteStyle"><strong>💡 Storage Check:</strong> The system compares 7yr/5yr/3yr data sizes against available storage. If 7yr doesn't fit, it automatically tries 5yr, then 3yr. The <strong>YearUsed</strong> column shows which was used. If none fit, migration fails with a storage error.</p>
</div>
"@

# ============================================================
# SECTION 10b: ALL COLUMNS REFERENCE
# ============================================================

$allColumnsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">All Columns Reference</h2>
  
  <h3 style="$subHeaderStyle">Group 1: Source &amp; Scan Data</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Column</th>
      <th style="$thStyle">Type</th>
      <th style="$thStyle">Description</th>
    </tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>DIV</strong></td><td style="$tdStyle">User</td><td style="$tdStyle">Division/department code</td></tr>
    <tr><td style="$tdAltStyle;background:#cfe2ff;"><strong>Title</strong></td><td style="$tdAltStyle">User</td><td style="$tdAltStyle">Migration item name</td></tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>ITDistro</strong></td><td style="$tdStyle">User</td><td style="$tdStyle">IT distribution group (dropdown)</td></tr>
    <tr><td style="$tdAltStyle;background:#cfe2ff;"><strong>SourcePath</strong></td><td style="$tdAltStyle">User</td><td style="$tdAltStyle">Full UNC path to source folder</td></tr>
    <tr><td style="$tdStyle"><strong>ClaimedAt</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">When item was claimed for scan</td></tr>
    <tr><td style="$tdAltStyle"><strong>ClaimedBy</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Server that processed the scan</td></tr>
    <tr><td style="$tdStyle"><strong>3yr</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Files modified in last 3 years (fallback if 7yr/5yr too large)</td></tr>
    <tr><td style="$tdAltStyle"><strong>5yr</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Files modified in last 5 years (fallback if 7yr too large)</td></tr>
    <tr><td style="$tdStyle"><strong>7yr</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Files modified in last 7 years (preferred migration size)</td></tr>
    <tr><td style="$tdAltStyle"><strong>TotalSize</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Total size of source folder</td></tr>
    <tr><td style="$tdStyle"><strong>FileCount</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Number of files in source</td></tr>
    <tr><td style="$tdAltStyle"><strong>DirCount</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Number of subdirectories</td></tr>
    <tr><td style="$tdStyle"><strong>Errors</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Count of scan errors (red if &gt; 0)</td></tr>
    <tr><td style="$tdAltStyle"><strong>Date</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Date of last scan - <em>clear to re-scan</em></td></tr>
    <tr><td style="$tdStyle"><strong>ScanDuration</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">How long the scan took</td></tr>
  </table>
  
  <h3 style="$subHeaderStyle">Group 2: Teams/SPO Target</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Column</th>
      <th style="$thStyle">Type</th>
      <th style="$thStyle">Description</th>
    </tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>TeamName</strong></td><td style="$tdStyle">User</td><td style="$tdStyle">Destination Microsoft Team name</td></tr>
    <tr><td style="$tdAltStyle"><strong>TeamChannel0</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Channel (defaults to General)</td></tr>
    <tr><td style="$tdStyle"><strong>TeamChannelError</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Error if Team/channel not found</td></tr>
    <tr><td style="$tdAltStyle"><strong>TargetURL</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">SharePoint site URL (green/red)</td></tr>
    <tr><td style="$tdStyle"><strong>TargetRelativePath</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Folder path in document library</td></tr>
    <tr><td style="$tdAltStyle"><strong>StorageQuota</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Site storage quota (MB)</td></tr>
    <tr><td style="$tdStyle"><strong>StorageUsed</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Current storage used (MB)</td></tr>
    <tr><td style="$tdAltStyle"><strong>StorageAvailable</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Remaining storage available</td></tr>
    <tr><td style="$tdStyle"><strong>LastChecked</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">When target was verified - <em>clear to re-check</em></td></tr>
  </table>
  
  <h3 style="$subHeaderStyle">Group 3: Migration Status</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Column</th>
      <th style="$thStyle">Type</th>
      <th style="$thStyle">Description</th>
    </tr>
    <tr><td style="$tdStyle"><strong>Processing</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Current processing state</td></tr>
    <tr><td style="$tdAltStyle"><strong>Migrate</strong></td><td style="$tdAltStyle">User</td><td style="$tdAltStyle">Set to \"Migrate\" to queue; shows result after</td></tr>
    <tr><td style="$tdStyle;background:#cfe2ff;"><strong>TimeZone</strong></td><td style="$tdStyle">User</td><td style="$tdStyle">Your timezone - migrations run 5 PM - 4 AM local</td></tr>
    <tr><td style="$tdAltStyle"><strong>QueuedAt</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">When item was added to queue (FIFO order)</td></tr>
    <tr><td style="$tdStyle"><strong>Server</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Migration server handling this item</td></tr>
    <tr><td style="$tdAltStyle"><strong>StartDate</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">When migration started</td></tr>
    <tr><td style="$tdStyle"><strong>CompletedDate</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">When migration completed</td></tr>
    <tr><td style="$tdAltStyle"><strong>EstDuration</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Estimated or actual duration</td></tr>
    <tr><td style="$tdStyle"><strong>LOG</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Links to migration logs</td></tr>
    <tr><td style="$tdAltStyle"><strong>YearUsed</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Year cutoff used: 7, 5, or 3 (based on storage check)</td></tr>
    <tr><td style="$tdStyle"><strong>DeleteSource</strong></td><td style="$tdStyle">Auto</td><td style="$tdStyle">Count of files + folders deleted from source</td></tr>
    <tr><td style="$tdAltStyle"><strong>ScriptError</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Errors or storage downgrade info</td></tr>
    <tr><td style="$tdAltStyle"><strong>Attachments</strong></td><td style="$tdAltStyle">Auto</td><td style="$tdAltStyle">Error CSVs and reports</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 11: STILL STUCK
# ============================================================

$helpHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Still Stuck?</h2>
  
  <ol style="margin:0 0 16px 20px;padding:0;">
    <li style="margin-bottom:8px;"><strong>Check Attachments</strong> for these reports:
      <ul style="margin:8px 0 0 20px;">
        <li><code style="background:#e9ecef;padding:2px 6px;border-radius:3px;">UNCscanErrors*.csv</code> - Scan errors (path issues, access denied)</li>
        <li><code style="background:#e9ecef;padding:2px 6px;border-radius:3px;">FailureSummaryReport2.csv</code> - Migration errors (files that failed to migrate)</li>
        <li><code style="background:#e9ecef;padding:2px 6px;border-radius:3px;">DeletionReport_*.csv</code> - Files + empty folders deleted from source after migration</li>
      </ul>
    </li>
    <li style="margin-bottom:8px;"><strong>Check ScriptError column</strong> - Summarizes what went wrong</li>
    <li style="margin-bottom:8px;"><strong>Contact IT</strong> - Provide your item Title and error message</li>
  </ol>
</div>
"@

# ============================================================
# SECTION 12: SHAREPOINT LIMITS (Appendix)
# ============================================================

$limitsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Appendix: SharePoint Limits</h2>
  
  <p style="margin:0 0 16px 0;">These limits can cause migration failures even if scan passes:</p>
  
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Limit</th>
      <th style="$thStyle">Value</th>
    </tr>
    <tr>
      <td style="$tdStyle">Full URL path (site + folders + filename)</td>
      <td style="$tdStyle"><strong>400 characters</strong> max</td>
    </tr>
  </table>
  
  <p style="$noteStyle"><strong>💡 Tip:</strong> Keep folder structures shallow. Deep nesting + long names = problems.</p>
  
  <p style="margin:16px 0 0 0;"><strong>Characters not allowed:</strong> <code style="background:#e9ecef;padding:2px 6px;border-radius:3px;">" * : &lt; &gt; ? / \ | # %</code></p>
</div>
"@

# ============================================================
# CREATE OR UPDATE PAGE
# ============================================================

Write-Host "`n>> Creating/updating page: $PageName" -ForegroundColor Cyan

# Check if page exists
$existingPage = Get-PnPPage -Identity $PageName -ErrorAction SilentlyContinue

if ($existingPage) {
    Write-Host "   [!] Page exists - will delete and recreate" -ForegroundColor Yellow
    Remove-PnPPage -Identity $PageName -Force
    Start-Sleep -Seconds 2
}

# Create new page
$page = Add-PnPPage -Name $PageName -LayoutType Article -ErrorAction Stop
Write-Host "   [OK] Page created" -ForegroundColor Green

# Remove default header image
Set-PnPPage -Identity $PageName -HeaderLayoutType NoImage -Title "IT Quick Ref Admin Guide"

# Add sections
Write-Host "   Adding content sections..." -ForegroundColor Gray

Add-PnPPageTextPart -Page $PageName -Text $headerHtml -Order 1
Add-PnPPageTextPart -Page $PageName -Text $processFlowHtml -Order 2
Add-PnPPageTextPart -Page $PageName -Text $quickStartHtml -Order 3
Add-PnPPageTextPart -Page $PageName -Text $step1Html -Order 4
Add-PnPPageTextPart -Page $PageName -Text $step2Html -Order 5
Add-PnPPageTextPart -Page $PageName -Text $step3Html -Order 6
Add-PnPPageTextPart -Page $PageName -Text $step4Html -Order 7
Add-PnPPageTextPart -Page $PageName -Text $errorsHtml -Order 8
Add-PnPPageTextPart -Page $PageName -Text $rescanHtml -Order 9
Add-PnPPageTextPart -Page $PageName -Text $schedulingHtml -Order 10
Add-PnPPageTextPart -Page $PageName -Text $columnsHtml -Order 11
Add-PnPPageTextPart -Page $PageName -Text $allColumnsHtml -Order 12
Add-PnPPageTextPart -Page $PageName -Text $helpHtml -Order 13
Add-PnPPageTextPart -Page $PageName -Text $limitsHtml -Order 14

# Publish
Set-PnPPage -Identity $PageName -Publish
Write-Host "   [OK] Page published" -ForegroundColor Green

# ============================================================
# DONE
# ============================================================

$pageUrl = "$siteUrl/SitePages/$PageName.aspx"
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUCCESS! Quick IT AMDIN Guide deployed" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "URL: $pageUrl" -ForegroundColor Yellow
Write-Host "`nNote: Make sure ProcessFlow.png is uploaded to Site Assets" -ForegroundColor Gray
Write-Host "      Run with -UploadImages to upload automatically" -ForegroundColor Gray
