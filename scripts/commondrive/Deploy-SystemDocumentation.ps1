<#
.SYNOPSIS
    Deploys the System Documentation page to SharePoint Online.

.DESCRIPTION
    Reads SystemDocumentation_Preview.html, converts CSS classes to inline styles,
    and deploys to SharePoint as a modern page with text web parts.

.PARAMETER PageName
    Name of the page to create. Default: SystemDocumentation

.PARAMETER PreviewOnly
    If set, outputs the converted HTML to console instead of deploying.

.EXAMPLE
    .\Deploy-SystemDocumentation.ps1
    
.EXAMPLE
    .\Deploy-SystemDocumentation.ps1 -PreviewOnly
    
.NOTES
    Version:     1.4.0
    Date:        2026-04-29
    Author:      Douglas Cox [Microsoft CSA]
    
    PREREQUISITE: Before running, upload these images to Site Assets:
    - CommonDrive_diagrams_migration-process-flow.png
    - CommonDrive_diagrams_system-architecture.png
#>

param(
    [string]$PageName = "SystemDocumentation",
    [switch]$PreviewOnly
)

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$siteUrl  = "https://contoso.spo.microsoft.scloud/sites/000001"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$previewHtmlPath = Join-Path $scriptDir "SystemDocumentation_Preview.html"

# App-Only Authentication
$UseAppAuth               = $true
$AppClientId              = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
$AppTenantId              = "dddddddd-dddd-dddd-dddd-dddddddddddd"
$AppCertificateThumbprint = "1111111111111111111111111111111111111111"

# Diagram Images (must be uploaded to Site Assets first)
# Upload these files to: Site Assets library root or SiteAssets/CommonDriveDocs/
$diagramImages = @{
    ProcessFlow  = "CommonDrive_diagrams_migration-process-flow.png"
    Architecture = "CommonDrive_diagrams_system-architecture.png"
}
$imageLibraryPath = "SiteAssets"  # or "SiteAssets/CommonDriveDocs" if using subfolder

# ============================================================
# INLINE STYLE DEFINITIONS
# ============================================================

