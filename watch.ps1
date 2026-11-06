# Keeps TG WS Proxy running only while Telegram Desktop is running.
# Installed to %LOCALAPPDATA%\TgWsProxyAuto and started at logon by TgWsProxy-Auto.vbs.

param(
    [string]$MutexName = 'Local\TgWsProxyAutoWatch'
)

$ErrorActionPreference = 'SilentlyContinue'
$pollSeconds = 1
$closeGraceSeconds = 3

$scriptDir = $PSScriptRoot
$logPath = Join-Path $scriptDir 'watch.log'
$telegramProcessName = 'Telegram'
$proxyProcessName = 'TgWsProxy_windows'
$proxyExe = Join-Path $scriptDir 'TgWsProxy_windows.exe'

# Single instance per user session.
$mutex = New-Object System.Threading.Mutex($false, $MutexName)
if (-not $mutex.WaitOne(0)) {
    exit 0
}

function Write-WatchLog {
    param([string]$Message)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    $item = Get-Item -LiteralPath $logPath
    if ($item -and $item.Length -gt 262144) {
        $tail = Get-Content -LiteralPath $logPath -Tail 500
        Set-Content -LiteralPath $logPath -Value $tail -Encoding UTF8
    }
}

function Test-Running {
    param([string]$Name)
    return [bool](Get-Process -Name $Name -ErrorAction SilentlyContinue)
}

function Start-Proxy {
    Start-Process -FilePath $script:proxyExe -WorkingDirectory $script:scriptDir
    Write-WatchLog 'Telegram started -> TgWsProxy launched.'
}

function Stop-Proxy {
    param([string]$Reason)
    $processes = @(Get-Process -Name $proxyProcessName -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return
    }
    foreach ($process in $processes) {
        $null = $process.CloseMainWindow()
    }
    Start-Sleep -Seconds 2
    $stillRunning = @(Get-Process -Name $proxyProcessName -ErrorAction SilentlyContinue)
    if ($stillRunning.Count -gt 0) {
        $stillRunning | Stop-Process -Force
    }
    Write-WatchLog "TgWsProxy stopped ($Reason)."
}

if (-not (Test-Path -LiteralPath $proxyExe)) {
    Write-WatchLog "ERROR: $proxyExe not found. Watcher exiting."
    $mutex.ReleaseMutex()
    exit 1
}

Write-WatchLog "Watcher started (proxy: $proxyExe)."

if (Test-Running $telegramProcessName) {
    if (-not (Test-Running $proxyProcessName)) {
        Start-Proxy
    }
}

while ($true) {
    if (Test-Running $telegramProcessName) {
        if (-not (Test-Running $proxyProcessName)) {
            Start-Proxy
        }
    }
    else {
        if (Test-Running $proxyProcessName) {
            # Short grace period so a quick Telegram restart/update
            # does not tear the proxy down.
            Start-Sleep -Seconds $closeGraceSeconds
            if (-not (Test-Running $telegramProcessName)) {
                Stop-Proxy 'Telegram exited'
            }
        }
    }
    Start-Sleep -Seconds $pollSeconds
}
