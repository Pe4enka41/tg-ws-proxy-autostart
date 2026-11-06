param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'TgWsProxyAuto'),
    [string]$StartupDir = [Environment]::GetFolderPath('Startup'),
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$kitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$proxySource = Join-Path $kitDir 'TgWsProxy_windows.exe'
$watchSource = Join-Path $kitDir 'watch.ps1'
$proxyDest = Join-Path $InstallDir 'TgWsProxy_windows.exe'
$watchDest = Join-Path $InstallDir 'watch.ps1'
$startupFile = Join-Path $StartupDir 'TgWsProxy-Auto.vbs'
$downloadedProxy = $null

function Download-OfficialProxy {
    $isArm = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') -or ($env:PROCESSOR_ARCHITEW6432 -eq 'ARM64')
    $assetName = if ($isArm) { 'TgWsProxy_windows_arm64.exe' } else { 'TgWsProxy_windows.exe' }
    $url = "https://github.com/Flowseal/tg-ws-proxy/releases/latest/download/$assetName"

    Write-Host "Скачиваю официальную версию прокси ($assetName) с GitHub..." -ForegroundColor Cyan
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
        if ((Get-Item -LiteralPath $tempFile).Length -lt 5MB) {
            throw 'Скачанный файл повреждён или слишком маленький.'
        }
        Write-Host 'Скачивание завершено.' -ForegroundColor Green
        return $tempFile
    }
    catch {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        throw
    }
}

Write-Host ''
Write-Host '=== TG WS Proxy: автозапуск вместе с Telegram ===' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path -LiteralPath $watchSource)) {
    throw 'Не найден watch.ps1 рядом с установщиком. Распакуйте архив полностью.'
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $StartupDir | Out-Null

# Find the proxy: bundled exe -> already installed exe -> download official build.
if (-not (Test-Path -LiteralPath $proxySource)) {
    if (Test-Path -LiteralPath $proxyDest) {
        $proxySource = $proxyDest
    }
    else {
        try {
            $downloadedProxy = Download-OfficialProxy
            $proxySource = $downloadedProxy
        }
        catch {
            throw "Не удалось скачать прокси. Проверьте интернет или скачайте вручную: https://github.com/Flowseal/tg-ws-proxy/releases`n$($_.Exception.Message)"
        }
    }
}

# Stop the old watcher and proxy before replacing files.
if (-not $NoStart) {
    $oldWatchers = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like "*$InstallDir*watch.ps1*" })
    foreach ($process in $oldWatchers) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Get-Process -Name TgWsProxy_windows -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

if ($proxySource -ne $proxyDest) {
    Copy-Item -LiteralPath $proxySource -Destination $proxyDest -Force
}
if ($downloadedProxy) {
    Remove-Item -LiteralPath $downloadedProxy -Force -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath $watchSource -Destination $watchDest -Force

# The VBS file in the Startup folder starts the watcher hidden at logon.
$vbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$watchDest""", 0, False
"@
[System.IO.File]::WriteAllText($startupFile, $vbs, [System.Text.Encoding]::Unicode)

if (-not $NoStart) {
    Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$startupFile`"" -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

Write-Host 'Готово!' -ForegroundColor Green
Write-Host ''
Write-Host "Прокси установлен: $proxyDest"
Write-Host "Сторож установлен: $watchDest"
Write-Host "Автозапуск: $startupFile"
Write-Host "Лог: $(Join-Path $InstallDir 'watch.log')"
Write-Host ''
Write-Host 'Что дальше:'
Write-Host '  1. Запустите Telegram как обычно - прокси стартует автоматически.'
Write-Host '  2. Значок TgWsProxy в трее -> "Открыть в Telegram" (настроить прокси один раз).'
Write-Host '  3. Чтобы прокси закрылся, выйдите из Telegram полностью: трей -> Выйти.'
Write-Host ''
