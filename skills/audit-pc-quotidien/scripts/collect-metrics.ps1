# collect-metrics.ps1 — Collecte des metriques pour le skill audit-pc-quotidien
# Compatible Windows PowerShell 5.1+. Chaque section est isolee : un echec
# produit un champ "erreur" sans interrompre la collecte.

$ErrorActionPreference = 'Stop'
$dateJour = Get-Date -Format 'yyyy-MM-dd'
$racine = Join-Path $env:USERPROFILE 'AuditPC'
foreach ($d in @('donnees','rapports','logs')) {
    $p = Join-Path $racine $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
$sortie = Join-Path $racine ("donnees\metriques-$dateJour.json")

function Invoke-Section {
    param([string]$Nom, [scriptblock]$Bloc)
    Write-Host "[collecte] $Nom..."
    try { & $Bloc } catch { @{ erreur = $_.Exception.Message } }
}

$estAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$donnees = [ordered]@{
    date        = (Get-Date).ToString('s')
    machine     = $env:COMPUTERNAME
    admin       = $estAdmin
}

# ---------------------------------------------------------------- 1. General
$donnees.general = Invoke-Section 'Etat general' {
    $os  = Get-CimInstance Win32_OperatingSystem
    $ramTotalMo = [math]::Round($os.TotalVisibleMemorySize / 1KB)
    $ramLibreMo = [math]::Round($os.FreePhysicalMemory / 1KB)

    # Mesure CPU independante de la langue de Windows (les noms de compteurs
    # Get-Counter sont localises et echouent sur un Windows en francais).
    $cpuPct = $null
    try {
        $mesures = for ($i = 0; $i -lt 3; $i++) {
            (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            Start-Sleep -Seconds 2
        }
        $cpuPct = [math]::Round(($mesures | Measure-Object -Average).Average)
    } catch {}

    $gpuPct = $null
    try {
        # Classe CIM : son nom ne depend pas de la langue de Windows (contrairement a Get-Counter)
        $ech = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
               Where-Object { $_.Name -like '*engtype_3D' }
        if ($ech) { $gpuPct = [math]::Round([math]::Min(100, ($ech | Measure-Object -Property UtilizationPercentage -Sum).Sum), 1) }
    } catch {}

    $dureeBootSec = $null
    try {
        $evt = Get-WinEvent -FilterHashtable @{ LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; Id=100 } -MaxEvents 1 -ErrorAction Stop
        $xml = [xml]$evt.ToXml()
        $bt = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }).'#text'
        if ($bt) { $dureeBootSec = [math]::Round([double]$bt / 1000, 1) }
    } catch {}

    @{
        dernierDemarrage   = $os.LastBootUpTime.ToString('s')
        uptimeHeures       = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
        dureeDemarrageSec  = $dureeBootSec
        cpuPct             = $cpuPct
        ramTotalMo         = $ramTotalMo
        ramUtiliseePct     = [math]::Round(100 * ($ramTotalMo - $ramLibreMo) / $ramTotalMo)
        gpu3DPct           = $gpuPct
    }
}

# ------------------------------------------------------- 1b. Temperatures LHM
$donnees.temperatures = Invoke-Section 'Temperatures (LibreHardwareMonitor)' {
    $lhm = Invoke-RestMethod -Uri 'http://localhost:8085/data.json' -TimeoutSec 4
    $temps = New-Object System.Collections.Generic.List[object]
    function Walk($noeud, $chemin) {
        foreach ($enfant in @($noeud.Children)) {
            if ($null -eq $enfant) { continue }
            $nouveau = if ($enfant.Text) { "$chemin/$($enfant.Text)" } else { $chemin }
            if ($enfant.Type -eq 'Temperature' -or ($enfant.SensorId -like '*temperature*')) {
                $temps.Add(@{ capteur = $nouveau; valeur = $enfant.Value })
            }
            Walk $enfant $nouveau
        }
    }
    Walk $lhm ''
    if ($temps.Count -eq 0) {
        # Structure alternative : certains builds exposent Value sur les feuilles Text/Min/Max
        throw 'Aucun capteur de temperature trouve dans data.json'
    }
    @{ capteurs = $temps }
}

