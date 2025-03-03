# main.ps1

# --- Configuration ---
$repoUrl = "https://github.com/algiers/scripts.git"
$scriptsLocalPath = "$env:TEMP\ChifaPlusScripts"
$ErrorActionPreference = "Stop"

# --- Helper Functions ---
function Test-GitInstalled {
    try {
        $null = git --version
        return $true
    }
    catch {
        Write-Host "Git is not installed. Please install Git before running this script." -ForegroundColor Red
        return $false
    }
}

function Update-Scripts {
    Write-Host "Updating scripts from $repoUrl..."
    if (-not (Test-Path $scriptsLocalPath)) {
        New-Item -ItemType Directory -Path $scriptsLocalPath -Force | Out-Null
    }
    
    if (-not (Test-GitInstalled)) {
        exit 1
    }

    try {
        # Close any open file handles in the scripts directory to prevent file locking issues
        if (Test-Path $scriptsLocalPath) {
            Write-Host "Preparing files for update..." -ForegroundColor Yellow
            # Force garbage collection to release any file handles
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            
            # Get existing script files before update
            $existingFiles = Get-ChildItem -Path $scriptsLocalPath -Filter "*.ps1" -File | Select-Object -ExpandProperty FullName
        }
        
        # Configure Git safe directory
        git config --global --add safe.directory $scriptsLocalPath
        
        Push-Location $scriptsLocalPath

        if (Test-Path .git) {
            # Force clean any local changes to ensure clean update
            git reset --hard HEAD
            git clean -fd
            # Pull latest changes with allow-unrelated-histories flag to handle disconnected repositories
            git pull origin main --allow-unrelated-histories
        } else {
            git clone $repoUrl .
        }
        
        # Verify file updates were successful
        $updatedFiles = Get-ChildItem -Path $scriptsLocalPath -Filter "*.ps1" -File | Select-Object -ExpandProperty FullName
        $updatedCount = ($updatedFiles | Where-Object { $existingFiles -notcontains $_ }).Count + 
                       ($existingFiles | Where-Object { $updatedFiles -notcontains $_ }).Count
        
        if ($updatedCount -gt 0) {
            Write-Host "$updatedCount files were added or replaced." -ForegroundColor Green
        }
        
        Write-Host "Scripts updated successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to update scripts: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Pop-Location
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
