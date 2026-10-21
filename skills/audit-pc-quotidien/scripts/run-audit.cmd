@echo off
rem run-audit.cmd — lance par la tache planifiee AuditPC-Quotidien
rem 1) collecte des metriques  2) analyse par Claude Code (headless)  3) alerte si critique

setlocal
set "RACINE=%USERPROFILE%\AuditPC"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "JOUR=%%i"
set "LOG=%RACINE%\logs\audit-%JOUR%.log"
if not exist "%RACINE%\logs" mkdir "%RACINE%\logs"

echo [%date% %time%] Collecte des metriques >> "%LOG%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect-metrics.ps1" >> "%LOG%" 2>&1

echo [%date% %time%] Analyse Claude Code >> "%LOG%"
claude -p "Utilise le skill audit-pc-quotidien (installe dans %USERPROFILE%\.claude\skills\audit-pc-quotidien). Mode headless : la collecte est deja faite, le fichier du jour est %RACINE%\donnees\metriques-%JOUR%.json. Applique les etapes 3 a 5 du skill : analyse, note sur 100, rapport dans %RACINE%\rapports\rapport-%JOUR%.md, ligne ajoutee a %RACINE%\historique.csv, et fichier ALERTE-%JOUR%.md uniquement si condition critique. N'execute aucune commande." --allowedTools "Read,Write,Edit,Glob" --max-turns 30 >> "%LOG%" 2>&1

if exist "%RACINE%\rapports\ALERTE-%JOUR%.md" (
  echo [%date% %time%] ALERTE CRITIQUE detectee >> "%LOG%"
  powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show((Get-Content -Raw '%RACINE%\rapports\ALERTE-%JOUR%.md'), 'Audit PC - ALERTE CRITIQUE', 'OK', 'Warning')" >> "%LOG%" 2>&1
)

echo [%date% %time%] Termine >> "%LOG%"
endlocal
