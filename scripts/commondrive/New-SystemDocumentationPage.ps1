<#
.SYNOPSIS
    Creates the comprehensive System Documentation page on SharePoint Online.

.DESCRIPTION
    Deploys complete migration system documentation including:
    - System architecture and process flow
    - Key features and scheduling logic
    - Azure app registrations (36 total)
    - Power Automate notifications
    - Server setup and prerequisites
    - Scheduled tasks with command lines
    - Configuration reference
    - Troubleshooting guide
    - Security considerations

.PARAMETER PageName
    Name of the page to create. Default: SystemDocumentation

.EXAMPLE
    .\New-SystemDocumentationPage.ps1
    
.NOTES
    Version:     1.0.0
    Date:        2026-04-27
    Author:      Douglas Cox [Microsoft CSA]
    
    This script combines the previous Architecture and Admin Setup Guide pages
    into a single comprehensive reference document.
#>

param(
    [string]$PageName = "SystemDocumentation"
)

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$siteUrl  = "https://contoso.spo.microsoft.scloud/sites/000001"

# App-Only Authentication
$UseAppAuth               = $true
$AppClientId              = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
$AppTenantId              = "dddddddd-dddd-dddd-dddd-dddddddddddd"
$AppCertificateThumbprint = "1111111111111111111111111111111111111111"