# ---------------------------------------------------------------- 1c. Disques
$donnees.disques = Invoke-Section 'Disques et SMART' {
    $logiques = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        @{
            lettre    = $_.DeviceID
            tailleGo  = [math]::Round($_.Size / 1GB, 1)
            libreGo   = [math]::Round($_.FreeSpace / 1GB, 1)
            librePct  = if ($_.Size) { [math]::Round(100 * $_.FreeSpace / $_.Size) } else { $null }
            systeme   = ($_.DeviceID -eq $env:SystemDrive)
        }
    }
    $physiques = @()
    try {
        $physiques = Get-PhysicalDisk | ForEach-Object {
            $fiab = $null
            try { $fiab = $_ | Get-StorageReliabilityCounter } catch {}
            @{
                nom              = $_.FriendlyName
                type             = "$($_.MediaType)"
                sante            = "$($_.HealthStatus)"
                usurePct         = if ($fiab) { $fiab.Wear } else { $null }
                temperatureC     = if ($fiab) { $fiab.Temperature } else { $null }
                erreursLecture   = if ($fiab) { $fiab.ReadErrorsUncorrected } else { $null }
                erreursEcriture  = if ($fiab) { $fiab.WriteErrorsUncorrected } else { $null }
                heuresFonctionnement = if ($fiab -and $fiab.PowerOnHours) { $fiab.PowerOnHours.TotalHours } else { $null }
            }
        }
    } catch {}
    @{ volumes = @($logiques); physiques = @($physiques); smartComplet = $estAdmin }
}

# ---------------------------------------------------------------- 2. Pilotes
$donnees.pilotes = Invoke-Section 'Pilotes' {
    $classes = @('Display','System','Net','Media','USB','SCSIAdapter','HDC','Image','Printer','Bluetooth')
    $liste = Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceClass -in $classes -and $_.DeviceName } |
        Sort-Object DeviceClass, DeviceName -Unique |
        ForEach-Object {
            @{
                peripherique = $_.DeviceName
                classe       = $_.DeviceClass
                fabricant    = $_.Manufacturer
                version      = $_.DriverVersion
                date         = if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } else { $null }
            }
        }
    @{ liste = @($liste) }
}

# --------------------------------------------------------- 3. Windows Update
$donnees.windowsUpdate = Invoke-Section 'Windows Update' {
    $reg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $enAttente = @()
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $rech = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0")
        $enAttente = @($rech.Updates | ForEach-Object {
            @{
                titre      = $_.Title
                securite   = [bool]($_.Categories | Where-Object { $_.Name -like '*Security*' -or $_.Name -like '*curit*' })
                facultative = -not $_.AutoSelectOnWebSites
            }
        })
    } catch { $enAttente = @(@{ erreur = "Recherche WU impossible: $($_.Exception.Message)" }) }
    $redemarrageRequis = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    @{
        versionWindows     = "$($reg.ProductName) $($reg.DisplayVersion) (build $($reg.CurrentBuildNumber))"
        misesAJourEnAttente = $enAttente
        redemarrageRequis  = $redemarrageRequis
    }
}

# ---------------------------------------------------------------- 4. Securite
$donnees.securite = Invoke-Section 'Securite (Defender, pare-feu)' {
    $def = Get-MpComputerStatus
    $menaces = @()
    try { $menaces = @(Get-MpThreatDetection | Select-Object -First 10 | ForEach-Object { @{ menace = "$($_.ThreatID)"; date = $_.InitialDetectionTime.ToString('s') } }) } catch {}
    $pareFeu = Get-NetFirewallProfile | ForEach-Object { @{ profil = $_.Name; actif = [bool]$_.Enabled } }
    @{
        antivirusActif        = $def.AntivirusEnabled
        tempsReelActif        = $def.RealTimeProtectionEnabled
        signaturesDate        = if ($def.AntivirusSignatureLastUpdated) { $def.AntivirusSignatureLastUpdated.ToString('s') } else { $null }
        signaturesAgeJours    = $def.AntivirusSignatureAge
        derniereAnalyseRapide = if ($def.QuickScanEndTime) { $def.QuickScanEndTime.ToString('s') } else { $null }
        menacesRecentes       = $menaces
        pareFeu               = @($pareFeu)
    }
}

# ------------------------------------------------------------ 5. Performances
$donnees.performances = Invoke-Section 'Demarrage et processus' {
    $demarrage = Get-CimInstance Win32_StartupCommand | ForEach-Object {
        @{ nom = $_.Name; commande = $_.Command; emplacement = $_.Location }
    }
    $topRam = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
        @{ processus = $_.ProcessName; ramMo = [math]::Round($_.WorkingSet64 / 1MB) }
    }
    $topCpu = Get-Process | Where-Object { $_.CPU } | Sort-Object CPU -Descending | Select-Object -First 10 | ForEach-Object {
        @{ processus = $_.ProcessName; cpuSecondesCumulees = [math]::Round($_.CPU) }
    }
    @{
        programmesDemarrage = @($demarrage)
        nbProgrammesDemarrage = @($demarrage).Count
        topRam = @($topRam)
        topCpu = @($topCpu)
    }
}

