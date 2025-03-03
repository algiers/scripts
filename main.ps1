# main.ps1

# --- Configuration ---
$repoUrl = "https://github.com/algiers/scripts.git"
$scriptsLocalPath = "$env:TEMP\ChifaPlusScripts" # Dossier temporaire pour les scripts
$ErrorActionPreference = "Stop"

# --- Fonction de mise à jour ---
function Update-Scripts {
    Write-Host "Mise à jour des scripts depuis $repoUrl..."
    if (-not (Test-Path $scriptsLocalPath)) {
        New-Item -ItemType Directory -Path $scriptsLocalPath -Force | Out-Null
    }
    
    # Configure Git safe directory
    git config --global --add safe.directory $scriptsLocalPath
    
    Set-Location $scriptsLocalPath

    if (Test-Path ..git) {
        git pull origin main
    } else {
        git clone $repoUrl .
    }
    Write-Host "Scripts mis à jour."
}

# --- Mise à jour initiale ---
Update-Scripts

# --- Menu interactif ---
do {
    #Construire la liste des scripts disponibles.
    $availableScripts = Get-ChildItem -Path "$scriptsLocalPath" -Filter "*.ps1" | Where-Object { $_.Name -ne "main.ps1" } | ForEach-Object {$_.BaseName}

    #Afficher la liste a l'utilisateur
    Write-Host "Scripts disponibles:" -ForegroundColor Green
    $i = 1
    foreach($script in $availableScripts){
        Write-Host "$i. $script"
        $i++
    }

    #Demander a l'utilsiateur de choisir un script.
    try{
        $choix = Read-Host "Entrez le numéro du script à exécuter (ou 'q' pour quitter, 'u' pour mettre à jour)"
        if($choix -eq 'q'){
            break # Quitter la boucle
        }
        elseif($choix -eq 'u'){
            Update-Scripts # Mettre à jour les scripts
        }
        elseif($choix -as [int] -ge 1 -and $choix -as [int] -le $availableScripts.Count){
            # --- Exécution du script choisi ---
            $selectedScript = $availableScripts[$choix - 1]
            $scriptPath = "$scriptsLocalPath\$selectedScript.ps1"

            if (Test-Path $scriptPath) {
                Write-Host "Exécution du script: $selectedScript" -ForegroundColor Cyan

                # Demander les arguments si nécessaire
                $arguments = Read-Host "Entrez les arguments du script (ex: -Param1 Valeur1 -Param2 Valeur2), ou appuyez sur Entrée pour exécuter sans arguments"

                if ($arguments) {
                    Invoke-Expression "& '$scriptPath' $arguments"
                } else {
                    & $scriptPath
                }
            } else {
                Write-Host "Script non trouvé: $scriptPath" -ForegroundColor Red
            }
        }
        else{
            Write-Host "Choix invalide." -ForegroundColor Red
        }
    }
    catch{
        Write-Host "Une erreur s'est produite: $($_.Exception.Message)" -ForegroundColor Red
    }
} while ($true)

Write-Host "Au revoir!"
