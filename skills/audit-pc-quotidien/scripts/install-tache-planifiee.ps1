# install-tache-planifiee.ps1 — cree la tache Windows "AuditPC-Quotidien" a 8h00
# A executer en console ADMINISTRATEUR.

$ErrorActionPreference = 'Stop'

$estAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $estAdmin) {
    Write-Host 'ERREUR : lancez ce script dans une console PowerShell en administrateur.' -ForegroundColor Red
    exit 1
}

$scriptCmd = Join-Path $PSScriptRoot 'run-audit.cmd'
if (-not (Test-Path $scriptCmd)) {
    Write-Host "ERREUR : run-audit.cmd introuvable a cote de ce script ($scriptCmd)." -ForegroundColor Red
    exit 1
}

# Verification rapide que la CLI claude est accessible pour ce compte
try { $null = Get-Command claude -ErrorAction Stop }
catch {
    Write-Host "ATTENTION : la commande 'claude' n'est pas dans le PATH de cette session." -ForegroundColor Yellow
    Write-Host "La tache sera creee, mais verifiez que Claude Code fonctionne pour ce compte utilisateur."
}

$nomTache = 'AuditPC-Quotidien'
$action   = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c "' + $scriptCmd + '"')
$trigger  = New-ScheduledTaskTrigger -Daily -At '08:00'
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries `
            -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)

if (Get-ScheduledTask -TaskName $nomTache -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $nomTache -Confirm:$false
    Write-Host "Ancienne tache '$nomTache' remplacee."
}

Register-ScheduledTask -TaskName $nomTache -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description 'Audit quotidien du PC (collecte + analyse Claude Code) — skill audit-pc-quotidien' | Out-Null

Write-Host ''
Write-Host "Tache '$nomTache' creee : tous les jours a 08:00 (rattrapage si le PC etait eteint)." -ForegroundColor Green
Write-Host "Rapports dans : $env:USERPROFILE\AuditPC\rapports\"
Write-Host "Journaux dans : $env:USERPROFILE\AuditPC\logs\"
Write-Host ''
Write-Host "Test immediat possible : Start-ScheduledTask -TaskName '$nomTache'"