# These map to the CSS classes in SystemDocumentation_Preview.html
$styles = @{
    # Base styles
    base = "font-family:'Segoe UI',-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;line-height:1.6;color:#212529;"
    
    # Section container
    section = "background:#ffffff;border-radius:4px;margin-top:20px;border:1px solid #dee2e6;padding:24px 28px;"
    
    # Headers
    h1 = "font-size:22px;font-weight:600;color:#ffc107;margin:0 0 6px 0;"
    h2 = "font-size:18px;font-weight:600;color:#002868;margin:0 0 16px 0;padding-bottom:8px;border-bottom:2px solid #bf9b30;"
    h3 = "font-size:15px;font-weight:600;color:#002868;margin:20px 0 12px 0;"
    
    # Tables
    table = "width:100%;border-collapse:collapse;margin:16px 0;font-size:13px;"
    th = "background:#002868;color:#ffffff;padding:10px 12px;text-align:left;border:1px solid #002868;font-weight:600;"
    td = "padding:10px 12px;border:1px solid #dee2e6;color:#212529;vertical-align:top;"
    tdAlt = "padding:10px 12px;border:1px solid #dee2e6;color:#212529;vertical-align:top;background:#f8f9fa;"
    
    # Notes/callouts
    note = "font-size:14px;color:#212529;background:#f8f9fa;padding:12px 16px;border-left:3px solid #bf9b30;border-radius:0 4px 4px 0;margin:16px 0;"
    noteInfo = "font-size:14px;color:#212529;background:#e7f3ff;padding:12px 16px;border-left:3px solid #0078d4;border-radius:0 4px 4px 0;margin:16px 0;"
    noteWarn = "font-size:14px;color:#212529;background:#fff8e6;padding:12px 16px;border-left:3px solid #fd7e14;border-radius:0 4px 4px 0;margin:16px 0;"
    noteDanger = "font-size:14px;color:#212529;background:#f8d7da;padding:12px 16px;border-left:3px solid #dc3545;border-radius:0 4px 4px 0;margin:16px 0;"
    
    # Code blocks
    pre = "background:#1e1e1e;color:#d4d4d4;padding:14px;border-radius:4px;overflow-x:auto;font-family:'Consolas','Courier New',monospace;font-size:12px;line-height:1.5;margin:12px 0;white-space:pre-wrap;"
    code = "background:#e9ecef;padding:2px 6px;border-radius:3px;font-family:'Consolas','Courier New',monospace;font-size:12px;"
    
    # Header banner
    header = "padding:32px;background:linear-gradient(135deg,#002868 0%,#001845 100%);border-radius:6px;text-align:center;"
    headerTitle = "font-size:22px;font-weight:600;color:#ffffff;margin:0 0 6px 0;"
    headerSubtitle = "color:#ffc107;margin:0;font-size:16px;"
    headerMeta = "color:rgba(255,255,255,0.6);margin:8px 0 0 0;font-size:13px;"
    
    # Footer
    footer = "text-align:center;padding:20px;color:#6c757d;font-size:12px;margin-top:20px;"
    
    # Process flow cards
    processFlow = "display:flex;flex-wrap:wrap;gap:8px;align-items:stretch;justify-content:center;margin:20px 0;"
    stepCard = "flex:1 1 140px;max-width:160px;background:#f8f9fa;border-radius:6px;border:1px solid #dee2e6;overflow:hidden;font-size:12px;"
    stepHeader = "background:#002868;color:white;padding:6px 10px;font-weight:600;font-size:11px;"
    stepBody = "padding:10px;font-size:11px;"
    stepUser = "background:#6f42c1;color:white;padding:6px 8px;border-radius:4px;margin-bottom:6px;font-size:10px;"
    stepSystem = "background:#e9ecef;padding:6px 8px;border-radius:4px;margin-bottom:6px;border:1px solid #adb5bd;font-size:10px;"
    stepCheck = "background:#fff8e6;padding:6px 8px;border-radius:4px;margin-bottom:6px;border:1px solid #fd7e14;font-size:10px;"
    stepInfo = "background:#e7f3ff;padding:6px 8px;border-radius:4px;border:1px solid #0078d4;font-size:10px;"
    arrow = "font-size:20px;color:#6c757d;padding:0 4px;align-self:center;"
    
    # Colors
    green = "color:#198754;"
    red = "color:#dc3545;"
    
    # TOC
    toc = "background:#f8f9fa;border:1px solid #dee2e6;border-radius:6px;padding:16px 24px;margin:20px 0;"
    tocList = "margin:0;padding-left:20px;columns:2;column-gap:40px;"
    tocLink = "color:#002868;text-decoration:none;"
    
    # Legend
    legend = "display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px;font-size:12px;"
    
    # Diagram
    diagramSection = "margin:20px 0;text-align:center;"
}

# ============================================================
# LOAD AND PARSE PREVIEW HTML
# ============================================================

Write-Host "`n>> Loading preview HTML" -ForegroundColor Cyan

if (-not (Test-Path $previewHtmlPath)) {
    Write-Host "   [X] Preview file not found: $previewHtmlPath" -ForegroundColor Red
    exit 1
}

$rawHtml = Get-Content $previewHtmlPath -Raw -Encoding UTF8
Write-Host "   [OK] Loaded $([math]::Round($rawHtml.Length / 1024, 1)) KB" -ForegroundColor Green

# ============================================================
# EXTRACT BODY CONTENT
# ============================================================

Write-Host "`n>> Extracting body content" -ForegroundColor Cyan

# Extract content between <body> and </body>
if ($rawHtml -match '(?s)<body[^>]*>(.*?)</body>') {
    $bodyContent = $Matches[1]
} else {
    Write-Host "   [X] Could not find body content" -ForegroundColor Red
    exit 1
}

