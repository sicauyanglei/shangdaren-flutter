param(
    [string]$Filter = "SDR",
    [string]$Level = "ALL",
    [switch]$SaveToFile,
    [switch]$NoColor,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
========================================
  上大人游戏 - BlueStacks 日志监听工具
========================================
用法: .\monitor-logs.ps1 [参数]

参数:
  -Filter <tag>    过滤标签 (默认: SDR，即所有游戏日志)
                   可选: ZHAO, PENG, CHI, HU, TURN, RESP, BTN, STATE, ERROR
  -Level <level>   日志级别过滤 (默认: ALL)
                   可选: ERROR, WARN, INFO, DEBUG, ALL
  -SaveToFile      同时保存日志到文件 (logs/目录下)
  -NoColor         禁用颜色输出
  -Help            显示此帮助信息

示例:
  .\monitor-logs.ps1                    # 监听所有游戏日志
  .\monitor-logs.ps1 -Filter ZHAO       # 只看招牌相关日志
  .\monitor-logs.ps1 -Level ERROR       # 只看错误日志
  .\monitor-logs.ps1 -SaveToFile        # 监听并保存到文件
  .\monitor-logs.ps1 -Filter RESP       # 只看响应按钮相关日志

快捷键:
  Ctrl+C  停止监听
"@
    exit 0
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  上大人游戏 - BlueStacks 日志监听" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$adb = "adb"
$device = $null

$devs = & $adb devices 2>&1 | Select-String "device$"
if ($devs) {
    $device = ($devs[0].ToString() -split "\s+")[0]
    Write-Host "[OK] 已连接设备: $device" -ForegroundColor Green
} else {
    Write-Host "[INFO] 未检测到ADB设备，尝试启动BlueStacks..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\BlueStacks_nxt\HD-Player.exe" -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 2
        & $adb connect localhost:5555 2>&1 | Out-Null
        $devs = & $adb devices 2>&1 | Select-String "device$"
        if ($devs) { $device = ($devs[0].ToString() -split "\s+")[0]; break }
    }
    if (-not $device) {
        Write-Host "[FAIL] 无法连接BlueStacks，请手动启动后重试" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] 已连接: $device" -ForegroundColor Green
}

$logDir = Join-Path $PSScriptRoot "logs"
if ($SaveToFile -and -not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = $null
if ($SaveToFile) {
    $logFile = Join-Path $logDir "game_$timestamp.log"
    Write-Host "[OK] 日志将保存到: $logFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "过滤标签: $Filter" -ForegroundColor Yellow
Write-Host "日志级别: $Level" -ForegroundColor Yellow
Write-Host "按 Ctrl+C 停止监听" -ForegroundColor DarkGray
Write-Host "----------------------------------------" -ForegroundColor DarkGray

& $adb -s $device logcat -c 2>&1 | Out-Null

$levelOrder = @{ ERROR = 0; WARN = 1; INFO = 2; DEBUG = 3; ALL = 4 }
$maxLevel = if ($Level -ne "ALL") { $levelOrder[$Level] } else { 4 }

function Write-ColorLog {
    param([string]$Line, [string]$LevelStr)
    
    if ($NoColor) {
        Write-Host $Line
        return
    }
    
    switch ($LevelStr) {
        "ERROR" { Write-Host $Line -ForegroundColor Red }
        "WARN"  { Write-Host $Line -ForegroundColor Yellow }
        "INFO"  { Write-Host $Line -ForegroundColor White }
        "DEBUG" { Write-Host $Line -ForegroundColor DarkGray }
        default { Write-Host $Line }
    }
}

try {
    & $adb -s $device logcat -v time 2>&1 | ForEach-Object {
        $line = $_.ToString()
        
        if ($line -match '\[SDR:(\w+)\]\s+(.*)') {
            $logLevel = $Matches[1]
            $logMsg = $Matches[2]
            
            $lineLevel = $levelOrder[$logLevel]
            if ($null -eq $lineLevel) { $lineLevel = 2 }
            
            if ($lineLevel -gt $maxLevel) { return }
            
            if ($Filter -ne "SDR" -and $Filter -ne "ALL") {
                if ($logMsg -notmatch "\[$Filter\]") { return }
            }
            
            $timeStr = Get-Date -Format "HH:mm:ss"
            $formatted = "[$timeStr] [SDR:$logLevel] $logMsg"
            
            Write-ColorLog -Line $formatted -LevelStr $logLevel
            
            if ($SaveToFile -and $logFile) {
                Add-Content -Path $logFile -Value $formatted -Encoding UTF8
            }
        }
        elseif ($line -match 'FATAL|AndroidRuntime.*FATAL') {
            $timeStr = Get-Date -Format "HH:mm:ss"
            $formatted = "[$timeStr] [CRASH] $line"
            Write-Host $formatted -ForegroundColor Red -BackgroundColor DarkRed
            if ($SaveToFile -and $logFile) {
                Add-Content -Path $logFile -Value $formatted -Encoding UTF8
            }
        }
    }
}
finally {
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "日志监听已停止" -ForegroundColor Yellow
    if ($SaveToFile -and $logFile -and (Test-Path $logFile)) {
        Write-Host "日志已保存到: $logFile" -ForegroundColor Green
    }
}
