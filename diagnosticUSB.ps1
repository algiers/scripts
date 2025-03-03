# Script interactif de diagnostique et reinitialisation des peripheriques USB
# A executer en tant qu'administrateur

function Show-Menu {
    Clear-Host
    Write-Host "===== OUTIL DE DIAGNOSTIC ET REINITIALISATION USB =====" -ForegroundColor Cyan
    Write-Host
    Write-Host "1: Lister tous les peripheriques USB" -ForegroundColor Green
    Write-Host "2: Reinitialiser un peripherique USB specifique" -ForegroundColor Green
    Write-Host "3: Reinitialiser tous les controleurs et hubs USB" -ForegroundColor Yellow
    Write-Host "4: Desactiver l'economie d'energie pour les ports USB" -ForegroundColor Yellow
    Write-Host "5: Nettoyer le cache des pilotes USB" -ForegroundColor Red
    Write-Host "6: Verifier les performances du controleur USB" -ForegroundColor Green
    Write-Host "7: Diagnostic complet avec rapport" -ForegroundColor Magenta
    Write-Host "Q: Quitter" -ForegroundColor Gray
    Write-Host
    Write-Host "Note: Les options en jaune et rouge peuvent necessiter un redemarrage" -ForegroundColor Yellow
    Write-Host
}

function List-USBDevices {
    Write-Host "Liste des peripheriques USB:" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan
    
    $usbDevices = Get-PnpDevice -Class USB -ErrorAction SilentlyContinue
    
    if ($usbDevices) {
        $i = 1
        $script:deviceList = @()
        
        foreach ($device in $usbDevices) {
            $status = switch ($device.Status) {
                "OK" { "Fonctionnel" }
                "Error" { "Erreur" }
                "Unknown" { "Inconnu" }
                "Degraded" { "Degrade" }
                default { $device.Status }
            }
            
            $statusColor = switch ($device.Status) {
                "OK" { "Green" }
                "Error" { "Red" }
                "Unknown" { "Yellow" }
                "Degraded" { "Yellow" }
                default { "White" }
            }
            
            Write-Host "$i. " -NoNewline
            Write-Host $device.FriendlyName -NoNewline -ForegroundColor White
            Write-Host " - Etat: " -NoNewline
            Write-Host $status -ForegroundColor $statusColor
            
            $deviceInfo = [PSCustomObject]@{
                Index = $i
                Name = $device.FriendlyName
                Status = $device.Status
                InstanceId = $device.InstanceId
            }
            
            $script:deviceList += $deviceInfo
            $i++
        }
    } else {
        Write-Host "Aucun peripherique USB trouve ou acces insuffisant." -ForegroundColor Red
    }
    
    Write-Host
    Read-Host "Appuyez sur Entree pour continuer"
}