# Extract content inside the container div
if ($bodyContent -match '(?s)<div class="container">(.*)</div>\s*$') {
    $containerContent = $Matches[1]
} else {
    $containerContent = $bodyContent
}

Write-Host "   [OK] Extracted body content" -ForegroundColor Green

# ============================================================
# CONVERT CLASSES TO INLINE STYLES
# ============================================================

Write-Host "`n>> Converting CSS classes to inline styles" -ForegroundColor Cyan

$html = $containerContent

# Replace class="section" with inline style
$html = $html -replace 'class="section"', "style=`"$($styles.section)`""

# Replace headers
$html = $html -replace '<h1>', "<h1 style=`"$($styles.h1)`">"
$html = $html -replace '<h2>', "<h2 style=`"$($styles.h2)`">"
$html = $html -replace '<h3>', "<h3 style=`"$($styles.h3)`">"

# Replace tables
$html = $html -replace '<table>', "<table style=`"$($styles.table)`">"
$html = $html -replace '<th>', "<th style=`"$($styles.th)`">"
$html = $html -replace '<td>', "<td style=`"$($styles.td)`">"

# Replace notes
$html = $html -replace 'class="note note-info"', "style=`"$($styles.noteInfo)`""
$html = $html -replace 'class="note note-warn"', "style=`"$($styles.noteWarn)`""
$html = $html -replace 'class="note note-danger"', "style=`"$($styles.noteDanger)`""
$html = $html -replace 'class="note"', "style=`"$($styles.note)`""

# Replace code blocks
$html = $html -replace '<pre>', "<pre style=`"$($styles.pre)`">"
$html = $html -replace '<code>', "<code style=`"$($styles.code)`">"

# Replace header banner
$html = $html -replace 'class="header"', "style=`"$($styles.header)`""
$html = $html -replace 'class="subtitle"', "style=`"$($styles.headerSubtitle)`""
$html = $html -replace 'class="meta"', "style=`"$($styles.headerMeta)`""

# Replace footer
$html = $html -replace 'class="footer"', "style=`"$($styles.footer)`""

# Replace TOC
$html = $html -replace 'class="toc"', "style=`"$($styles.toc)`""

# Replace process flow elements
$html = $html -replace 'class="process-flow"', "style=`"$($styles.processFlow)`""
$html = $html -replace 'class="step-card"', "style=`"$($styles.stepCard)`""
$html = $html -replace 'class="step-header"', "style=`"$($styles.stepHeader)`""
$html = $html -replace 'class="step-body"', "style=`"$($styles.stepBody)`""
$html = $html -replace 'class="step-user"', "style=`"$($styles.stepUser)`""
$html = $html -replace 'class="step-system"', "style=`"$($styles.stepSystem)`""
$html = $html -replace 'class="step-check"', "style=`"$($styles.stepCheck)`""
$html = $html -replace 'class="step-info"', "style=`"$($styles.stepInfo)`""
$html = $html -replace 'class="arrow"', "style=`"$($styles.arrow)`""

# Replace legend
$html = $html -replace 'class="legend"', "style=`"$($styles.legend)`""

# Replace diagram section
$html = $html -replace 'class="diagram-section"', "style=`"$($styles.diagramSection)`""

# Replace color classes
$html = $html -replace 'class="green"', "style=`"$($styles.green)`""
$html = $html -replace 'class="red"', "style=`"$($styles.red)`""

# Remove any remaining id attributes (not needed in SPO)
# Keep them for now - they're harmless and might help with anchors

Write-Host "   [OK] Converted styles" -ForegroundColor Green

# ============================================================
# REPLACE MERMAID DIAGRAMS WITH IMAGES
# ============================================================

Write-Host "`n>> Replacing Mermaid diagrams with images" -ForegroundColor Cyan

# Build image URLs
$processFlowUrl  = "$siteUrl/$imageLibraryPath/$($diagramImages.ProcessFlow)"
$architectureUrl = "$siteUrl/$imageLibraryPath/$($diagramImages.Architecture)"

