param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'TgWsProxyAuto')
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$startupFile = Join-Path ([Environment]::GetFolderPath('Startup')) 'TgWsProxy-Auto.vbs'

Write-Host ''
Write-Host '=== Удаление TG WS Proxy Auto ===' -ForegroundColor Cyan

$watchers = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -like "*$InstallDir*watch.ps1*" })
foreach ($process in $watchers) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}
Get-Process -Name TgWsProxy_windows -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Remove-Item -LiteralPath $startupFile -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue

if ((Test-Path -LiteralPath $startupFile) -or (Test-Path -LiteralPath $InstallDir)) {
    Write-Host 'Не удалось удалить всё. Закройте Telegram и запустите uninstall.cmd ещё раз.' -ForegroundColor Yellow
}
else {
    Write-Host 'Готово: автозапуск и файлы удалены.' -ForegroundColor Green
}
Write-Host ''