function Reset-SpecificUSBDevice {
    List-USBDevices
    
    if ($script:deviceList.Count -eq 0) {
        return
    }
    
    Write-Host "Selectionnez le numero du peripherique a reinitialiser (ou 0 pour annuler): " -ForegroundColor Yellow -NoNewline
    $selection = Read-Host
    
    if ($selection -eq "0" -or [string]::IsNullOrEmpty($selection)) {
        return
    }
    
    $selectionIndex = [int]$selection - 1
    
    if ($selectionIndex -ge 0 -and $selectionIndex -lt $script:deviceList.Count) {
        $selectedDevice = $script:deviceList[$selectionIndex]
        
        Write-Host "`nReinitialisation de: " -NoNewline
        Write-Host $selectedDevice.Name -ForegroundColor Cyan
        
        try {
            Write-Host "Desactivation..." -ForegroundColor Yellow
            Disable-PnpDevice -InstanceId $selectedDevice.InstanceId -Confirm:$false -ErrorAction Stop
            
            Write-Host "Attente de 5 secondes..." -ForegroundColor Yellow
            $progressParams = @{
                Activity = "Reinitialisation en cours"
                Status = "Veuillez patienter"
                PercentComplete = 0
            }
            
            for ($i = 1; $i -le 5; $i++) {
                $progressParams.PercentComplete = $i * 20
                Write-Progress @progressParams
                Start-Sleep -Seconds 1
            }
            
            Write-Progress -Activity "Reinitialisation en cours" -Completed
            
            Write-Host "Reactivation..." -ForegroundColor Green
            Enable-PnpDevice -InstanceId $selectedDevice.InstanceId -Confirm:$false -ErrorAction Stop
            
            Write-Host "`nReinitialisation terminee avec succes!" -ForegroundColor Green
        }
        catch {
            Write-Host "`nErreur lors de la reinitialisation: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Selection invalide." -ForegroundColor Red
    }
    
    Write-Host
    Read-Host "Appuyez sur Entree pour continuer"
}

function Reset-AllUSBControllers {
    Write-Host "ATTENTION: Cette operation va reinitialiser TOUS les controleurs USB!" -ForegroundColor Red
    Write-Host "Tous les peripheriques USB seront temporairement deconnectes." -ForegroundColor Yellow
    $confirm = Read-Host "Etes-vous sur de vouloir continuer? (O/N)"
    
    if ($confirm -ne "O" -and $confirm -ne "o") {
        return
    }
    
    Write-Host "`nRecuperation des controleurs USB..." -ForegroundColor Cyan
    $usbControllers = Get-PnpDevice -Class USB | Where-Object { 
        $_.FriendlyName -match "USB Root Hub|Generic USB Hub|USB Host Controller" -or 
        $_.FriendlyName -match "Controleur|Concentrateur"
    }
    
    if ($usbControllers.Count -eq 0) {
        Write-Host "Aucun controleur USB trouve." -ForegroundColor Red
        Read-Host "Appuyez sur Entree pour continuer"
        return
    }
    
    Write-Host "Les controleurs suivants seront reinitialises:" -ForegroundColor Yellow
    foreach ($controller in $usbControllers) {
        Write-Host " - $($controller.FriendlyName)" -ForegroundColor White
    }
    
    $finalConfirm = Read-Host "`nDerniere confirmation avant reinitialisation (O/N)"
    
    if ($finalConfirm -ne "O" -and $finalConfirm -ne "o") {
        return
    }
    
    $totalCount = $usbControllers.Count
    $current = 0
    
    foreach ($controller in $usbControllers) {
        $current++
        $percent = [math]::Round(($current / $totalCount) * 100)
        
        Write-Progress -Activity "Reinitialisation des controleurs USB" -Status "Traitement: $($controller.FriendlyName)" -PercentComplete $percent
        
        try {
            Write-Host "Desactivation de $($controller.FriendlyName)..." -ForegroundColor Yellow
            Disable-PnpDevice -InstanceId $controller.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            
            Write-Host "Reactivation de $($controller.FriendlyName)..." -ForegroundColor Green
            Enable-PnpDevice -InstanceId $controller.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "Erreur lors de la reinitialisation de $($controller.FriendlyName): $_" -ForegroundColor Red
        }
    }
    
    Write-Progress -Activity "Reinitialisation des controleurs USB" -Completed
    
    Write-Host "`nReinitialisation de tous les controleurs USB terminee!" -ForegroundColor Green
    Write-Host "Veuillez patienter quelques secondes pour que tous les peripheriques se reconnectent." -ForegroundColor Yellow
    
    Read-Host "Appuyez sur Entree pour continuer"
}

function Disable-USBPowerSaving {
    Write-Host "Desactivation de l'economie d'energie pour les peripheriques USB..." -ForegroundColor Cyan
    
    try {
        # Verifier si les modules necessaires sont disponibles
        if (-not (Get-Module -ListAvailable -Name "PowerShellGet")) {
            Write-Host "Le module PowerShellGet n'est pas disponible. Cette fonction pourrait ne pas fonctionner correctement." -ForegroundColor Yellow
        }
        
        # Desactiver l'economie d'energie pour les controleurs USB via les parametres du registre
        Write-Host "1. Configuration des parametres d'alimentation USB dans le registre..." -ForegroundColor Yellow
        
        # Recuperer tous les peripheriques USB
        $usbDevices = Get-PnpDevice -Class USB -ErrorAction SilentlyContinue
        $usbDevicesCount = ($usbDevices | Measure-Object).Count
        $current = 0
        
        foreach ($device in $usbDevices) {
            $current++
            $percent = [math]::Round(($current / $usbDevicesCount) * 100)
            Write-Progress -Activity "Modification des parametres d'alimentation USB" -Status "Peripherique: $($device.FriendlyName)" -PercentComplete $percent
            
            # Chemin du registre pour le peripherique
            $devicePath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($device.InstanceId)\Device Parameters"
            
            # Verifier si le chemin existe
            if (Test-Path $devicePath) {
                try {
                    # Desactiver l'economie d'energie selective suspend
                    Set-ItemProperty -Path $devicePath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $devicePath -Name "AllowIdleIrpInD3" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $devicePath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                } catch {
                    # Ignorer les erreurs silencieusement - certains peripheriques n'ont pas ces parametres
                }
            }
        }
        
        Write-Progress -Activity "Modification des parametres d'alimentation USB" -Completed
        
        # Configurer le plan d'alimentation pour desactiver l'economie d'energie USB
        Write-Host "2. Configuration du plan d'alimentation pour les ports USB..." -ForegroundColor Yellow
        
        try {
            # Obtenir le GUID du plan d'alimentation actif
            $activePowerPlan = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='True'").InstanceID
            $powerPlanGuid = $activePowerPlan.Replace("Microsoft:PowerPlan\{", "").Replace("}", "")
            
            # Desactiver l'economie d'energie USB pour le plan actif
            powercfg -SETACVALUEINDEX $powerPlanGuid 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
            powercfg -SETDCVALUEINDEX $powerPlanGuid 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
            
            Write-Host "3. Application des modifications au plan d'alimentation..." -ForegroundColor Yellow
            powercfg -S $powerPlanGuid
            
            Write-Host "`nL'economie d'energie pour les peripheriques USB a ete desactivee avec suc