# ---------------------------------------------------------------- 6. Nettoyage
$donnees.nettoyage = Invoke-Section 'Espace recuperable' {
    function TailleGo($chemin) {
        if (-not (Test-Path $chemin)) { return 0 }
        $s = (Get-ChildItem $chemin -Recurse -Force -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($s) { [math]::Round($s / 1GB, 2) } else { 0 }
    }
    $corbeilleGo = 0
    try {
        $shell = New-Object -ComObject Shell.Application
        $items = $shell.Namespace(0xA).Items()
        $total = 0; foreach ($i in $items) { $total += $i.Size }
        $corbeilleGo = [math]::Round($total / 1GB, 2)
    } catch {}
    $postes = [ordered]@{
        tempUtilisateurGo = TailleGo $env:TEMP
        tempWindowsGo     = TailleGo 'C:\Windows\Temp'
        cacheWindowsUpdateGo = TailleGo 'C:\Windows\SoftwareDistribution\Download'
        corbeilleGo       = $corbeilleGo
        cacheChromeGo     = TailleGo (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Cache')
        cacheEdgeGo       = TailleGo (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Cache')
    }
    $postes.totalGo = [math]::Round(($postes.Values | Measure-Object -Sum).Sum, 2)
    $postes
}

# ------------------------------------------------------------------ 7. Reseau
$donnees.reseau = Invoke-Section 'Reseau' {
    $cible = '1.1.1.1'
    $envoyes = 10; $recus = 0; $latences = @()
    for ($i = 0; $i -lt $envoyes; $i++) {
        try {
            $r = Test-Connection -ComputerName $cible -Count 1 -ErrorAction Stop
            $recus++
            $lat = $null
            if ($r.PSObject.Properties['ResponseTime']) { $lat = $r.ResponseTime }
            elseif ($r.PSObject.Properties['Latency'])  { $lat = $r.Latency }
            if ($null -ne $lat) { $latences += [double]$lat }
        } catch {}
    }
    $dnsMs = $null
    try { $dnsMs = [math]::Round((Measure-Command { Resolve-DnsName 'www.google.com' -ErrorAction Stop }).TotalMilliseconds) } catch {}
    $adaptateurs = Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        @{ nom = $_.Name; description = $_.InterfaceDescription; vitesseLien = $_.LinkSpeed }
    }
    @{
        cible            = $cible
        pertePct         = [math]::Round(100 * ($envoyes - $recus) / $envoyes)
        latenceMoyMs     = if ($latences) { [math]::Round(($latences | Measure-Object -Average).Average, 1) } else { $null }
        dnsMs            = $dnsMs
        adaptateursActifs = @($adaptateurs)
    }
}

# ------------------------------------------------------------- 8. Applications
$donnees.applications = Invoke-Section 'Mises a jour applications (winget)' {
    $brut = winget upgrade --accept-source-agreements 2>$null | Out-String
    @{ wingetUpgradeBrut = $brut.Trim() }
}

# ------------------------------------------------------- 9. Journal evenements
$donnees.evenements = Invoke-Section 'Journaux Windows (24h)' {
    $depuis = (Get-Date).AddDays(-1)
    function Compter($filtre) {
        try { @(Get-WinEvent -FilterHashtable $filtre -MaxEvents 200 -ErrorAction Stop).Count } catch { 0 }
    }
    $critSys = @()
    try {
        $critSys = Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1,2; StartTime=$depuis } -MaxEvents 30 -ErrorAction Stop |
            ForEach-Object { @{ source = $_.ProviderName; id = $_.Id; heure = $_.TimeCreated.ToString('s'); message = ($_.Message -split "`n")[0] } }
    } catch {}
    $erreursDisque = Compter @{ LogName='System'; ProviderName='disk','Ntfs','storahci','stornvme'; Level=1,2,3; StartTime=$depuis }
    $kernelPower41 = Compter @{ LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=41; StartTime=$depuis }
    $bugCheck      = Compter @{ LogName='System'; ProviderName='Microsoft-Windows-WER-SystemErrorReporting'; Id=1001; StartTime=$depuis }
    $whea7j        = Compter @{ LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddDays(-7) }
    $minidumps = @()
    if (Test-Path 'C:\Windows\Minidump') {
        $minidumps = Get-ChildItem 'C:\Windows\Minidump' -Filter *.dmp -ErrorAction SilentlyContinue |
            Where-Object LastWriteTime -gt $depuis | ForEach-Object { $_.Name }
    }
    @{
        erreursCritiques24h = @($critSys)
        nbErreursCritiques24h = @($critSys).Count
        erreursDisque24h    = $erreursDisque
        arretsInattendus24h = $kernelPower41
        bsod24h             = $bugCheck + @($minidumps).Count
        minidumps24h        = @($minidumps)
        erreursMaterielWhea7j = $whea7j
    }
}

# --------------------------------------------------------------------- Sortie
$json = $donnees | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($sortie, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[collecte] Termine -> $sortie"
