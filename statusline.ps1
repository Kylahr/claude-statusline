[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$input_json = [Console]::In.ReadToEnd()
$data = $input_json | ConvertFrom-Json

$ESC = [char]27
function C { param([string]$code, [string]$text) "$ESC[${code}m$text$ESC[0m" }

function Strip-Ansi([string]$s) {
    return $s -replace "$ESC\[[0-9;]*m", ''
}

function Get-WindowWidth {
    if ($env:CLAUDE_STATUSLINE_WIDTH) {
        $w = 0
        if ([int]::TryParse($env:CLAUDE_STATUSLINE_WIDTH, [ref]$w) -and $w -gt 0) { return $w }
    }
    try {
        $w = [Console]::WindowWidth
        if ($w -gt 0) { return $w }
    } catch { }
    try {
        $w = $Host.UI.RawUI.WindowSize.Width
        if ($w -gt 0) { return $w }
    } catch { }
    return 120
}

function Format-Bar {
    param([double]$pct, [int]$width = 8)
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }
    $filled = [int][Math]::Round(($pct / 100.0) * $width)
    if ($filled -gt $width) { $filled = $width }
    $empty = $width - $filled
    return ("[" + ([string][char]0x2588 * $filled) + (" " * $empty) + "]")
}

function Format-ResetTime {
    param($epoch)
    if (-not $epoch) { return $null }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $diff = [long]$epoch - $now
    if ($diff -le 0) { return "now" }
    $h = [int][Math]::Floor($diff / 3600)
    $m = [int][Math]::Floor(($diff % 3600) / 60)
    if ($h -ge 24) {
        $d = [int][Math]::Floor($h / 24)
        $h = $h % 24
        return "${d}d${h}h"
    }
    return "${h}h${m}m"
}

function Format-Tokens {
    param([long]$n)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($n -ge 1000000) {
        return (($n / 1000000.0).ToString("N1", $inv) + "M")
    } elseif ($n -ge 1000) {
        return (($n / 1000.0).ToString("N0", $inv) + "k")
    }
    return "$n"
}

function Format-Duration {
    param([long]$ms)
    if ($ms -le 0) { return "0s" }
    $sec = [long][Math]::Floor($ms / 1000)
    if ($sec -lt 60) { return "${sec}s" }
    $m = [long][Math]::Floor($sec / 60)
    $s = $sec % 60
    if ($m -lt 60) { return "${m}m${s}s" }
    $h = [long][Math]::Floor($m / 60)
    $m = $m % 60
    if ($h -lt 24) { return "${h}h${m}m" }
    $d = [long][Math]::Floor($h / 24)
    $h = $h % 24
    return "${d}d${h}h"
}

$parts = @()

# cwd (cyan)
$cwd = $null
if ($data.cwd) { $cwd = $data.cwd }
elseif ($data.workspace -and $data.workspace.current_dir) { $cwd = $data.workspace.current_dir }
if ($cwd) {
    $home_path = $HOME -replace '\\', '/'
    $cwd_norm  = $cwd  -replace '\\', '/'
    $short = $cwd_norm -replace ('^' + [regex]::Escape($home_path)), '~'
    $parts += (C "36" $short)
}

# git branch (magenta)
if ($cwd -and (Test-Path $cwd)) {
    Push-Location $cwd
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    Pop-Location
    if ($LASTEXITCODE -eq 0 -and $branch) { $parts += (C "35" $branch) }
}

# model (yellow)
$model_name = $null
if ($data.model -and $data.model.display_name) {
    $model_name = $data.model.display_name
    $parts += (C "33" $model_name)
}

# context tokens used / max (green)
$used_input = $null
if ($data.context_window) {
    $max = 200000
    if ($data.context_window.context_window_size) {
        $max = [long]$data.context_window.context_window_size
    } elseif ($model_name -and $model_name -match "1M") {
        $max = 1000000
    }

    if ($data.context_window.current_usage) {
        $cu = $data.context_window.current_usage
        $sum = 0
        if ($cu.input_tokens) { $sum += [long]$cu.input_tokens }
        if ($cu.cache_creation_input_tokens) { $sum += [long]$cu.cache_creation_input_tokens }
        if ($cu.cache_read_input_tokens) { $sum += [long]$cu.cache_read_input_tokens }
        if ($sum -gt 0) { $used_input = $sum }
    }
    if ($used_input -eq $null -and $data.context_window.used_percentage -ne $null) {
        $used_input = [long]([double]$data.context_window.used_percentage / 100.0 * $max)
    }

    if ($used_input -ne $null) {
        $label = "ctx " + (Format-Tokens $used_input) + "/" + (Format-Tokens $max)
        $parts += (C "32" $label)
    }
}

# session timer (bright white)
if ($data.cost -and $data.cost.total_duration_ms -ne $null) {
    $dur = Format-Duration ([long]$data.cost.total_duration_ms)
    $parts += (C "97" ("Session: " + $dur))
}

# 5-hour rate limit (blue)
if ($data.rate_limits -and $data.rate_limits.five_hour -and $data.rate_limits.five_hour.used_percentage -ne $null) {
    $pct = [double]$data.rate_limits.five_hour.used_percentage
    $seg = "5h " + (Format-Bar $pct 8) + (" {0,3:N0}%" -f $pct)
    $reset = Format-ResetTime $data.rate_limits.five_hour.resets_at
    if ($reset) { $seg += " (" + $reset + ")" }
    $parts += (C "38;5;141" $seg)
}

# weekly rate limit (orange)
if ($data.rate_limits -and $data.rate_limits.seven_day -and $data.rate_limits.seven_day.used_percentage -ne $null) {
    $pct = [double]$data.rate_limits.seven_day.used_percentage
    $seg = "wk " + (Format-Bar $pct 8) + (" {0,3:N0}%" -f $pct)
    $reset = Format-ResetTime $data.rate_limits.seven_day.resets_at
    if ($reset) { $seg += " (" + $reset + ")" }
    $parts += (C "38;5;208" $seg)
}

# Pack segments into rows that fit in the terminal width
$width = Get-WindowWidth
$sepPlain = " | "
$sepLen = $sepPlain.Length

$rows = [System.Collections.ArrayList]@()
$currentRow = [System.Collections.ArrayList]@()
$currentLen = 0

foreach ($p in $parts) {
    $pLen = (Strip-Ansi $p).Length
    $addLen = if ($currentRow.Count -eq 0) { $pLen } else { $pLen + $sepLen }
    if ($currentRow.Count -gt 0 -and ($currentLen + $addLen) -gt $width) {
        [void]$rows.Add($currentRow)
        $currentRow = [System.Collections.ArrayList]@()
        $currentLen = 0
        $addLen = $pLen
    }
    [void]$currentRow.Add($p)
    $currentLen += $addLen
}
if ($currentRow.Count -gt 0) { [void]$rows.Add($currentRow) }

$sep = C "90" "|"
$lines = @()
foreach ($row in $rows) {
    $lines += ($row -join " $sep ")
}
[Console]::Out.Write($lines -join "`n")
