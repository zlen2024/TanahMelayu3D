# Comprehensive Automated Test Runner
# Runs both Godot Engine game mechanics tests and Node.js multiplayer network tests.
$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$GodotExe = Join-Path $ProjectRoot "bin\Godot_v4.3-stable_win64_console.exe"

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "RUNNING FULL RPG POC AUTOMATED TEST SUITE" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Godot Game Systems Test (Chat, Map, Hit, Attack, Monster Death Fix, Leveling)
Write-Host "[1/3] Running Godot 4 Game Mechanics Tests..." -ForegroundColor Yellow
& $GodotExe --headless res://tests/test_runner.tscn
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot Game Mechanics Tests failed!"
    exit 1
}

# 2. Server and WebSocket Network Integration Test
Write-Host ""
Write-Host "[2/3] Running Multiplayer Network Integration Tests..." -ForegroundColor Yellow
node (Join-Path $ProjectRoot "tests/test_server_network.js")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Multiplayer Network Tests failed!"
    exit 1
}

# 3. Database attribute-point logic (level grants, backfill, allocation)
Write-Host ""
Write-Host "[3/3] Running Database Attribute-Point Tests..." -ForegroundColor Yellow
node (Join-Path $ProjectRoot "tests/test_db_stats.js")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Database Attribute-Point Tests failed!"
    exit 1
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "ALL AUTOMATED TESTS (ENGINE AND MULTIPLAYER) PASSED!" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host ""
