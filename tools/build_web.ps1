# Build script to export Godot 4 Web project to dist/
$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$BinDir = Join-Path $ProjectRoot "bin"
$DistDir = Join-Path $ProjectRoot "dist"
$GodotExe = Join-Path $BinDir "Godot_v4.3-stable_win64_console.exe"

# 1. Check Godot binary
if (-not (Test-Path $GodotExe)) {
    Write-Host "Godot binary missing. Running setup_godot.ps1..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "setup_godot.ps1")
}

# 2. Check export templates
$TemplatesDir = Join-Path $env:APPDATA "Godot\export_templates\4.3.stable"
if (-not (Test-Path (Join-Path $TemplatesDir "web_nothreads_release.zip"))) {
    Write-Host "Export templates missing. Running setup_templates.ps1..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "setup_templates.ps1")
}

# 3. Clean and prepare dist directory
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$OutputHtml = Join-Path $DistDir "index.html"

Write-Host "Exporting Godot project to Web ($OutputHtml)..." -ForegroundColor Cyan
& $GodotExe --headless --export-release "Web" $OutputHtml

if (Test-Path $OutputHtml) {
    Write-Host "Web build succeeded!" -ForegroundColor Green
    
    # Create itch.io ready zip
    $ItchZip = Join-Path $ProjectRoot "dist/godot_web_rpg_itch.zip"
    if (Test-Path $ItchZip) { Remove-Item $ItchZip -Force }
    Compress-Archive -Path "$DistDir\*" -DestinationPath $ItchZip -Force
    Write-Host "Created itch.io deployment zip: $ItchZip" -ForegroundColor Green
    
    Get-ChildItem $DistDir
} else {
    Write-Error "Web export failed! index.html was not generated."
}
