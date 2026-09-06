# Setup script to download Godot 4.3 portable engine
$ErrorActionPreference = "Stop"

$GodotVersion = "4.3-stable"
$GodotZipName = "Godot_v4.3-stable_win64.exe.zip"
$GodotUrl = "https://github.com/godotengine/godot/releases/download/$GodotVersion/$GodotZipName"
$BinDir = Join-Path $PSScriptRoot "..\bin"

if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
}

$GodotExe = Join-Path $BinDir "godot.exe"

if (-not (Test-Path $GodotExe)) {
    Write-Host "Downloading Godot 4.3 Windows x64..." -ForegroundColor Cyan
    $ZipPath = Join-Path $BinDir "godot.zip"
    curl.exe -L -o $ZipPath $GodotUrl
    
    Write-Host "Extracting Godot executable..." -ForegroundColor Cyan
    Expand-Archive -Path $ZipPath -DestinationPath $BinDir -Force
    Remove-Item $ZipPath -Force
    
    $ExtractedExe = Get-ChildItem $BinDir -Filter "Godot*.exe" | Select-Object -First 1
    if ($ExtractedExe) {
        Copy-Item $ExtractedExe.FullName -Destination $GodotExe -Force
        Write-Host "Godot installed successfully to $GodotExe" -ForegroundColor Green
    }
} else {
    Write-Host "Godot already installed at $GodotExe" -ForegroundColor Green
}

& $GodotExe --version
