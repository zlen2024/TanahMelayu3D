# Downloads and installs Godot 4.3 export templates
$ErrorActionPreference = "Stop"

$TemplatesDir = Join-Path $env:APPDATA "Godot\export_templates\4.3.stable"

if (Test-Path (Join-Path $TemplatesDir "web_nothreads_release.zip")) {
    Write-Host "Export templates already installed at $TemplatesDir" -ForegroundColor Green
    exit 0
}

Write-Host "Downloading Godot 4.3 Export Templates (~490MB)..." -ForegroundColor Cyan
$Url = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
$ZipPath = Join-Path $PSScriptRoot "..\bin\templates.zip"
$ExtractTemp = Join-Path $PSScriptRoot "..\bin\templates_extracted"

curl.exe -L -o $ZipPath $Url

Write-Host "Extracting export templates..." -ForegroundColor Cyan
if (Test-Path $ExtractTemp) { Remove-Item $ExtractTemp -Recurse -Force }
Expand-Archive -Path $ZipPath -DestinationPath $ExtractTemp -Force

if (-not (Test-Path $TemplatesDir)) {
    New-Item -ItemType Directory -Path $TemplatesDir -Force | Out-Null
}

Copy-Item "$ExtractTemp\templates\*" -Destination $TemplatesDir -Recurse -Force

Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
Remove-Item $ZipPath -Force
Remove-Item $ExtractTemp -Recurse -Force

Write-Host "Godot 4.3 export templates installed successfully to $TemplatesDir!" -ForegroundColor Green
Get-ChildItem $TemplatesDir -Filter "*web*"