# Colors
$colors = @{
    White      = "#ffffff"
    LightGray  = "#f8f9fa"
    Navy       = "#002868"
    Gold       = "#bf9b30"
    TextDark   = "#212529"
    Border     = "#dee2e6"
    InfoBg     = "#e7f3ff"
    InfoBorder = "#0078d4"
    WarnBg     = "#fff8e6"
    WarnBorder = "#fd7e14"
    DangerBg   = "#f8d7da"
    DangerBorder = "#dc3545"
    Purple     = "#6f42c1"
    Green      = "#198754"
    Red        = "#dc3545"
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
# STYLES
# ============================================================

$baseStyles = @"
font-family:'Segoe UI',-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;line-height:1.6;color:$($colors.TextDark);
"@

$sectionStyle = @"
$baseStyles padding:24px 28px;background:$($colors.White);border-radius:4px;margin-top:20px;border:1px solid $($colors.Border);
"@

$headerStyle = @"
font-size:18px;font-weight:600;color:$($colors.Navy);margin:0 0 16px 0;padding-bottom:8px;border-bottom:2px solid $($colors.Gold);
"@

$subHeaderStyle = @"
font-size:15px;font-weight:600;color:$($colors.Navy);margin:20px 0 12px 0;
"@

$tableStyle = @"
width:100%;border-collapse:collapse;margin:16px 0;font-size:13px;
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

$noteInfoStyle = @"
font-size:14px;color:$($colors.TextDark);background:$($colors.InfoBg);padding:12px 16px;border-left:3px solid $($colors.InfoBorder);border-radius:0 4px 4px 0;margin:16px 0;
"@

$noteWarnStyle = @"
font-size:14px;color:$($colors.TextDark);background:$($colors.WarnBg);padding:12px 16px;border-left:3px solid $($colors.WarnBorder);border-radius:0 4px 4px 0;margin:16px 0;
"@

$noteDangerStyle = @"
font-size:14px;color:$($colors.TextDark);background:$($colors.DangerBg);padding:12px 16px;border-left:3px solid $($colors.DangerBorder);border-radius:0 4px 4px 0;margin:16px 0;
"@

$preStyle = @"
background:#1e1e1e;color:#d4d4d4;padding:14px;border-radius:4px;overflow-x:auto;font-family:'Consolas','Courier New',monospace;font-size:12px;line-height:1.5;margin:12px 0;white-space:pre-wrap;
"@

$codeStyle = @"
background:#e9ecef;padding:2px 6px;border-radius:3px;font-family:'Consolas','Courier New',monospace;font-size:12px;
"@

$badgeStyle = @"
display:inline-block;background:$($colors.Navy);color:white;padding:2px 8px;border-radius:12px;font-size:11px;font-weight:600;margin-left:8px;
"@

# ============================================================
# SECTION 1: HEADER
# ============================================================

$headerHtml = @"
<div style="$baseStyles padding:32px;background:linear-gradient(135deg,$($colors.Navy) 0%,#001845 100%);border-radius:6px;text-align:center;">
  <h1 style="font-size:22px;font-weight:600;color:$($colors.White);margin:0 0 6px 0;">Common Drive Migration</h1>
  <p style="color:$($colors.Gold);margin:0;font-size:16px;">System Documentation</p>
  <p style="color:rgba(255,255,255,0.6);margin:8px 0 0 0;font-size:13px;">Architecture • Setup • Operations | Version 2.7 | April 2026</p>
</div>
"@

# ============================================================
# SECTION 2: 6-SERVER WARNING
# ============================================================

$warningHtml = @"
<div style="$noteWarnStyle margin:20px 0;">
  <strong>⚠️ IMPORTANT:</strong> Any changes to scripts must be deployed to <strong>all 6 migration servers</strong>. Update one server, test, then deploy to remaining servers.
</div>
"@

# ============================================================
# SECTION 3: EXECUTIVE SUMMARY
# ============================================================

$summaryHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Executive Summary</h2>
  
  <p style="margin:0 0 16px 0;">Automated file share migration system that migrates on-premises Common Drive data to Microsoft Teams/SharePoint Online. The system uses distributed processing across <strong>6 servers (18 parallel instances)</strong> with app-only authentication for fully unattended operation.</p>
  
  <table style="$tableStyle">
    <tr><th style="$thStyle">Category</th><th style="$thStyle">Capabilities</th></tr>
    <tr>
      <td style="$tdStyle"><strong>Scheduling</strong></td>
      <td style="$tdStyle">Timezone-aware windows (EST, CST, MST, PST, AKST, HST) — migrations run <strong>5 PM - 4 AM</strong> weekdays, <strong>all day</strong> weekends &amp; federal holidays. ANYTIME option for 24/7 processing.</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Queue Processing</strong></td>
      <td style="$tdAltStyle">FIFO (first in, first out) based on QueuedAt timestamp</td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Data Management</strong></td>
      <td style="$tdStyle">3/5/7 year data retention analysis • Automatic storage quota validation • Post-migration source cleanup (read-only + file deletion + empty folder cleanup)</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Automation</strong></td>
      <td style="$tdAltStyle">Automatic Team/Channel resolution via Graph API • Certificate-based app-only auth • 36 Azure App Registrations for throttle distribution</td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Notifications</strong></td>
      <td style="$tdStyle">Power Automate email flows: "Ready for Review" (6 AM + 1 PM) and "Migration Results" (7 AM daily)</td>
    </tr>
  </table>
</div>
"@

# ============================================================
# SECTION 4: PROCESS FLOW (6 STEPS)
# ============================================================

$processFlowHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Process Flow (6 Steps)</h2>
  
  <div style="text-align:center;margin-bottom:16px;font-size:13px;">
    <span style="display:inline-block;background:$($colors.Purple);color:#fff;padding:4px 12px;border-radius:4px;margin:0 8px;">👤 USER ACTION</span>
    <span style="display:inline-block;background:#e9ecef;color:#212529;padding:4px 12px;border-radius:4px;border:1px solid #adb5bd;margin:0 8px;">⚙️ SYSTEM</span>
    <span style="display:inline-block;background:$($colors.WarnBg);color:#212529;padding:4px 12px;border-radius:4px;border:1px solid $($colors.WarnBorder);margin:0 8px;">⚠️ CHECK</span>
    <span style="display:inline-block;background:$($colors.InfoBg);color:#212529;padding:4px 12px;border-radius:4px;border:1px solid $($colors.InfoBorder);margin:0 8px;">📋 INFO</span>
  </div>
  
  <div style="display:flex;justify-content:center;gap:8px;align-items:flex-start;flex-wrap:wrap;">
    
    <!-- STEP 1 -->
    <div style="flex:1;min-width:140px;max-width:180px;background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;overflow:hidden;">
      <div style="background:$($colors.Navy);color:#fff;padding:10px 8px;text-align:center;font-weight:600;font-size:12px;">
        <span style="font-size:10px;display:block;">STEP 1</span>CREATE ITEM
      </div>
      <div style="padding:10px;display:flex;flex-direction:column;gap:8px;">
        <div style="background:$($colors.Purple);color:#fff;padding:10px;border-radius:6px;font-size:11px;text-align:center;">
          👤 <strong>USER ENTERS:</strong><br>DIV, Title, ITDistro<br>SourcePath, TeamName<br>TimeZone
        </div>
      </div>
    </div>
    
    <div style="display:flex;align-items:center;color:#adb5bd;font-size:20px;padding:40px 4px 0 4px;">→</div>
    
    <!-- STEP 2 -->
    <div style="flex:1;min-width:140px;max-width:180px;background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;overflow:hidden;">
      <div style="background:$($colors.Navy);color:#fff;padding:10px 8px;text-align:center;font-weight:600;font-size:12px;">
        <span style="font-size:10px;display:block;">STEP 2</span>AUTOMATIC SCAN
      </div>
      <div style="padding:10px;display:flex;flex-direction:column;gap:6px;">
        <div style="background:#e9ecef;border:1px solid #adb5bd;padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚙️ System scans source<br><em>Begins within 5 min</em>
        </div>
        <div style="background:$($colors.WarnBg);border:1px solid $($colors.WarnBorder);padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚠️ <strong>CHECK:</strong> Errors column
        </div>
        <div style="background:$($colors.InfoBg);border:1px solid $($colors.InfoBorder);padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          📋 <strong>7yr</strong> = data to migrate
        </div>
      </div>
    </div>
    
    <div style="display:flex;align-items:center;color:#adb5bd;font-size:20px;padding:40px 4px 0 4px;">→</div>
    
    <!-- STEP 3 -->
    <div style="flex:1;min-width:140px;max-width:180px;background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;overflow:hidden;">
      <div style="background:$($colors.Navy);color:#fff;padding:10px 8px;text-align:center;font-weight:600;font-size:12px;">
        <span style="font-size:10px;display:block;">STEP 3</span>TARGET RESOLUTION
      </div>
      <div style="padding:10px;display:flex;flex-direction:column;gap:6px;">
        <div style="background:#e9ecef;border:1px solid #adb5bd;padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚙️ System resolves Team<br><em>Begins within 5 min</em>
        </div>
        <div style="background:$($colors.WarnBg);border:1px solid $($colors.WarnBorder);padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚠️ <strong>CHECK:</strong> TargetURL<br><span style="color:$($colors.Green);">🟢 Green</span> = OK<br><span style="color:$($colors.Red);">🔴 Red</span> = Low storage
        </div>
      </div>
    </div>
    
    <div style="display:flex;align-items:center;color:#adb5bd;font-size:20px;padding:40px 4px 0 4px;">→</div>
    
    <!-- STEP 4 -->
    <div style="flex:1;min-width:140px;max-width:180px;background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;overflow:hidden;">
      <div style="background:$($colors.Navy);color:#fff;padding:10px 8px;text-align:center;font-weight:600;font-size:12px;">
        <span style="font-size:10px;display:block;">STEP 4</span>QUEUE MIGRATION
      </div>
      <div style="padding:10px;display:flex;flex-direction:column;gap:8px;">
        <div style="background:$($colors.Purple);color:#fff;padding:10px;border-radius:6px;font-size:11px;text-align:center;">
          👤 <strong>USER SETS:</strong><br>Migrate = "Migrate"
        </div>
      </div>
    </div>
    
    <div style="display:flex;align-items:center;color:#adb5bd;font-size:20px;padding:40px 4px 0 4px;">→</div>
    
    <!-- STEP 5 -->
    <div style="flex:1;min-width:140px;max-width:180px;background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;overflow:hidden;">
      <div style="background:$($colors.Navy);color:#fff;padding:10px 8px;text-align:center;font-weight:600;font-size:12px;">
        <span style="font-size:10px;display:block;">STEP 5</span>MIGRATION
      </div>
      <div style="padding:10px;display:flex;flex-direction:column;gap:6px;">
        <div style="background:#e9ecef;border:1px solid #adb5bd;padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚙️ Files copied to SPO
        </div>
        <div style="background:$($colors.WarnBg);border:1px solid $($colors.WarnBorder);padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚠️ <strong>CHECK:</strong> Result<br><span style="color:$($colors.Green);">🟢 Migrated</span><br><span style="color:$($colors.Red);">🔴 Failed</span>
        </div>
      </div>
    </div>
    
    <div style="display:flex;align-items:center;color:#adb5bd;font-size:20px;padding:40px 4px 0 4px;">→</div>
    
    <!-- STEP 6 -->
    <div style="flex:1;min-width:140px;max-width:180px;background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;overflow:hidden;">
      <div style="background:$($colors.Navy);color:#fff;padding:10px 8px;text-align:center;font-weight:600;font-size:12px;">
        <span style="font-size:10px;display:block;">STEP 6</span>POST-MIGRATION
      </div>
      <div style="padding:10px;display:flex;flex-direction:column;gap:6px;">
        <div style="background:#e9ecef;border:1px solid #adb5bd;padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚙️ Source read-only<br>Files + empty folders deleted
        </div>
        <div style="background:$($colors.WarnBg);border:1px solid $($colors.WarnBorder);padding:8px;border-radius:6px;font-size:11px;text-align:center;">
          ⚠️ Failed files remain<br>→ Fix &amp; migrate again
        </div>
      </div>
    </div>
    
  </div>
  
  <div style="$noteInfoStyle margin-top:20px;">
    <strong>📐 Interactive Diagrams:</strong> For detailed Mermaid flowcharts showing the full system architecture and migration pipeline, open <a href="diagrams/CommonDriveMigration_Architecture_SPO.html" style="color:$($colors.Navy);font-weight:600;">Architecture Diagrams (Interactive)</a> in your browser.
  </div>
</div>
"@

# ============================================================
# SECTION 5: SYSTEM ARCHITECTURE
# ============================================================

$architectureHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">System Architecture</h2>
  
  <h3 style="$subHeaderStyle">Infrastructure (6 Servers)</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Datacenter</th>
      <th style="$thStyle">Server 1</th>
      <th style="$thStyle">Server 2</th>
      <th style="$thStyle">Server 3</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>HQD1</strong></td>
      <td style="$tdStyle">hqd1-sdass-201</td>
      <td style="$tdStyle">hqd1-sdass-202</td>
      <td style="$tdStyle">hqd1-sdass-203</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>HQD2</strong></td>
      <td style="$tdAltStyle">hqd2-sdass-201</td>
      <td style="$tdAltStyle">hqd2-sdass-202</td>
      <td style="$tdAltStyle">hqd2-sdass-203</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Component Summary</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Component</th><th style="$thStyle">Count</th><th style="$thStyle">Details</th></tr>
    <tr><td style="$tdStyle"><strong>Servers</strong></td><td style="$tdStyle">6</td><td style="$tdStyle">2 datacenters × 3 servers</td></tr>
    <tr><td style="$tdAltStyle"><strong>SPMT Instances</strong></td><td style="$tdAltStyle">18</td><td style="$tdAltStyle">3 per server for throttle distribution</td></tr>
    <tr><td style="$tdStyle"><strong>Scheduled Tasks</strong></td><td style="$tdStyle">30</td><td style="$tdStyle">5 per server</td></tr>
    <tr><td style="$tdAltStyle"><strong>App Registrations</strong></td><td style="$tdAltStyle">36</td><td style="$tdAltStyle">1 Graph + 6 SPO Admin + 18 SPMT + 11 Helper</td></tr>
    <tr><td style="$tdStyle"><strong>Service Account</strong></td><td style="$tdStyle">1</td><td style="$tdStyle">svc-migration</td></tr>
    <tr><td style="$tdAltStyle"><strong>Certificate</strong></td><td style="$tdAltStyle">1</td><td style="$tdAltStyle">App-only auth (LocalMachine\My)</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 6: KEY FEATURES
# ============================================================

$featuresHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Key Features</h2>
  
  <table style="$tableStyle">
    <tr><th style="$thStyle">Feature</th><th style="$thStyle">Description</th></tr>
    <tr><td style="$tdStyle"><strong>Distributed Processing</strong></td><td style="$tdStyle">6 servers × 3 instances = 18 parallel workers</td></tr>
    <tr><td style="$tdAltStyle"><strong>Throttle Distribution</strong></td><td style="$tdAltStyle">Each instance uses different AppClientId to spread API limits</td></tr>
    <tr><td style="$tdStyle"><strong>Timezone-aware Scheduling</strong></td><td style="$tdStyle">Items processed based on user's local timezone (EST, CST, MST, PST, AKST, HST)</td></tr>
    <tr><td style="$tdAltStyle"><strong>FIFO Queue</strong></td><td style="$tdAltStyle">Items processed in the order they were queued</td></tr>
    <tr><td style="$tdStyle"><strong>Large Migration Handling</strong></td><td style="$tdStyle">Migrations ≥10GB restricted to weekends/holidays only</td></tr>
    <tr><td style="$tdAltStyle"><strong>ANYTIME Option</strong></td><td style="$tdAltStyle">Items with TimeZone=ANYTIME can run 24/7</td></tr>
    <tr><td style="$tdStyle"><strong>Federal Holiday Support</strong></td><td style="$tdStyle">Pre-configured holiday list allows all-day processing</td></tr>
    <tr><td style="$tdAltStyle"><strong>Claim-based Locking</strong></td><td style="$tdAltStyle">ClaimedBy/ClaimedAt prevents duplicate work</td></tr>
    <tr><td style="$tdStyle"><strong>Age-based Migration</strong></td><td style="$tdStyle">Only files modified within 7 years are migrated</td></tr>
    <tr><td style="$tdAltStyle"><strong>App-only Auth</strong></td><td style="$tdAltStyle">Certificate-based, no MFA required</td></tr>
    <tr><td style="$tdStyle"><strong>Empty Folder Cleanup</strong></td><td style="$tdStyle">Triple-verified before deletion (existence + empty + re-check)</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 7: SCHEDULING LOGIC
# ============================================================

$schedulingHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Scheduling Logic</h2>
  
  <div style="$noteWarnStyle">
    <strong>Size-Based Restrictions:</strong> Large migrations (≥10GB) are restricted to weekends and federal holidays to minimize impact on users. Use <code style="$codeStyle">ANYTIME</code> timezone for items that should run 24/7.
  </div>
  
  <h3 style="$subHeaderStyle">Migration Windows by Size</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Item Type</th>
      <th style="$thStyle">Mon-Thu 5PM-4AM</th>
      <th style="$thStyle">Fri 5PM → Mon 4AM</th>
      <th style="$thStyle">Federal Holidays</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Small (&lt;10GB)</strong></td>
      <td style="$tdStyle"><span style="color:$($colors.Green);">✅ Allowed</span></td>
      <td style="$tdStyle"><span style="color:$($colors.Green);">✅ Allowed</span></td>
      <td style="$tdStyle"><span style="color:$($colors.Green);">✅ All day</span></td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Large (≥10GB)</strong></td>
      <td style="$tdAltStyle"><span style="color:$($colors.Red);">❌ Blocked</span></td>
      <td style="$tdAltStyle"><span style="color:$($colors.Green);">✅ Allowed</span></td>
      <td style="$tdAltStyle"><span style="color:$($colors.Green);">✅ All day</span></td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>ANYTIME</strong></td>
      <td style="$tdStyle"><span style="color:$($colors.Green);">✅ 24/7</span></td>
      <td style="$tdStyle"><span style="color:$($colors.Green);">✅ 24/7</span></td>
      <td style="$tdStyle"><span style="color:$($colors.Green);">✅ 24/7</span></td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Supported Timezones</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">TimeZone</th><th style="$thStyle">UTC Offset</th><th style="$thStyle">Region</th></tr>
    <tr><td style="$tdStyle">EST</td><td style="$tdStyle">UTC-5 / UTC-4 (DST)</td><td style="$tdStyle">Eastern</td></tr>
    <tr><td style="$tdAltStyle">CST</td><td style="$tdAltStyle">UTC-6 / UTC-5 (DST)</td><td style="$tdAltStyle">Central</td></tr>
    <tr><td style="$tdStyle">MST</td><td style="$tdStyle">UTC-7 / UTC-6 (DST)</td><td style="$tdStyle">Mountain</td></tr>
    <tr><td style="$tdAltStyle">PST</td><td style="$tdAltStyle">UTC-8 / UTC-7 (DST)</td><td style="$tdAltStyle">Pacific</td></tr>
    <tr><td style="$tdStyle">AKST</td><td style="$tdStyle">UTC-9 / UTC-8 (DST)</td><td style="$tdStyle">Alaska</td></tr>
    <tr><td style="$tdAltStyle">HST</td><td style="$tdAltStyle">UTC-10 (no DST)</td><td style="$tdAltStyle">Hawaii</td></tr>
    <tr><td style="$tdStyle"><strong>ANYTIME</strong></td><td style="$tdStyle">N/A</td><td style="$tdStyle">No restrictions - runs 24/7</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 8: AZURE APP REGISTRATIONS (36 TOTAL)
# ============================================================

$appsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Azure App Registrations (36 total)</h2>
  
  <h3 style="$subHeaderStyle">Summary by Category</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Category</th><th style="$thStyle">Count</th><th style="$thStyle">Purpose</th></tr>
    <tr><td style="$tdStyle"><strong>Graph App</strong></td><td style="$tdStyle">1</td><td style="$tdStyle">Teams/Channel lookup (Team.ReadBasic.All, Channel.ReadBasic.All, Sites.Read.All)</td></tr>
    <tr><td style="$tdAltStyle"><strong>SPO Admin Apps</strong></td><td style="$tdAltStyle">6</td><td style="$tdAltStyle">Site operations - 1 per server (Sites.FullControl.All)</td></tr>
    <tr><td style="$tdStyle"><strong>SPMT Apps</strong></td><td style="$tdStyle">18</td><td style="$tdStyle">Migration API - 3 per server for throttle distribution</td></tr>
    <tr><td style="$tdAltStyle"><strong>UNC Scan / Helper Apps</strong></td><td style="$tdAltStyle">11</td><td style="$tdAltStyle">Storage scanning, list read/write</td></tr>
  </table>
  
  <h3 style="$subHeaderStyle">Full App Registration List</h3>
  <table style="$tableStyle font-size:12px;">
    <tr><th style="$thStyle">Category</th><th style="$thStyle">Server</th><th style="$thStyle">App Name</th></tr>
    <tr><td style="$tdStyle">Helper</td><td style="$tdStyle">1-201</td><td style="$tdStyle">CommonDriveMigration-Helper-1-201</td></tr>
    <tr><td style="$tdAltStyle">Helper</td><td style="$tdAltStyle">1-202</td><td style="$tdAltStyle">CommonDriveMigration-Helper-1-202</td></tr>
    <tr><td style="$tdStyle">Helper</td><td style="$tdStyle">1-203</td><td style="$tdStyle">CommonDriveMigration-Helper-1-203</td></tr>
    <tr><td style="$tdAltStyle">Helper</td><td style="$tdAltStyle">2-201</td><td style="$tdAltStyle">CommonDriveMigration-Helper-2-201</td></tr>
    <tr><td style="$tdStyle">Helper</td><td style="$tdStyle">2-202</td><td style="$tdStyle">CommonDriveMigration-Helper-2-202</td></tr>
    <tr><td style="$tdAltStyle">Helper</td><td style="$tdAltStyle">2-203</td><td style="$tdAltStyle">CommonDriveMigration-Helper-2-203</td></tr>
    <tr><td style="$tdStyle">Helper</td><td style="$tdStyle">Shared</td><td style="$tdStyle">CommonDriveMigration-HelperTools</td></tr>
    <tr><td style="$tdAltStyle">UNC Scan</td><td style="$tdAltStyle">1-201</td><td style="$tdAltStyle">CommonDriveMigration-UNCScan-1-201</td></tr>
    <tr><td style="$tdStyle">UNC Scan</td><td style="$tdStyle">1-202</td><td style="$tdStyle">CommonDriveMigration-UNCScan-1-202</td></tr>
    <tr><td style="$tdAltStyle">UNC Scan</td><td style="$tdAltStyle">1-203</td><td style="$tdAltStyle">CommonDriveMigration-UNCScan-1-203</td></tr>
    <tr><td style="$tdStyle">UNC Scan</td><td style="$tdStyle">2-201</td><td style="$tdStyle">CommonDriveMigration-UNCScan-2-201</td></tr>
    <tr><td style="$tdAltStyle">UNC Scan</td><td style="$tdAltStyle">2-202</td><td style="$tdAltStyle">CommonDriveMigration-UNCScan-2-202</td></tr>
    <tr><td style="$tdStyle">UNC Scan</td><td style="$tdStyle">2-203</td><td style="$tdStyle">CommonDriveMigration-UNCScan-2-203</td></tr>
    <tr><td style="$tdAltStyle">SPMT</td><td style="$tdAltStyle">Shared</td><td style="$tdAltStyle">CommonDriveMigration-SPMT</td></tr>
    <tr><td style="$tdStyle">SPMT 1</td><td style="$tdStyle">1-201</td><td style="$tdStyle">CommonDriveMigration-SPMT-1-201</td></tr>
    <tr><td style="$tdAltStyle">SPMT 1</td><td style="$tdAltStyle">1-202</td><td style="$tdAltStyle">CommonDriveMigration-SPMT-1-202</td></tr>
    <tr><td style="$tdStyle">SPMT 1</td><td style="$tdStyle">1-203</td><td style="$tdStyle">CommonDriveMigration-SPMT-1-203</td></tr>
    <tr><td style="$tdAltStyle">SPMT 1</td><td style="$tdAltStyle">2-201</td><td style="$tdAltStyle">CommonDriveMigration-SPMT-2-201</td></tr>
    <tr><td style="$tdStyle">SPMT 1</td><td style="$tdStyle">2-202</td><td style="$tdStyle">CommonDriveMigration-SPMT-2-202</td></tr>
    <tr><td style="$tdAltStyle">SPMT 1</td><td style="$tdAltStyle">2-203</td><td style="$tdAltStyle">CommonDriveMigration-SPMT-2-203</td></tr>
    <tr><td style="$tdStyle">SPMT 2</td><td style="$tdStyle">1-201</td><td style="$tdStyle">CommonDriveMigration-SPMT2-1-201</td></tr>
    <tr><td style="$tdAltStyle">SPMT 2</td><td style="$tdAltStyle">1-202</td><td style="$tdAltStyle">CommonDriveMigration-SPMT2-1-202</td></tr>
    <tr><td style="$tdStyle">SPMT 2</td><td style="$tdStyle">1-203</td><td style="$tdStyle">CommonDriveMigration-SPMT2-1-203</td></tr>
    <tr><td style="$tdAltStyle">SPMT 2</td><td style="$tdAltStyle">2-201</td><td style="$tdAltStyle">CommonDriveMigration-SPMT2-2-201</td></tr>
    <tr><td style="$tdStyle">SPMT 2</td><td style="$tdStyle">2-202</td><td style="$tdStyle">CommonDriveMigration-SPMT2-2-202</td></tr>
    <tr><td style="$tdAltStyle">SPMT 2</td><td style="$tdAltStyle">2-203</td><td style="$tdAltStyle">CommonDriveMigration-SPMT2-2-203</td></tr>
    <tr><td style="$tdStyle">SPMT 3</td><td style="$tdStyle">1-201</td><td style="$tdStyle">CommonDriveMigration-SPMT3-1-201</td></tr>
    <tr><td style="$tdAltStyle">SPMT 3</td><td style="$tdAltStyle">1-202</td><td style="$tdAltStyle">CommonDriveMigration-SPMT3-1-202</td></tr>
    <tr><td style="$tdStyle">SPMT 3</td><td style="$tdStyle">1-203</td><td style="$tdStyle">CommonDriveMigration-SPMT3-1-203</td></tr>
    <tr><td style="$tdAltStyle">SPMT 3</td><td style="$tdAltStyle">2-201</td><td style="$tdAltStyle">CommonDriveMigration-SPMT3-2-201</td></tr>
    <tr><td style="$tdStyle">SPMT 3</td><td style="$tdStyle">2-202</td><td style="$tdStyle">CommonDriveMigration-SPMT3-2-202</td></tr>
    <tr><td style="$tdAltStyle">SPMT 3</td><td style="$tdAltStyle">2-203</td><td style="$tdAltStyle">CommonDriveMigration-SPMT3-2-203</td></tr>
  </table>
  
  <div style="$noteStyle">
    <strong>💡 Why 36 apps?</strong> Distributing API calls across multiple app registrations prevents throttling. Each SPMT worker uses a different app, allowing 18 parallel migrations without hitting tenant limits.
  </div>
</div>
"@

# ============================================================
# SECTION 9: POWER AUTOMATE EMAIL NOTIFICATIONS
# ============================================================

$notificationsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Power Automate Email Notifications</h2>
  
  <div style="$noteInfoStyle">
    <strong>Automated Notifications:</strong> Three Power Automate flows send daily email notifications to ITDistro contacts, keeping users informed of scan completions and migration results.
  </div>
  
  <h3 style="$subHeaderStyle">Notification Flows</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Flow Name</th>
      <th style="$thStyle">Schedule</th>
      <th style="$thStyle">Trigger Condition</th>
      <th style="$thStyle">Email Subject</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Ready for Review AM</strong></td>
      <td style="$tdStyle">Daily 6:00 AM</td>
      <td style="$tdStyle">FileCount ≠ null AND StorageQuota ≠ null AND NotifiedReady ≠ 1</td>
      <td style="$tdStyle">"Items Ready for Review"</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Ready for Review PM</strong></td>
      <td style="$tdAltStyle">Daily 1:00 PM</td>
      <td style="$tdAltStyle">Same as AM</td>
      <td style="$tdAltStyle">"Items Ready for Review"</td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Migration Results AM</strong></td>
      <td style="$tdStyle">Daily 7:00 AM</td>
      <td style="$tdStyle">Migrate = Migrated/MigratedWithErrors/Failed AND NotifiedComplete ≠ 1</td>
      <td style="$tdStyle">"Migration Nightly Results"</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Email Configuration</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Setting</th><th style="$thStyle">Value</th></tr>
    <tr><td style="$tdStyle">From</td><td style="$tdStyle">Office365@contoso.gov</td></tr>
    <tr><td style="$tdAltStyle">To</td><td style="$tdAltStyle">ITDistro column value (grouped per recipient)</td></tr>
    <tr><td style="$tdStyle">BCC</td><td style="$tdStyle">user1@contoso.gov; user2@contoso.gov</td></tr>
    <tr><td style="$tdAltStyle">Importance</td><td style="$tdAltStyle">High</td></tr>
  </table>
  
  <h3 style="$subHeaderStyle">Tracking Columns</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Column</th><th style="$thStyle">Type</th><th style="$thStyle">Purpose</th></tr>
    <tr><td style="$tdStyle">NotifiedReady</td><td style="$tdStyle">Yes/No</td><td style="$tdStyle">Prevents duplicate "Ready for Review" emails</td></tr>
    <tr><td style="$tdAltStyle">NotifiedComplete</td><td style="$tdAltStyle">Yes/No</td><td style="$tdAltStyle">Prevents duplicate "Migration Results" emails</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 10: SCHEDULED TASKS
# ============================================================

$tasksHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Scheduled Tasks (Per Server)</h2>
  
  <p>Each of the 6 servers runs these scheduled tasks:</p>
  
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Task</th>
      <th style="$thStyle">Interval</th>
      <th style="$thStyle">Script</th>
      <th style="$thStyle">Purpose</th>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>UNC Storage Scan</strong></td>
      <td style="$tdStyle">Every 5 min</td>
      <td style="$tdStyle"><code style="$codeStyle">Invoke-UNCStorageScan-v2.ps1</code></td>
      <td style="$tdStyle">Scan new source paths, calculate 3/5/7yr sizes</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Target Resolution</strong></td>
      <td style="$tdAltStyle">Every 5 min</td>
      <td style="$tdAltStyle"><code style="$codeStyle">Update-MigrationTargets.v2.ps1</code></td>
      <td style="$tdAltStyle">Resolve Teams/Channels, check storage</td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>SPMT Worker</strong> <span style="$badgeStyle">×3</span></td>
      <td style="$tdStyle">Every 15 min</td>
      <td style="$tdStyle"><code style="$codeStyle">CommonDriveMigration.v2.ps1</code></td>
      <td style="$tdStyle">Execute migrations with scheduling</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><strong>Dashboard</strong></td>
      <td style="$tdAltStyle">Every 2 hrs</td>
      <td style="$tdAltStyle"><code style="$codeStyle">New-MigrationDashboard.ps1</code></td>
      <td style="$tdAltStyle">Update stats dashboard page</td>
    </tr>
    <tr>
      <td style="$tdStyle"><strong>Log Cleanup</strong></td>
      <td style="$tdStyle">Daily 2 AM</td>
      <td style="$tdStyle"><code style="$codeStyle">Clear-EmptyMigrationLogs.ps1</code></td>
      <td style="$tdStyle">Remove old empty log folders</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Task Command Lines</h3>
  
  <p><strong>UNC Storage Scan</strong> (every 5 min):</p>
  <pre style="$preStyle">powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\Scripts\Invoke-UNCStorageScan-v2.ps1" -AutoRun</pre>
  
  <p><strong>Target Resolution</strong> (every 5 min):</p>
  <pre style="$preStyle">powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\Scripts\Update-MigrationTargets.v2.ps1" -AutoRun</pre>
  
  <p><strong>SPMT Worker</strong> (every 15 min):</p>
  <pre style="$preStyle">powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\Scripts\CommonDriveMigration.v2.ps1" -AutoRun -MaxItems 1 -Continuous -UseScheduling</pre>
  
  <div style="$noteInfoStyle">
    <ul style="margin:0;padding-left:20px;">
      <li><code style="$codeStyle">-MaxItems 1</code> = Process one item at a time (no hoarding)</li>
      <li><code style="$codeStyle">-Continuous</code> = Loop until MaxRuntime or queue empty</li>
      <li><code style="$codeStyle">-UseScheduling</code> = Respect timezone windows (5PM-4AM local)</li>
    </ul>
  </div>
  
  <p><strong>Dashboard</strong> (every 2 hrs, server 1-201 only):</p>
  <pre style="$preStyle">powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\Scripts\New-MigrationDashboard.ps1"</pre>
  
  <h3 style="$subHeaderStyle">Manual Scripts (Not Scheduled)</h3>
  <p><strong>Landing Page</strong> — run when new divisions are added:</p>
  <pre style="$preStyle">powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\Scripts\New-MigrationLandingPage.ps1"</pre>
</div>
"@

# ============================================================
# SECTION 11: PREREQUISITES
# ============================================================

$prereqsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Prerequisites</h2>
  
  <h3 style="$subHeaderStyle">Software Requirements</h3>
  <ul style="margin:8px 0 16px 20px;padding:0;">
    <li style="margin-bottom:6px;">Windows Server 2016 or later</li>
    <li style="margin-bottom:6px;">PowerShell 5.1 or higher</li>
    <li style="margin-bottom:6px;">SharePoint Migration Tool (SPMT) 4.2.129.0 or later</li>
    <li style="margin-bottom:6px;">PnP.PowerShell module 1.12 or later</li>
  </ul>
  
  <h3 style="$subHeaderStyle">Accounts Required</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Account</th>
      <th style="$thStyle">Purpose</th>
      <th style="$thStyle">Requirements</th>
    </tr>
    <tr>
      <td style="$tdStyle"><code style="$codeStyle">CONTOSO\svc-migration</code></td>
      <td style="$tdStyle">Service Account</td>
      <td style="$tdStyle">Read access to source file shares, network share access</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><code style="$codeStyle">svc-migration@contoso.gov</code></td>
      <td style="$tdAltStyle">SPMT Credential Account</td>
      <td style="$tdAltStyle">Stored in encrypted credential file</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">Azure AD App Registration</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Setting</th>
      <th style="$thStyle">Value</th>
    </tr>
    <tr><td style="$tdStyle">App Name</td><td style="$tdStyle">CommonDriveMigration-SPMT</td></tr>
    <tr><td style="$tdAltStyle">Client ID</td><td style="$tdAltStyle"><code style="$codeStyle">&lt;your-app-client-id&gt;</code> <em>(Azure Portal → App Registrations)</em></td></tr>
    <tr><td style="$tdStyle">Tenant ID</td><td style="$tdStyle"><code style="$codeStyle">&lt;your-tenant-id&gt;</code> <em>(Azure Portal → Overview)</em></td></tr>
    <tr><td style="$tdAltStyle">Certificate Thumbprint</td><td style="$tdAltStyle"><code style="$codeStyle">&lt;your-cert-thumbprint&gt;</code> <em>(Cert:\LocalMachine\My)</em></td></tr>
    <tr><td style="$tdStyle">Permissions</td><td style="$tdStyle">Sites.FullControl.All (Application)</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 12: SERVER SETUP
# ============================================================

$serverSetupHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Server Setup</h2>
  
  <h3 style="$subHeaderStyle">Step 1: Install Required Software</h3>
  <pre style="$preStyle"><span style="color:#6a9955;"># Install PnP.PowerShell (run as Administrator)</span>
Install-Module PnP.PowerShell -Scope AllUsers -Force

<span style="color:#6a9955;"># Install SPMT (download from Microsoft)</span>
<span style="color:#6a9955;"># https://docs.microsoft.com/en-us/sharepointmigration/introducing-the-sharepoint-migration-tool</span></pre>
  
  <h3 style="$subHeaderStyle">Step 2: Create Required Folders</h3>
  <pre style="$preStyle"><span style="color:#6a9955;"># Create script and log directories</span>
New-Item -Path <span style="color:#ce9178;">"F:\Scripts"</span> -ItemType Directory -Force
New-Item -Path <span style="color:#ce9178;">"F:\SPMTTranscripts"</span> -ItemType Directory -Force
New-Item -Path <span style="color:#ce9178;">"F:\Migration-Common-Lists"</span> -ItemType Directory -Force
New-Item -Path <span style="color:#ce9178;">"F:\SPMTLOGS"</span> -ItemType Directory -Force
New-Item -Path <span style="color:#ce9178;">"F:\Reacl-Delete-Logs"</span> -ItemType Directory -Force
New-Item -Path <span style="color:#ce9178;">"F:\UNCScan"</span> -ItemType Directory -Force
New-Item -Path <span style="color:#ce9178;">"F:\MigrationTargets"</span> -ItemType Directory -Force</pre>
  
  <h3 style="$subHeaderStyle">Step 3: Deploy Script Files</h3>
  <p>Copy to <code style="$codeStyle">F:\Scripts\</code>:</p>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Script</th><th style="$thStyle">Purpose</th></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">CommonDriveMigration.v2.ps1</code></td><td style="$tdStyle">Main migration script</td></tr>
    <tr><td style="$tdAltStyle"><code style="$codeStyle">SPMT-Worker.v2.ps1</code></td><td style="$tdAltStyle">SPMT execution worker</td></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">Invoke-UNCStorageScan-v2.ps1</code></td><td style="$tdStyle">Source folder scanner</td></tr>
    <tr><td style="$tdAltStyle"><code style="$codeStyle">Update-MigrationTargets.v2.ps1</code></td><td style="$tdAltStyle">Teams/storage resolution</td></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">New-MigrationDashboard.ps1</code></td><td style="$tdStyle">Stats dashboard</td></tr>
    <tr><td style="$tdAltStyle"><code style="$codeStyle">New-MigrationLandingPage.ps1</code></td><td style="$tdAltStyle">Division landing page</td></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">Clear-EmptyMigrationLogs.ps1</code></td><td style="$tdStyle">Log cleanup</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 13: SHAREPOINT PAGES
# ============================================================

$pagesHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">SharePoint Pages</h2>
  
  <h3 style="$subHeaderStyle">User-Facing Pages</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Page</th><th style="$thStyle">URL</th><th style="$thStyle">Script</th></tr>
    <tr><td style="$tdStyle"><strong>Migration Landing Page</strong></td><td style="$tdStyle"><code style="$codeStyle">/SitePages/MigrationStatus.aspx</code></td><td style="$tdStyle">New-MigrationLandingPage.ps1</td></tr>
    <tr><td style="$tdAltStyle"><strong>Migration Dashboard</strong></td><td style="$tdAltStyle"><code style="$codeStyle">/SitePages/Dashboard.aspx</code></td><td style="$tdAltStyle">New-MigrationDashboard.ps1</td></tr>
    <tr><td style="$tdStyle"><strong>User Manual</strong></td><td style="$tdStyle"><code style="$codeStyle">/SitePages/MigrationUserManual.aspx</code></td><td style="$tdStyle">New-MigrationUserManualPage-Simple.ps1</td></tr>
  </table>
  
  <h3 style="$subHeaderStyle">Admin-Facing Pages</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Page</th><th style="$thStyle">URL</th><th style="$thStyle">Script</th></tr>
    <tr><td style="$tdStyle"><strong>System Documentation</strong></td><td style="$tdStyle"><code style="$codeStyle">/SitePages/SystemDocumentation.aspx</code></td><td style="$tdStyle">New-SystemDocumentationPage.ps1</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 14: CONFIGURATION REFERENCE
# ============================================================

$configHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Configuration Reference</h2>
  
  <p>Key settings in <code style="$codeStyle">CommonDriveMigration.v2.ps1</code>:</p>
  
  <table style="$tableStyle">
    <tr><th style="$thStyle">Setting</th><th style="$thStyle">Default</th><th style="$thStyle">Description</th></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">`$YearsToMigrate</code></td><td style="$tdStyle">7</td><td style="$tdStyle">Only migrate content modified within this many years</td></tr>
    <tr><td style="$tdAltStyle"><code style="$codeStyle">`$UseAppAuth</code></td><td style="$tdAltStyle">`$true</td><td style="$tdAltStyle">Use certificate authentication</td></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">`$EnableIncrementalDelete</code></td><td style="$tdStyle">`$true</td><td style="$tdStyle">Delete only successfully migrated files</td></tr>
    <tr><td style="$tdAltStyle"><code style="$codeStyle">`$EnableEmptyFolderCleanup</code></td><td style="$tdAltStyle">`$true</td><td style="$tdAltStyle">Delete empty folders after file deletion (triple-verified)</td></tr>
    <tr><td style="$tdStyle"><code style="$codeStyle">`$LargeMigrationThresholdGB</code></td><td style="$tdStyle">10</td><td style="$tdStyle">Items ≥10GB only run weekends/holidays</td></tr>
    <tr><td style="$tdAltStyle"><code style="$codeStyle">`$BlockedExtensions</code></td><td style="$tdAltStyle">pst, ds_store, tmp, temp</td><td style="$tdAltStyle">Files to exclude from migration</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 15: LOG LOCATIONS
# ============================================================

$logsHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Log Locations</h2>
  
  <h3 style="$subHeaderStyle">Server-Side Logs</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Location</th>
      <th style="$thStyle">Script</th>
      <th style="$thStyle">Contents</th>
    </tr>
    <tr>
      <td style="$tdStyle"><code style="$codeStyle">F:\UNCScan\</code></td>
      <td style="$tdStyle">Invoke-UNCStorageScan-v2.ps1</td>
      <td style="$tdStyle">Transcript logs, lock file</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><code style="$codeStyle">F:\MigrationTargets\</code></td>
      <td style="$tdAltStyle">Update-MigrationTargets.v2.ps1</td>
      <td style="$tdAltStyle">Transcript logs</td>
    </tr>
    <tr>
      <td style="$tdStyle"><code style="$codeStyle">F:\SPMTLOGS\</code></td>
      <td style="$tdStyle">CommonDriveMigration.v2.ps1</td>
      <td style="$tdStyle">SPMT working folder, task reports</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><code style="$codeStyle">F:\Reacl-Delete-Logs\</code></td>
      <td style="$tdAltStyle">CommonDriveMigration.v2.ps1</td>
      <td style="$tdAltStyle">ACL change scripts, deletion reports</td>
    </tr>
    <tr>
      <td style="$tdStyle"><code style="$codeStyle">F:\Migration-Common-Lists\</code></td>
      <td style="$tdStyle">CommonDriveMigration.v2.ps1</td>
      <td style="$tdStyle">CSV source lists</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><code style="$codeStyle">F:\Scripts\</code></td>
      <td style="$tdAltStyle">All</td>
      <td style="$tdAltStyle">Script files, credentials</td>
    </tr>
  </table>
  
  <h3 style="$subHeaderStyle">SPO List Attachments</h3>
  <table style="$tableStyle">
    <tr>
      <th style="$thStyle">Attachment</th>
      <th style="$thStyle">Created By</th>
      <th style="$thStyle">Contents</th>
    </tr>
    <tr>
      <td style="$tdStyle"><code style="$codeStyle">UNCscanErrors_*.csv</code></td>
      <td style="$tdStyle">Invoke-UNCStorageScan-v2.ps1</td>
      <td style="$tdStyle">Scan errors (path too long, access denied)</td>
    </tr>
    <tr>
      <td style="$tdAltStyle"><code style="$codeStyle">FailureSummaryReport2.csv</code></td>
      <td style="$tdAltStyle">CommonDriveMigration.v2.ps1</td>
      <td style="$tdAltStyle">Migration failures</td>
    </tr>
    <tr>
      <td style="$tdStyle"><code style="$codeStyle">DeletionReport_*.csv</code></td>
      <td style="$tdStyle">CommonDriveMigration.v2.ps1</td>
      <td style="$tdStyle">Files + empty folders deleted from source</td>
    </tr>
  </table>
</div>
"@

# ============================================================
# SECTION 16: TROUBLESHOOTING
# ============================================================

$troubleshootHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Troubleshooting</h2>
  
  <h3 style="$subHeaderStyle">Task Won't Start</h3>
  <pre style="$preStyle"><span style="color:#6a9955;"># Check task status</span>
Get-ScheduledTask -TaskName "CommonDrive-Migration-AutoRun" | Select-Object State, LastRunTime, LastTaskResult

<span style="color:#6a9955;"># View recent task history</span>
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" -MaxEvents 20 | 
    Where-Object { `$_.Message -like "*CommonDrive*" }</pre>
  
  <h3 style="$subHeaderStyle">Certificate Issues</h3>
  <pre style="$preStyle"><span style="color:#6a9955;"># Verify certificate exists (replace with your thumbprint)</span>
<span style="color:#9cdcfe;">`$thumbprint</span> = <span style="color:#ce9178;">"&lt;your-cert-thumbprint&gt;"</span>
Get-ChildItem Cert:\LocalMachine\My | Where-Object { `$_.Thumbprint -eq <span style="color:#9cdcfe;">`$thumbprint</span> }

<span style="color:#6a9955;"># Check certificate expiration</span>
Get-ChildItem Cert:\LocalMachine\My | Where-Object { `$_.Thumbprint -eq <span style="color:#9cdcfe;">`$thumbprint</span> } | 
    Select-Object Subject, NotAfter, @{N='DaysUntilExpiry';E={(`$_.NotAfter - (Get-Date)).Days}}</pre>
  
  <h3 style="$subHeaderStyle">SPMT Errors</h3>
  <pre style="$preStyle"><span style="color:#6a9955;"># Check recent SPMT logs</span>
Get-ChildItem "F:\SPMTLOGS" -Recurse -Filter "*.log" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5 | 
    ForEach-Object { Get-Content `$_.FullName -Tail 50 }</pre>
  
  <h3 style="$subHeaderStyle">Common Issues</h3>
  <table style="$tableStyle">
    <tr><th style="$thStyle">Symptom</th><th style="$thStyle">Cause</th><th style="$thStyle">Fix</th></tr>
    <tr><td style="$tdStyle">Item stuck in "Claimed"</td><td style="$tdStyle">Previous run crashed</td><td style="$tdStyle">Clear ClaimedBy/ClaimedAt columns (auto-releases after 2hr)</td></tr>
    <tr><td style="$tdAltStyle">Migration not starting</td><td style="$tdAltStyle">Outside migration window</td><td style="$tdAltStyle">Wait for 5PM local or use ANYTIME timezone</td></tr>
    <tr><td style="$tdStyle">Access denied errors</td><td style="$tdStyle">Certificate or permission issue</td><td style="$tdStyle">Verify cert thumbprint, check app permissions</td></tr>
    <tr><td style="$tdAltStyle">TargetURL shows red</td><td style="$tdAltStyle">Insufficient storage</td><td style="$tdAltStyle">Increase site quota or delete old content</td></tr>
  </table>
</div>
"@

# ============================================================
# SECTION 17: SECURITY
# ============================================================

$securityHtml = @"
<div style="$sectionStyle">
  <h2 style="$headerStyle">Security Considerations</h2>
  
  <ul style="margin:8px 0 16px 20px;padding:0;">
    <li style="margin-bottom:6px;"><strong>Credential File:</strong> <code style="$codeStyle">SPMTCred.xml</code> contains encrypted credentials. Protect with NTFS permissions.</li>
    <li style="margin-bottom:6px;"><strong>Certificate:</strong> Only grant necessary accounts access to the private key.</li>
    <li style="margin-bottom:6px;"><strong>Service Account:</strong> Use a dedicated service account with minimal required permissions.</li>
    <li style="margin-bottom:6px;"><strong>Source Deletion:</strong> The script deletes source files after successful migration.</li>
  </ul>
  
  <div style="$noteDangerStyle">
    <strong>⚠️ WARNING:</strong> <code style="$codeStyle">`$EnableIncrementalDelete = `$true</code> and <code style="$codeStyle">`$EnableEmptyFolderCleanup = `$true</code> will permanently delete files and folders from the source after successful migration. Test on a small, non-critical folder first before running bulk migrations.
  </div>
</div>
"@

# ============================================================
# SECTION 18: FOOTER
# ============================================================

$footerHtml = @"
<div style="text-align:center;padding:20px;color:#6c757d;font-size:12px;margin-top:20px;">
  Common Drive Migration v2.7 | Contoso USSec/IL6 Environment | April 2026<br/>
  Script Author: Douglas Cox [Microsoft CSA]
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
Set-PnPPage -Identity $PageName -HeaderLayoutType NoImage -Title "Common Drive Migration - System Documentation"

# Add sections
Write-Host "   Adding content sections..." -ForegroundColor Gray

Add-PnPPageTextPart -Page $PageName -Text $headerHtml -Order 1
Add-PnPPageTextPart -Page $PageName -Text $warningHtml -Order 2
Add-PnPPageTextPart -Page $PageName -Text $summaryHtml -Order 3
Add-PnPPageTextPart -Page $PageName -Text $processFlowHtml -Order 4
Add-PnPPageTextPart -Page $PageName -Text $architectureHtml -Order 5
Add-PnPPageTextPart -Page $PageName -Text $featuresHtml -Order 6
Add-PnPPageTextPart -Page $PageName -Text $schedulingHtml -Order 7
Add-PnPPageTextPart -Page $PageName -Text $appsHtml -Order 8
Add-PnPPageTextPart -Page $PageName -Text $notificationsHtml -Order 9
Add-PnPPageTextPart -Page $PageName -Text $tasksHtml -Order 10
Add-PnPPageTextPart -Page $PageName -Text $prereqsHtml -Order 11
Add-PnPPageTextPart -Page $PageName -Text $serverSetupHtml -Order 12
Add-PnPPageTextPart -Page $PageName -Text $pagesHtml -Order 13
Add-PnPPageTextPart -Page $PageName -Text $configHtml -Order 14
Add-PnPPageTextPart -Page $PageName -Text $logsHtml -Order 15
Add-PnPPageTextPart -Page $PageName -Text $troubleshootHtml -Order 16
Add-PnPPageTextPart -Page $PageName -Text $securityHtml -Order 17
Add-PnPPageTextPart -Page $PageName -Text $footerHtml -Order 18

# Publish
Set-PnPPage -Identity $PageName -Publish
Write-Host "   [OK] Page published" -ForegroundColor Green

# ============================================================
# DONE
# ============================================================

$pageUrl = "$siteUrl/SitePages/$PageName.aspx"
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   SYSTEM DOCUMENTATION PAGE DEPLOYED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n   Page URL: $pageUrl" -ForegroundColor White
Write-Host "`n"
