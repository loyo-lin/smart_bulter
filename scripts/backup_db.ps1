$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$backupDir = Join-Path $projectRoot "backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not (Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$dbFiles = @(
    "chat_history.db",
    "smart_butler.db"
)

foreach ($db in $dbFiles) {
    $src = Join-Path $projectRoot $db
    if (Test-Path -LiteralPath $src) {
        $dest = Join-Path $backupDir ("{0}.{1}.bak" -f $db, $timestamp)
        Copy-Item -LiteralPath $src -Destination $dest -Force
        Write-Output "Backup created: $dest"
    }
}

