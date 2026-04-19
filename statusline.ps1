[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$input_json = [Console]::In.ReadToEnd()
$data = $input_json | ConvertFrom-Json

$ESC = [char]27
function C { param([string]$code, [string]$text) "$ESC[${code}m$text$ESC[0m" }

function Format-Bar {
    param([double]$pct, [int]$width = 8)
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }
    $filled = [int][Math]::Round(($pct / 100.0) * $width)
    if ($filled -gt $width) { $filled = $width }
    $empty = $width - $filled
    return ("[" + ([string][char]0x2588 * $filled) + ([string][char]0x2591 * $empty) + "]")
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
if ($data.context_window) {
    $max = 200000
    if ($model_name -and $model_name -match "1M") { $max = 1000000 }

    $used = $null
    if ($data.context_window.current_usage) {
        $cu = $data.context_window.current_usage
        $sum = 0
        if ($cu.input_tokens) { $sum += [long]$cu.input_tokens }
        if ($cu.cache_creation_input_tokens) { $sum += [long]$cu.cache_creation_input_tokens }
        if ($cu.cache_read_input_tokens) { $sum += [long]$cu.cache_read_input_tokens }
        if ($sum -gt 0) { $used = $sum }
    }
    if ($used -eq $null -and $data.context_window.used_percentage -ne $null) {
        $used = [long]([double]$data.context_window.used_percentage / 100.0 * $max)
    }

    if ($used -ne $null) {
        $label = "ctx " + (Format-Tokens $used) + "/" + (Format-Tokens $max)
        $parts += (C "32" $label)
    }
}

# 5-hour rate limit (blue)
if ($data.rate_limits -and $data.rate_limits.five_hour -and $data.rate_limits.five_hour.used_percentage -ne $null) {
    $pct = [double]$data.rate_limits.five_hour.used_percentage
    $seg = "5h " + (Format-Bar $pct 8) + (" {0,3:N0}%" -f $pct)
    $reset = Format-ResetTime $data.rate_limits.five_hour.resets_at
    if ($reset) { $seg += " (" + $reset + ")" }
    $parts += (C "34" $seg)
}

# weekly rate limit (orange)
if ($data.rate_limits -and $data.rate_limits.seven_day -and $data.rate_limits.seven_day.used_percentage -ne $null) {
    $pct = [double]$data.rate_limits.seven_day.used_percentage
    $seg = "wk " + (Format-Bar $pct 8) + (" {0,3:N0}%" -f $pct)
    $reset = Format-ResetTime $data.rate_limits.seven_day.resets_at
    if ($reset) { $seg += " (" + $reset + ")" }
    $parts += (C "38;5;208" $seg)
}

$sep = C "90" "|"
[Console]::Out.Write(($parts -join " $sep "))
