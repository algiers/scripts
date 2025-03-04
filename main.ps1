# main.ps1

# --- Configuration ---
$repoBaseUrl = "https://raw.githubusercontent.com/algiers/scripts/main"
$scriptsLocalPath = "$env:TEMP\ChifaPlusScripts"
$ErrorActionPreference = "Stop"

# --- Helper Functions ---
function Get-ScriptsList {
    try {
        # Get the list of available scripts from the repository
        $readmeUrl = "$repoBaseUrl/README.md"
        $readme = Invoke-WebRequest -Uri $readmeUrl -UseBasicParsing -ErrorAction Stop
        
        # Extract script names from README.md (assuming they're listed with .ps1 extension)
        $scriptNames = [regex]::Matches($readme.Content, '\b[\w-]+\.ps1\b') | 
                      Where-Object { $_.Value -ne "main.ps1" } | 
                      ForEach-Object { $_.Value } | 
                      Sort-Object -Unique
        
        return $scriptNames
    }
    catch {
        Write-Host "Failed to retrieve scripts list: $($_.Exception.Message)" -ForegroundColor Red
        # Fallback to a basic list if we can't get it from README
        return @("diagnosticUSB.ps1")
    }
}

function Update-Scripts {
    Write-Host "Downloading scripts from GitHub repository..." -ForegroundColor Cyan
    
    # Create scripts directory if it doesn't exist
    if (-not (Test-Path $scriptsLocalPath)) {
        New-Item -ItemType Directory -Path $scriptsLocalPath -Force | Out-Null
        Write-Host "Created scripts directory at $scriptsLocalPath" -ForegroundColor Yellow
    }

    try {
        # Close any open file handles in the scripts directory to prevent file locking issues
        if (Test-Path $scriptsLocalPath) {
            Write-Host "Preparing files for update..." -ForegroundColor Yellow
            # Force garbage collection to release any file handles
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
        
        # Get list of scripts to download
        $scriptsList = Get-ScriptsList
        
        # Always include main.ps1 in the download list
        if ($scriptsList -notcontains "main.ps1") {
            $scriptsList += "main.ps1"
        }
        
        # Download each script
        $updatedCount = 0
        foreach ($scriptName in $scriptsList) {
            $scriptUrl = "$repoBaseUrl/$scriptName"
            $localPath = Join-Path $scriptsLocalPath $scriptName
            
            Write-Host "Downloading $scriptName..." -ForegroundColor Yellow
            try {
                # Download the script
                Invoke-WebRequest -Uri $scriptUrl -OutFile $localPath -UseBasicParsing -ErrorAction Stop
                $updatedCount++
            }
            catch {
                Write-Host "Failed to download $scriptName: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Also download README.md for reference
        try {
            $readmeUrl = "$repoBaseUrl/README.md"
            $readmePath = Join-Path $scriptsLocalPath "README.md"
            Invoke-WebRequest -Uri $readmeUrl -OutFile $readmePath -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to download README.md: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        if ($updatedCount -gt 0) {
            Write-Host "$updatedCount scripts were downloaded or updated." -ForegroundColor Green
        }
        else {
            Write-Host "No scripts were updated. Check your internet connection." -ForegroundColor Red
        }
        
        Write-Host "Scripts update completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to update scripts: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Full error details: $($_)" -ForegroundColor Yellow
    }
}

# --- Menu Functions ---
function Show-ScriptMenu {
    param (
        [array]$scripts
    )
    
    Clear-Host
    Write-Host "=== Available Scripts ===" -ForegroundColor Cyan
    Write-Host "Q. Quit"
    Write-Host "U. Update Scripts"
    Write-Host ""
    
    $i = 1
    foreach($script in $scripts){
        Write-Host "$i. $script"
        $i++
    }
    Write-Host ""
}

# --- Initial Update ---
Update-Scripts

# --- Interactive Menu ---
do {
    $availableScripts = Get-ChildItem -Path "$scriptsLocalPath" -Filter "*.ps1" | 
                        Where-Object { $_.Name -ne "main.ps1" } | 
                        Select-Object -ExpandProperty FullName
    
    # Ensure we have valid script paths
    $availableScripts = $availableScripts | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }

    if ($availableScripts.Count -eq 0) {
        Write-Host "No scripts available. Please update the scripts using option 'U'." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        continue
    }

    $scriptNames = $availableScripts | ForEach-Object { Split-Path $_ -Leaf }
    Show-ScriptMenu $scriptNames

    try {
        $choice = Read-Host "Enter script number (Q to quit, U to update)"
        
        switch ($choice.ToLower()) {
            'q' { 
                Write-Host "Goodbye!"
                exit 
            }
            'u' { 
                Update-Scripts
                continue 
            }
            default {
                if ([int]::TryParse($choice, [ref]$null)) {
                    $choiceNum = [int]$choice
                    if ($choiceNum -ge 1 -and $choiceNum -le $availableScripts.Count) {
                        # Ensure we're getting a valid path from the array
                        if ($availableScripts -is [array]) {
                            $scriptPath = $availableScripts[$choiceNum - 1]
                        } else {
                            # Handle case where $availableScripts is not an array
                            $scriptPath = $availableScripts
                        }
                        
                        # Ensure the path is a string and not empty
                        if ([string]::IsNullOrEmpty($scriptPath)) {
                            Write-Host "Error: Invalid script path selected." -ForegroundColor Red
                            continue
                        }

                        # Enhanced path validation and error logging
                        Write-Host "Debug - Script path: $scriptPath" -ForegroundColor Gray
                        
                        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                            Write-Host "Script not found: $scriptPath" -ForegroundColor Red
                            Write-Host "Directory exists: $(Test-Path -LiteralPath (Split-Path $scriptPath -Parent))" -ForegroundColor Gray
                            continue
                        }

                        Write-Host "Executing: $(Split-Path $scriptPath -Leaf)" -ForegroundColor Cyan
                        $arguments = Read-Host "Enter script arguments (e.g., -Param1 Value1), or press Enter to run without arguments"

                        # Use more robust path handling with quotes
                        $scriptPathQuoted = """$scriptPath"""
                        
                        try {
                            # Use direct script invocation with the call operator instead of Start-Process
                            if ($arguments) {
                                Write-Host "Running: & $scriptPath $arguments" -ForegroundColor Gray
                                # Create a scriptblock from the command and invoke it
                                $scriptBlock = [ScriptBlock]::Create("& '$scriptPath' $arguments")
                                Invoke-Command -ScriptBlock $scriptBlock
                            } else {
                                Write-Host "Running: & $scriptPath" -ForegroundColor Gray
                                # Direct invocation with call operator
                                & $scriptPath
                            }
                        } catch {
                            Write-Host "Error executing script: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host "Exception details: $($_ | Out-String)" -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "Invalid selection." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Invalid input. Please enter a number." -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} while ($true)
