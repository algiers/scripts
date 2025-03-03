# Script interactif de diagnostique et réinitialisation des périphériques USB
# À exécuter en tant qu'administrateur

function Show-Menu {
    Clear-Host
    Write-Host "===== OUTIL DE DIAGNOSTIC ET RÉINITIALISATION USB =====" -ForegroundColor Cyan
    Write-Host
    Write-Host "1: Lister tous les périphériques USB" -ForegroundColor Green
    Write-Host "2: Réinitialiser un périphérique USB spécifique" -ForegroundColor Green
    Write-Host "3: Réinitialiser tous les contrôleurs et hubs USB" -ForegroundColor Yellow
    Write-Host "4: Désactiver l'économie d'énergie pour les ports USB" -ForegroundColor Yellow
    Write-Host "5: Nettoyer le cache des pilotes USB" -ForegroundColor Red
    Write-Host "6: Vérifier les performances du contrôleur USB" -ForegroundColor Green
    Write-Host "7: Diagnostic complet avec rapport" -ForegroundColor Magenta
    Write-Host "Q: Quitter" -ForegroundColor Gray
    Write-Host
    Write-Host "Note: Les options en jaune et rouge peuvent nécessiter un redémarrage" -ForegroundColor Yellow
    Write-Host
}

function List-USBDevices {
    Write-Host "Liste des périphériques USB:" -ForegroundColor Cyan
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
                "Degraded" { "Dégradé" }
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
            Write-Host " - État: " -NoNewline
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
        Write-Host "Aucun périphérique USB trouvé ou accès insuffisant." -ForegroundColor Red
    }
    
    Write-Host
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Reset-SpecificUSBDevice {
    List-USBDevices
    
    if ($script:deviceList.Count -eq 0) {
        return
    }
    
    Write-Host "Sélectionnez le numéro du périphérique à réinitialiser (ou 0 pour annuler): " -ForegroundColor Yellow -NoNewline
    $selection = Read-Host
    
    if ($selection -eq "0" -or [string]::IsNullOrEmpty($selection)) {
        return
    }
    
    $selectionIndex = [int]$selection - 1
    
    if ($selectionIndex -ge 0 -and $selectionIndex -lt $script:deviceList.Count) {
        $selectedDevice = $script:deviceList[$selectionIndex]
        
        Write-Host "`nRéinitialisation de: " -NoNewline
        Write-Host $selectedDevice.Name -ForegroundColor Cyan
        
        try {
            Write-Host "Désactivation..." -ForegroundColor Yellow
            Disable-PnpDevice -InstanceId $selectedDevice.InstanceId -Confirm:$false -ErrorAction Stop
            
            Write-Host "Attente de 5 secondes..." -ForegroundColor Yellow
            $progressParams = @{
                Activity = "Réinitialisation en cours"
                Status = "Veuillez patienter"
                PercentComplete = 0
            }
            
            for ($i = 1; $i -le 5; $i++) {
                $progressParams.PercentComplete = $i * 20
                Write-Progress @progressParams
                Start-Sleep -Seconds 1
            }
            
            Write-Progress -Activity "Réinitialisation en cours" -Completed
            
            Write-Host "Réactivation..." -ForegroundColor Green
            Enable-PnpDevice -InstanceId $selectedDevice.InstanceId -Confirm:$false -ErrorAction Stop
            
            Write-Host "`nRéinitialisation terminée avec succès!" -ForegroundColor Green
        }
        catch {
            Write-Host "`nErreur lors de la réinitialisation: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Sélection invalide." -ForegroundColor Red
    }
    
    Write-Host
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Reset-AllUSBControllers {
    Write-Host "ATTENTION: Cette opération va réinitialiser TOUS les contrôleurs USB!" -ForegroundColor Red
    Write-Host "Tous les périphériques USB seront temporairement déconnectés." -ForegroundColor Yellow
    $confirm = Read-Host "Êtes-vous sûr de vouloir continuer? (O/N)"
    
    if ($confirm -ne "O" -and $confirm -ne "o") {
        return
    }
    
    Write-Host "`nRécupération des contrôleurs USB..." -ForegroundColor Cyan
    $usbControllers = Get-PnpDevice -Class USB | Where-Object { 
        $_.FriendlyName -match "USB Root Hub|Generic USB Hub|USB Host Controller" -or 
        $_.FriendlyName -match "Contrôleur|Concentrateur"
    }
    
    if ($usbControllers.Count -eq 0) {
        Write-Host "Aucun contrôleur USB trouvé." -ForegroundColor Red
        Read-Host "Appuyez sur Entrée pour continuer"
        return
    }
    
    Write-Host "Les contrôleurs suivants seront réinitialisés:" -ForegroundColor Yellow
    foreach ($controller in $usbControllers) {
        Write-Host " - $($controller.FriendlyName)" -ForegroundColor White
    }
    
    $finalConfirm = Read-Host "`nDernière confirmation avant réinitialisation (O/N)"
    
    if ($finalConfirm -ne "O" -and $finalConfirm -ne "o") {
        return
    }
    
    $totalCount = $usbControllers.Count
    $current = 0
    
    foreach ($controller in $usbControllers) {
        $current++
        $percent = [math]::Round(($current / $totalCount) * 100)
        
        Write-Progress -Activity "Réinitialisation des contrôleurs USB" -Status "Traitement: $($controller.FriendlyName)" -PercentComplete $percent
        
        try {
            Write-Host "Désactivation de $($controller.FriendlyName)..." -ForegroundColor Yellow
            Disable-PnpDevice -InstanceId $controller.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            
            Write-Host "Réactivation de $($controller.FriendlyName)..." -ForegroundColor Green
            Enable-PnpDevice -InstanceId $controller.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "Erreur lors de la réinitialisation de $($controller.FriendlyName): $_" -ForegroundColor Red
        }
    }
    
    Write-Progress -Activity "Réinitialisation des contrôleurs USB" -Completed
    
    Write-Host "`nRéinitialisation de tous les contrôleurs USB terminée!" -ForegroundColor Green
    Write-Host "Veuillez patienter quelques secondes pour que tous les périphériques se reconnectent." -ForegroundColor Yellow
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Disable-USBPowerSaving {
    Write-Host "Désactivation de l'économie d'énergie pour les périphériques USB..." -ForegroundColor Cyan
    
    try {
        # Vérifier si les modules nécessaires sont disponibles
        if (-not (Get-Module -ListAvailable -Name "PowerShellGet")) {
            Write-Host "Le module PowerShellGet n'est pas disponible. Cette fonction pourrait ne pas fonctionner correctement." -ForegroundColor Yellow
        }
        
        # Désactiver l'économie d'énergie pour les contrôleurs USB via les paramètres du registre
        Write-Host "1. Configuration des paramètres d'alimentation USB dans le registre..." -ForegroundColor Yellow
        
        # Récupérer tous les périphériques USB
        $usbDevices = Get-PnpDevice -Class USB -ErrorAction SilentlyContinue
        $usbDevicesCount = ($usbDevices | Measure-Object).Count
        $current = 0
        
        foreach ($device in $usbDevices) {
            $current++
            $percent = [math]::Round(($current / $usbDevicesCount) * 100)
            Write-Progress -Activity "Modification des paramètres d'alimentation USB" -Status "Périphérique: $($device.FriendlyName)" -PercentComplete $percent
            
            # Chemin du registre pour le périphérique
            $devicePath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($device.InstanceId)\Device Parameters"
            
            # Vérifier si le chemin existe
            if (Test-Path $devicePath) {
                try {
                    # Désactiver l'économie d'énergie selective suspend
                    Set-ItemProperty -Path $devicePath -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $devicePath -Name "AllowIdleIrpInD3" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $devicePath -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                } catch {
                    # Ignorer les erreurs silencieusement - certains périphériques n'ont pas ces paramètres
                }
            }
        }
        
        Write-Progress -Activity "Modification des paramètres d'alimentation USB" -Completed
        
        # Configurer le plan d'alimentation pour désactiver l'économie d'énergie USB
        Write-Host "2. Configuration du plan d'alimentation pour les ports USB..." -ForegroundColor Yellow
        
        try {
            # Obtenir le GUID du plan d'alimentation actif
            $activePowerPlan = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='True'").InstanceID
            $powerPlanGuid = $activePowerPlan.Replace("Microsoft:PowerPlan\{", "").Replace("}", "")
            
            # Désactiver l'économie d'énergie USB pour le plan actif
            powercfg -SETACVALUEINDEX $powerPlanGuid 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
            powercfg -SETDCVALUEINDEX $powerPlanGuid 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
            
            Write-Host "3. Application des modifications au plan d'alimentation..." -ForegroundColor Yellow
            powercfg -S $powerPlanGuid
            
            Write-Host "`nL'économie d'énergie pour les périphériques USB a été désactivée avec succès!" -ForegroundColor Green
            Write-Host "Note: Un redémarrage du système est recommandé pour appliquer tous les changements." -ForegroundColor Yellow
        } catch {
            Write-Host "Erreur lors de la configuration du plan d'alimentation: $_" -ForegroundColor Red
        }
    } catch {
        Write-Host "Erreur lors de la désactivation de l'économie d'énergie: $_" -ForegroundColor Red
    }
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Clean-USBDriverCache {
    Write-Host "ATTENTION: Cette opération va nettoyer le cache des pilotes USB!" -ForegroundColor Red
    Write-Host "Un redémarrage sera nécessaire après cette opération." -ForegroundColor Yellow
    $confirm = Read-Host "Êtes-vous sûr de vouloir continuer? (O/N)"
    
    if ($confirm -ne "O" -and $confirm -ne "o") {
        return
    }
    
    try {
        Write-Host "`nArrêt du service Plug and Play..." -ForegroundColor Yellow
        Stop-Service -Name "PlugPlay" -Force -ErrorAction SilentlyContinue
        
        Write-Host "Suppression des clés de registre du cache USB..." -ForegroundColor Yellow
        
        # Suppression des paramètres MaximumTransferSize
        Remove-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\*\*\Device Parameters\MaximumTransferSize" -Force -ErrorAction SilentlyContinue
        
        # Nettoyage des périphériques USB dans le gestionnaire de périphériques
        Write-Host "Nettoyage des périphériques USB fantômes..." -ForegroundColor Yellow
        
        # Création d'un script temporaire pour exécuter devcon
        $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
        
        # Contenu du script
        $scriptContent = @"
# Définir l'environnement pour devcon (utilisation de pnputil dans Windows 10/11)
`$devconPath = "pnputil.exe"

# Vérifier si pnputil est disponible
if (Test-Path `$devconPath) {
    # Nettoyer les périphériques USB fantômes
    & `$devconPath /enum-devices /disconnected /class USB | Out-Null
    & `$devconPath /remove-devices /disconnected /class USB | Out-Null
    
    Write-Host "Nettoyage des périphériques USB fantômes terminé." -ForegroundColor Green
} else {
    Write-Host "Outil pnputil non trouvé. Impossible de nettoyer les périphériques fantômes." -ForegroundColor Red
}
"@
        
        # Écriture du script dans le fichier temporaire
        Set-Content -Path $tempScript -Value $scriptContent
        
        # Exécution du script temporaire avec élévation de privilèges
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Verb RunAs -Wait
        
        # Suppression du script temporaire
        Remove-Item -Path $tempScript -Force
        
        Write-Host "Redémarrage du service Plug and Play..." -ForegroundColor Yellow
        Start-Service -Name "PlugPlay" -ErrorAction SilentlyContinue
        
        Write-Host "`nNettoyage du cache des pilotes USB terminé!" -ForegroundColor Green
        Write-Host "Un redémarrage du système est nécessaire pour appliquer tous les changements." -ForegroundColor Yellow
        
        $rebootNow = Read-Host "Voulez-vous redémarrer maintenant? (O/N)"
        if ($rebootNow -eq "O" -or $rebootNow -eq "o") {
            Restart-Computer -Force
        }
    } catch {
        Write-Host "Erreur lors du nettoyage du cache des pilotes USB: $_" -ForegroundColor Red
    }
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Check-USBControllerPerformance {
    Write-Host "Vérification des performances du contrôleur USB..." -ForegroundColor Cyan
    
    try {
        # Récupérer les informations sur les contrôleurs USB
        $usbControllers = Get-WmiObject -Class Win32_USBController -ErrorAction Stop
        
        if ($usbControllers.Count -eq 0) {
            Write-Host "Aucun contrôleur USB trouvé." -ForegroundColor Red
            Read-Host "Appuyez sur Entrée pour continuer"
            return
        }
        
        Write-Host "`nContrôleurs USB détectés:" -ForegroundColor Green
        foreach ($controller in $usbControllers) {
            $status = switch ($controller.Status) {
                "OK" { "Fonctionnel" }
                "Error" { "Erreur" }
                "Degraded" { "Dégradé" }
                "Unknown" { "Inconnu" }
                default { $controller.Status }
            }
            
            $statusColor = switch ($controller.Status) {
                "OK" { "Green" }
                "Error" { "Red" }
                "Degraded" { "Yellow" }
                "Unknown" { "Yellow" }
                default { "White" }
            }
            
            Write-Host "Nom: " -NoNewline -ForegroundColor White
            Write-Host $controller.Name -ForegroundColor Cyan
            Write-Host "ID: " -NoNewline -ForegroundColor White
            Write-Host $controller.DeviceID -ForegroundColor Cyan
            Write-Host "État: " -NoNewline -ForegroundColor White
            Write-Host $status -ForegroundColor $statusColor
            Write-Host "Fabricant: " -NoNewline -ForegroundColor White
            Write-Host $controller.Manufacturer -ForegroundColor Cyan
            Write-Host "--------------------------" -ForegroundColor White
        }
        
        # Récupérer les périphériques connectés avec leurs vitesses
        Write-Host "`nVérification des vitesses de périphériques USB..." -ForegroundColor Yellow
        
        # Utilisation de PowerShell pour obtenir des informations sur les périphériques USB
        $usbDevices = Get-PnpDevice -Class USB | Where-Object { $_.Status -eq "OK" }
        $usbDevices | Format-Table FriendlyName, Status, InstanceId -AutoSize | Out-String | Out-File -FilePath $reportFile -Append
        $problemDevices = $usbDevices | Where-Object { $_.Status -ne "OK" }
        if ($problemDevices.Count -gt 0) {
            $problemDevices | Format-Table FriendlyName, Status, InstanceId -AutoSize | Out-String | Out-File -FilePath $reportFile -Append
        } else {
            "Aucun périphérique problématique détecté." | Out-File -FilePath $reportFile -Append
        }
        
        Write-Host "5. Analyse des paramètres d'alimentation USB..." -ForegroundColor Yellow
        "-- PARAMETRES D'ALIMENTATION USB --" | Out-File -FilePath $reportFile -Append
        $activePowerPlan = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='True'").ElementName
        "Plan d'alimentation actif: $activePowerPlan" | Out-File -FilePath $reportFile -Append
        
        Write-Host "6. Analyse des journaux d'événements..." -ForegroundColor Yellow
        "-- EVENEMENTS USB RECENTS --" | Out-File -FilePath $reportFile -Append
        $usbEvents = Get-WinEvent -LogName System -MaxEvents 50 | Where-Object { $_.Message -match "USB" }
        if ($usbEvents.Count -gt 0) {
            $usbEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize | Out-String | Out-File -FilePath $reportFile -Append
        } else {
            "Aucun événement USB récent trouvé." | Out-File -FilePath $reportFile -Append
        }
        
        Write-Host "7. Génération des recommandations..." -ForegroundColor Yellow
        "-- RECOMMANDATIONS --" | Out-File -FilePath $reportFile -Append
        
        $recommendations = @()
        
        if ($problemDevices.Count -gt 0) {
            $recommendations += "- Réinitialisez les périphériques problématiques détectés."
        }
        $usb3Controllers = $usbControllers | Where-Object { $_.Name -match "3\.0|3\.1|3\.2|SuperSpeed" }
        if ($usb3Controllers.Count -gt 0) {
            $recommendations += "- Pour les transferts rapides, utilisez les ports USB 3.0/3.1/3.2 (généralement de couleur bleue)."
        }
        $recommendations += "- Évitez de connecter trop de périphériques sur le même contrôleur USB."
        $recommendations += "- Utilisez un hub USB alimenté pour les périphériques gourmands en énergie."
        $recommendations += "- Assurez-vous que vos pilotes USB sont à jour via le Gestionnaire de périphériques."
        
        if ($activePowerPlan -match "Économie|Power saver") {
            $recommendations += "- Votre plan d'alimentation actuel peut limiter les performances USB. Envisagez de passer à un plan 'Performances élevées'."
        }
        
        $recommendations | Out-File -FilePath $reportFile -Append
        
        # Finaliser le rapport
        "" | Out-File -FilePath $reportFile -Append
        "=== FIN DU RAPPORT ===" | Out-File -FilePath $reportFile -Append
        
        Write-Host "`nDiagnostic terminé avec succès!" -ForegroundColor Green
        Write-Host "Le rapport a été enregistré dans: $reportFile" -ForegroundColor Cyan
        
        # Proposer d'ouvrir le rapport
        $openReport = Read-Host "Voulez-vous ouvrir le rapport maintenant? (O/N)"
        if ($openReport -eq "O" -or $openReport -eq "o") {
            Invoke-Item $reportFile
        }
        
    } catch {
        Write-Host "Erreur lors de l'exécution du diagnostic: $_" -ForegroundColor Red
        "ERREUR LORS DU DIAGNOSTIC: $_" | Out-File -FilePath $reportFile -Append
    }
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Run-CompleteDiagnostic {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportFile = "$env:USERPROFILE\Desktop\DiagnosticUSB_$timestamp.txt"
    
    Write-Host "Exécution du diagnostic complet. Ce processus peut prendre quelques minutes..." -ForegroundColor Cyan
    Write-Host "Un rapport sera créé sur votre bureau: $reportFile" -ForegroundColor Yellow
    
    # Créer le fichier de rapport
    "=== RAPPORT DE DIAGNOSTIC USB - $timestamp ===" | Out-File -FilePath $reportFile -Append
    "" | Out-File -FilePath $reportFile -Append
    
    try {
        Write-Host "1. Collecte des informations système..." -ForegroundColor Yellow
        "-- INFORMATIONS SYSTEME --" | Out-File -FilePath $reportFile -Append
        $systemInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer
        $systemInfo | Format-List | Out-String | Out-File -FilePath $reportFile -Append
        
        Write-Host "2. Analyse des contrôleurs USB..." -ForegroundColor Yellow
        "-- CONTROLEURS USB --" | Out-File -FilePath $reportFile -Append
        $usbControllers = Get-WmiObject -Class Win32_USBController
        $usbControllers | Format-List Name, DeviceID, Status, Manufacturer | Out-String | Out-File -FilePath $reportFile -Append
        
        Write-Host "3. Analyse des périphériques USB..." -ForegroundColor Yellow
        "-- PERIPHERIQUES USB --" | Out-File -FilePath $reportFile -Append
        $usbDevices = Get-PnpDevice -Class USB
        $usbDevices | Format-Table FriendlyName, Status, InstanceId -AutoSize | Out-String | Out-File -FilePath $reportFile -Append
        
        Write-Host "4. Recherche des périphériques problématiques..." -ForegroundColor Yellow
        "-- PERIPHERIQUES PROBLEMATIQUES --" | Out-File -FilePath $reportFile -Append
        $problemDevices = $usbDevices | Where-Object { $_.Status -ne "OK" }
        if ($problemDevices.Count -gt 0) {
            $problemDevices | Format-Table FriendlyName, Status, InstanceId -AutoSize | Out-String | Out-File -FilePath $reportFile -Append
        } else {
            "Aucun périphérique problématique détecté." | Out-File -FilePath $reportFile -Append
        }
        
        Write-Host "5. Analyse des paramètres d'alimentation USB..." -ForegroundColor Yellow
        "-- PARAMETRES D'ALIMENTATION USB --" | Out-File -FilePath $reportFile -Append
        
        # Vérifier la politique d'alimentation USB
        $activePowerPlan = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='True'").ElementName
        "Plan d'alimentation actif: $activePowerPlan" | Out-File -FilePath $reportFile -Append
        
        Write-Host "6. Analyse des journaux d'événements..." -ForegroundColor Yellow
        "-- EVENEMENTS USB RECENTS --" | Out-File -FilePath $reportFile -Append
        $usbEvents = Get-WinEvent -LogName System -MaxEvents 50 | Where-Object { $_.Message -match "USB" }
        if ($usbEvents.Count -gt 0) {
            $usbEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize | Out-String | Out-File -FilePath $reportFile -Append
        } else {
            "Aucun événement USB récent trouvé." | Out-File -FilePath $reportFile -Append
        }
        
        Write-Host "7. Génération des recommandations..." -ForegroundColor Yellow
        "-- RECOMMANDATIONS --" | Out-File -FilePath $reportFile -Append
        
        $recommendations = @()
        
        if ($problemDevices.Count -gt 0) {
            $recommendations += "- Réinitialisez les périphériques problématiques détectés."
        }
        $usb3Controllers = $usbControllers | Where-Object { $_.Name -match "3\.0|3\.1|3\.2|SuperSpeed" }
        if ($usb3Controllers.Count -gt 0) {
            $recommendations += "- Pour les transferts rapides, utilisez les ports USB 3.0/3.1/3.2 (généralement de couleur bleue)."
        }
        $recommendations += "- Évitez de connecter trop de périphériques sur le même contrôleur USB."
        $recommendations += "- Utilisez un hub USB alimenté pour les périphériques gourmands en énergie."
        $recommendations += "- Assurez-vous que vos pilotes USB sont à jour via le Gestionnaire de périphériques."
        
        if ($activePowerPlan -match "Économie|Power saver") {
            $recommendations += "- Votre plan d'alimentation actuel peut limiter les performances USB. Envisagez de passer à un plan 'Performances élevées'."
        }
        
        $recommendations | Out-File -FilePath $reportFile -Append
        
        # Finaliser le rapport
        "" | Out-File -FilePath $reportFile -Append
        "=== FIN DU RAPPORT ===" | Out-File -FilePath $reportFile -Append
        
        Write-Host "`nDiagnostic terminé avec succès!" -ForegroundColor Green
        Write-Host "Le rapport a été enregistré dans: $reportFile" -ForegroundColor Cyan
        
        # Proposer d'ouvrir le rapport
        $openReport = Read-Host "Voulez-vous ouvrir le rapport maintenant? (O/N)"
        if ($openReport -eq "O" -or $openReport -eq "o") {
            Invoke-Item $reportFile
        }
        
    } catch {
        Write-Host "Erreur lors de l'exécution du diagnostic: $_" -ForegroundColor Red
        "ERREUR LORS DU DIAGNOSTIC: $_" | Out-File -FilePath $reportFile -Append
    }
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

# Script principal
$script:deviceList = @()

# Vérifier les privilèges d'administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ATTENTION: Ce script nécessite des privilèges d'administrateur pour fonctionner correctement." -ForegroundColor Red
    Write-Host "Veuillez relancer PowerShell en tant qu'administrateur." -ForegroundColor Yellow
    Write-Host
    Read-Host "Appuyez sur Entrée pour quitter"
    exit
}

# Boucle principale du menu
do {
    Show-Menu
    $selection = Read-Host "Sélectionnez une option"
    
    switch ($selection) {
        "1" { List-USBDevices }
        "2" { Reset-SpecificUSBDevice }
        "3" { Reset-AllUSBControllers }
        "4" { Disable-USBPowerSaving }
        "5" { Clean-USBDriverCache }
        "6" { Check-USBControllerPerformance }
        "7" { Run-CompleteDiagnostic }
        "q" { return }
        "Q" { return }
        default { Write-Host "Option invalide. Veuillez réessayer." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($selection -ne "q" -and $selection -ne "Q")

Write-Host "Merci d'avoir utilisé l'outil de diagnostic USB!" -ForegroundColor Cyan