# Image style for responsive display
$imgStyle = "max-width:100%;height:auto;border:1px solid #dee2e6;border-radius:4px;margin:16px 0;"

# Find all Mermaid blocks and replace them
# First occurrence = Migration Process Flow, Second = System Architecture
$mermaidPattern = '(?s)<div class="mermaid">.*?</div>'
$mermaidMatches = [regex]::Matches($html, $mermaidPattern)

if ($mermaidMatches.Count -ge 2) {
    # Replace in reverse order to preserve positions
    # Second match = Architecture diagram
    $archImg = "<div style=`"text-align:center;margin:20px 0;`"><img src=`"$architectureUrl`" alt=`"System Architecture Diagram`" style=`"$imgStyle`" /></div>"
    $html = $html.Substring(0, $mermaidMatches[1].Index) + $archImg + $html.Substring($mermaidMatches[1].Index + $mermaidMatches[1].Length)
    
    # First match = Process Flow diagram
    $flowImg = "<div style=`"text-align:center;margin:20px 0;`"><img src=`"$processFlowUrl`" alt=`"Migration Process Flow Diagram`" style=`"$imgStyle`" /></div>"
    $html = $html.Substring(0, $mermaidMatches[0].Index) + $flowImg + $html.Substring($mermaidMatches[0].Index + $mermaidMatches[0].Length)
    
    Write-Host "   [OK] Replaced 2 Mermaid diagrams with images" -ForegroundColor Green
    Write-Host "        - Process Flow:  $processFlowUrl" -ForegroundColor Gray
    Write-Host "        - Architecture:  $architectureUrl" -ForegroundColor Gray
}
elseif ($mermaidMatches.Count -eq 1) {
    # Only one diagram found - assume it's the process flow
    $flowImg = "<div style=`"text-align:center;margin:20px 0;`"><img src=`"$processFlowUrl`" alt=`"Migration Process Flow Diagram`" style=`"$imgStyle`" /></div>"
    $html = [regex]::Replace($html, $mermaidPattern, $flowImg)
    Write-Host "   [OK] Replaced 1 Mermaid diagram with image" -ForegroundColor Green
}
else {
    Write-Host "   [!] No Mermaid diagrams found" -ForegroundColor Yellow
}

# ============================================================
# SPLIT INTO SECTIONS FOR WEB PARTS
# ============================================================

Write-Host "`n>> Splitting into web part sections" -ForegroundColor Cyan

# Split by section divs - each becomes a separate web part
$sections = @()

# Extract each major section by id
$sectionIds = @(
    'header',      # The banner (no id, extract by style)
    'warning',     # 6-server warning
    'solutions',   # Two solutions comparison
    'toc',         # Table of contents
    'summary',     # Executive summary
    'process',     # Process flow
    'architecture',
    'prereqs',
    'setup',
    'apps',
    'config',
    'columns',
    'features',
    'scheduling',
    'tasks',
    'notifications',
    'pages',
    'scenarios',
    'logs',
    'troubleshoot',
    'security',
    'footer'
)

# For SharePoint, we'll deploy as fewer, larger sections to avoid web part limits
# Group related sections together

# Section groupings for deployment
$webParts = @()

# 1. Header + Warning + Solutions + TOC
$webParts += @{
    Name = "Header"
    Pattern = '(?s)^(.*?)(<!-- EXECUTIVE SUMMARY -->|<div[^>]*id="summary")'
    Content = ""
}

# The rest will be extracted by section id
$sectionPattern = '(?s)<div[^>]*id="([^"]+)"[^>]*>(.*?)</div>\s*(?=<div[^>]*id="|<!-- |<div[^>]*class="footer"|$)'

# Actually, let's just deploy the whole thing as one large text part
# SharePoint can handle it

$webParts = @($html)

Write-Host "   [OK] Prepared content for deployment" -ForegroundColor Green

# ============================================================
# PREVIEW MODE
# ============================================================

if ($PreviewOnly) {
    Write-Host "`n>> Preview Mode - outputting HTML" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Gray
    Write-Host $html
    Write-Host "=" * 60 -ForegroundColor Gray
    Write-Host "`n   Total length: $($html.Length) characters" -ForegroundColor Cyan
    exit 0
}

# ============================================================
# CONNECT TO SHAREPOINT
# ============================================================

Write-Host "`n>> Connecting to SharePoint" -ForegroundColor Cyan

try {
    Import-Module PnP.PowerShell -ErrorAction Stop
    
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
# VERIFY DIAGRAM IMAGES EXIST IN SITE ASSETS
# ============================================================

Write-Host "`n>> Verifying diagram images in Site Assets" -ForegroundColor Cyan
Write-Host "   Expected location: $siteUrl/$imageLibraryPath/" -ForegroundColor Gray
Write-Host "   - $($diagramImages.ProcessFlow)" -ForegroundColor Gray
Write-Host "   - $($diagramImages.Architecture)" -ForegroundColor Gray

$missingImages = @()
foreach ($imgName in $diagramImages.Values) {
    try {
        $imgFile = Get-PnPFile -Url "$imageLibraryPath/$imgName" -ErrorAction SilentlyContinue
        if ($imgFile) {
            Write-Host "   [OK] Found: $imgName" -ForegroundColor Green
        } else {
            $missingImages += $imgName
            Write-Host "   [!] Not found: $imgName" -ForegroundColor Yellow
        }
    }
    catch {
        $missingImages += $imgName
        Write-Host "   [!] Not found: $imgName" -ForegroundColor Yellow
    }
}

if ($missingImages.Count -gt 0) {
    Write-Host "`n   WARNING: Missing images will show as broken in the page." -ForegroundColor Yellow
    Write-Host "   Upload them to: $siteUrl/$imageLibraryPath/" -ForegroundColor Yellow
}

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

# Set page properties
Set-PnPPage -Identity $PageName -HeaderLayoutType NoImage -Title "Common Drive Migration - System Documentation"

# Add content as text web part
Write-Host "   Adding content..." -ForegroundColor Gray

# SharePoint has a limit on text part size, so we may need to split
# For now, try adding as single part
try {
    Add-PnPPageTextPart -Page $PageName -Text $html -Order 1 -ErrorAction Stop
    Write-Host "   [OK] Content added" -ForegroundColor Green
}
catch {
    Write-Host "   [!] Content too large for single web part, splitting..." -ForegroundColor Yellow
    
    # Split by section divs
    $sectionRegex = '(?s)(<div[^>]*style="[^"]*background:#ffffff[^"]*"[^>]*>.*?</div>)\s*(?=<div|$)'
    $sectionMatches = [regex]::Matches($html, $sectionRegex)
    
    $order = 1
    foreach ($match in $sectionMatches) {
        try {
            Add-PnPPageTextPart -Page $PageName -Text $match.Value -Order $order -ErrorAction Stop
            $order++
        }
        catch {
            Write-Host "   [!] Failed to add section $order : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host "   [OK] Added $($order - 1) sections" -ForegroundColor Green
}

# Publish the page
Set-PnPPage -Identity $PageName -Publish
Write-Host "   [OK] Page published" -ForegroundColor Green

# ============================================================
# DONE
# ============================================================

$pageUrl = "$siteUrl/SitePages/$PageName.aspx"
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   SYSTEM DOCUMENTATION DEPLOYED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n   Page URL: $pageUrl" -ForegroundColor White
Write-Host "`n   Diagram Images (embedded in page):" -ForegroundColor Cyan
Write-Host "   - $siteUrl/$imageLibraryPath/$($diagramImages.ProcessFlow)" -ForegroundColor Gray
Write-Host "   - $siteUrl/$imageLibraryPath/$($diagramImages.Architecture)" -ForegroundColor Gray
Write-Host "`n"

# Disconnect
Disconnect-PnPOnline -ErrorAction SilentlyContinue
