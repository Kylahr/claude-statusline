#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Repo   = 'Kylahr/claude-statusline'
$Branch = 'main'
$StatuslineUrl = "https://raw.githubusercontent.com/$Repo/$Branch/statusline.ps1"

$claudeDir    = Join-Path $HOME '.claude'
$targetPs1    = Join-Path $claudeDir 'statusline-command.ps1'
$settingsPath = Join-Path $claudeDir 'settings.json'

if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

Write-Host "Downloading statusline -> $targetPs1"
Invoke-WebRequest -Uri $StatuslineUrl -OutFile $targetPs1 -UseBasicParsing

$forwardSlashPath = $targetPs1 -replace '\\', '/'
$statusLineCfg = [pscustomobject]@{
    type    = 'command'
    command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$forwardSlashPath`""
}

if (Test-Path $settingsPath) {
    $raw = Get-Content $settingsPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $settings = [pscustomobject]@{}
    } else {
        $settings = $raw | ConvertFrom-Json
    }
} else {
    $settings = [pscustomobject]@{}
}

if ($settings.PSObject.Properties.Name -contains 'statusLine') {
    $settings.statusLine = $statusLineCfg
} else {
    $settings | Add-Member -MemberType NoteProperty -Name statusLine -Value $statusLineCfg
}

Write-Host "Writing $settingsPath"
$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

Write-Host ""
Write-Host "Installed. Restart Claude Code to see the new statusline."
