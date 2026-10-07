param([string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configuration = Join-Path $projectRoot 'config/supabase.local.json'
if (-not (Test-Path -LiteralPath $configuration)) { throw 'Create config/supabase.local.json from the example before running.' }
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { Join-Path $env:USERPROFILE 'flutter/bin/flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Flutter was not found. Add its bin folder to PATH.' }
Push-Location $projectRoot
try { & $flutterPath run -d $Device --dart-define-from-file=$configuration } finally { Pop-Location }
