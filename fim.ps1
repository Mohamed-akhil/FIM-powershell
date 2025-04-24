# === CONFIGURATION ===
$basePath = "C:\Users\USER\FIM"
$folderPath = "$basePath\files"
$logFolder = "$basePath\logs"
$logFile = "$logFolder\FIM-Log-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$hashTablePath = "$folderPath\hashes.txt"

# === Ensure Necessary Folders Exist ===
foreach ($path in @($folderPath, $logFolder)) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

# === Helper: Write to Log and Console ===
function Write-Log {
    param($message, $color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    $logEntry | Tee-Object -FilePath $logFile -Append
    Write-Host $logEntry -ForegroundColor $color
}

# === Calculate File Hashes (excluding hashes.txt) ===
function Get-FileHashTable {
    $hashTable = @{}
    Get-ChildItem -Path $folderPath -Recurse -File | Where-Object {
        $_.Name -ne "hashes.txt"
    } | ForEach-Object {
        try {
            $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
            $hashTable[$_.FullName] = $hash.Hash
        } catch {
            Write-Log "ERROR hashing file: $_.FullName" "Red"
        }
    }
    return $hashTable
}

# === Load Stored Hashes ===
function Load-StoredHashes {
    $storedHashes = @{}
    if (Test-Path $hashTablePath) {
        Get-Content $hashTablePath | ForEach-Object {
            $line = $_.Split("|")
            if ($line.Count -eq 2) {
                $storedHashes[$line[0]] = $line[1]
            }
        }
    }
    return $storedHashes
}

# === Save Hashes ===
function Save-Hashes {
    param($hashTable)
    $lines = $hashTable.GetEnumerator() | ForEach-Object {
        "$($_.Key)|$($_.Value)"
    }
    $lines | Set-Content -Path $hashTablePath
}

# === Compare Hashes ===
function Compare-Hashes {
    $currentHashes = Get-FileHashTable
    $storedHashes = Load-StoredHashes
    $changes = @()

    foreach ($file in $currentHashes.Keys) {
        if ($storedHashes.ContainsKey($file)) {
            if ($currentHashes[$file] -ne $storedHashes[$file]) {
                $changes += @{ Type = "MODIFIED"; Path = $file }
            }
        } else {
            $changes += @{ Type = "NEW"; Path = $file }
        }
    }

    foreach ($file in $storedHashes.Keys) {
        if (-not $currentHashes.ContainsKey($file)) {
            $changes += @{ Type = "DELETED"; Path = $file }
        }
    }

    return $changes, $currentHashes
}

# === FILES FOLDER MONITORING ===

$filesWatcher = New-Object System.IO.FileSystemWatcher
$filesWatcher.Path = $folderPath
$filesWatcher.IncludeSubdirectories = $true
$filesWatcher.EnableRaisingEvents = $true
$filesWatcher.Filter = "*.*"

$filesAction = {
    $changedFile = $Event.SourceEventArgs.FullPath
    $fileName = [System.IO.Path]::GetFileName($changedFile)

    # Skip hashes.txt (self-generated)
    if ($fileName -eq "hashes.txt") {
        return
    }

    Write-Log "Change detected in FILES: $($Event.SourceEventArgs.ChangeType) - $changedFile" "Cyan"

    $result = Compare-Hashes
    $changes = $result[0]
    $currentHashes = $result[1]

    if ($changes.Count -gt 0) {
        Write-Log "Integrity violations:" "Magenta"
        foreach ($change in $changes) {
            switch ($change.Type) {
                "NEW"      { Write-Log "NEW FILE: $($change.Path)" "Green" }
                "MODIFIED" { Write-Log "MODIFIED: $($change.Path)" "Yellow" }
                "DELETED"  { Write-Log "DELETED: $($change.Path)" "Red" }
            }
        }

        Save-Hashes -hashTable $currentHashes
    }
}

Register-ObjectEvent $filesWatcher "Changed" -Action $filesAction | Out-Null
Register-ObjectEvent $filesWatcher "Created" -Action $filesAction | Out-Null
Register-ObjectEvent $filesWatcher "Deleted" -Action $filesAction | Out-Null
Register-ObjectEvent $filesWatcher "Renamed" -Action $filesAction | Out-Null

# === LOG FOLDER MONITORING ===

$logsWatcher = New-Object System.IO.FileSystemWatcher
$logsWatcher.Path = $logFolder
$logsWatcher.IncludeSubdirectories = $false
$logsWatcher.EnableRaisingEvents = $true
$logsWatcher.Filter = "*.log"

$logsAction = {
    $changeType = $Event.SourceEventArgs.ChangeType
    $logChanged = $Event.SourceEventArgs.FullPath

    # Ignore changes to the currently active log file
    if ($logChanged -eq $logFile -and $changeType -eq "Changed") {
        return
    }

    # Alert only if an existing log file is modified or deleted (excluding the current log file)
    if ($changeType -eq "Changed" -or $changeType -eq "Deleted") {
        Write-Log "ALERT: Existing log file $changeType - $logChanged" "Red"
    }
}

Register-ObjectEvent $logsWatcher "Changed" -Action $logsAction | Out-Null
Register-ObjectEvent $logsWatcher "Deleted" -Action $logsAction | Out-Null

# === Start Monitoring ===
Write-Log "File Integrity Monitoring started. Watching: $folderPath and logs at $logFolder" "Cyan"

# Keep alive
while ($true) {
    Start-Sleep -Seconds 1
}

