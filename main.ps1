do {
    $availableScripts = Get-ChildItem -Path "$scriptsLocalPath" -Filter "*.ps1" | 
                        Where-Object { $_.Name -ne "main.ps1" } | 
                        Select-Object -ExpandProperty FullName

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
                        $scriptPath = $availableScripts[$choiceNum - 1]

                        if (-not (Test-Path $scriptPath)) {
                            Write-Host "Script not found: $scriptPath" -ForegroundColor Red
                            continue
                        }

                        Write-Host "Executing: $(Split-Path $scriptPath -Leaf)" -ForegroundColor Cyan
                        $arguments = Read-Host "Enter script arguments (e.g., -Param1 Value1), or press Enter to run without arguments"

                        if ($arguments) {
                            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $arguments" -Wait
                        } else {
                            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
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