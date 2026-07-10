# sync-skills.ps1
# Hook SessionStart : synchronise TOUTES les Databricks Agent Skills officielles dans .claude/skills/
# (toujours a jour, automatiquement, sans action utilisateur) puis emet un statut CLI/auth que Claude lit.
#
# Concu pour etre RAPIDE et NON BLOQUANT : en cas d'echec (hors-ligne, git absent...), on conserve les
# skills deja presentes et on ne bloque jamais le demarrage de la session.
#
# Windows / PowerShell uniquement (choix projet).

# NB PowerShell 5.1 : on NE met PAS ErrorActionPreference sur 'Stop' globalement, car la sortie stderr
# de git (progression "Cloning into...") serait alors transformee en erreur terminale. On verifie
# plutot $LASTEXITCODE apres chaque appel natif (voir Invoke-Git).
$ErrorActionPreference = 'Continue'

# Racine du projet fournie par Claude Code ; fallback sur le dossier parent du script.
$projectDir = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$repoUrl   = 'https://github.com/databricks/databricks-agent-skills.git'
$cacheDir  = Join-Path $projectDir '.claude\.cache\databricks-agent-skills'
$skillsDir = Join-Path $projectDir '.claude\skills'
$stampFile = Join-Path $projectDir '.claude\.cache\last-sync-sha.txt'

# Lignes de statut accumulees puis imprimees en fin (stdout => vu par Claude au demarrage).
$status = New-Object System.Collections.Generic.List[string]

function Test-CommandExists([string]$name) {
    $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

# Lance git en capturant sortie + code retour, sans que la stderr de git ne provoque d'erreur terminale.
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $output = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') a echoue (code $LASTEXITCODE) : $output"
    }
    return $output
}

# --- 1/3 : Synchronisation des skills -------------------------------------------------
try {
    if (-not (Test-CommandExists 'git')) {
        throw 'git introuvable sur le PATH'
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cacheDir) | Out-Null

    if (-not (Test-Path (Join-Path $cacheDir '.git'))) {
        # Premier remplissage : clone shallow. core.longpaths contourne le bug Windows "Filename too long".
        Invoke-Git -c core.longpaths=true clone --quiet --depth 1 $repoUrl $cacheDir | Out-Null
    } else {
        # Mise a jour : fetch shallow + reset dur sur la branche par defaut distante.
        Invoke-Git -C $cacheDir -c core.longpaths=true fetch --quiet --depth 1 origin | Out-Null
        $defaultRef = (& git -C $cacheDir symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null)
        if ([string]::IsNullOrWhiteSpace($defaultRef)) { $defaultRef = 'origin/main' }
        Invoke-Git -C $cacheDir -c core.longpaths=true reset --hard --quiet $defaultRef | Out-Null
    }

    $sourceSkills = Join-Path $cacheDir 'skills'
    if (-not (Test-Path $sourceSkills)) {
        throw "dossier 'skills/' absent dans le repo synchronise"
    }

    $headSha = (& git -C $cacheDir rev-parse HEAD 2>$null)
    $shortSha = $headSha.Substring(0, [Math]::Min(7, $headSha.Length))
    $lastSha = if (Test-Path $stampFile) { (Get-Content $stampFile -Raw).Trim() } else { '' }
    $skillsPresent = (Test-Path $skillsDir) -and ((Get-ChildItem $skillsDir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)

    if ($headSha -eq $lastSha -and $skillsPresent) {
        # Rien n'a change cote officiel et les skills sont deja en place : on evite le robocopy (rapide).
        $count = (Get-ChildItem $skillsDir -Directory | Measure-Object).Count
        $status.Add("[skills] Deja a jour ($count skills, officiel @ $shortSha).")
    } else {
        New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
        # Recopie TOUTES les skills (miroir par skill : robocopy /MIR aligne .claude/skills/ sur la source).
        # robocopy renvoie un code < 8 en cas de succes ; on l'ignore volontairement.
        $count = 0
        Get-ChildItem -Path $sourceSkills -Directory | ForEach-Object {
            $dest = Join-Path $skillsDir $_.Name
            & robocopy $_.FullName $dest /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1 *>$null
            $count++
        }
        $headSha | Set-Content -Path $stampFile -Encoding utf8 -NoNewline
        $status.Add("[skills] $count skills Databricks synchronisees (officiel @ $shortSha).")
    }
}
catch {
    $existing = 0
    if (Test-Path $skillsDir) {
        $existing = (Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    }
    if ($existing -gt 0) {
        $status.Add("[skills] Synchro impossible ($($_.Exception.Message)). $existing skills deja en cache conservees.")
    } else {
        $status.Add("[skills] Synchro impossible ($($_.Exception.Message)) et aucune skill en cache. Verifier la connexion / git.")
    }
}

# --- 2/3 : Etat du CLI Databricks -----------------------------------------------------
$cliOk = Test-CommandExists 'databricks'
if ($cliOk) {
    $ver = (& databricks version 2>$null)
    $status.Add("[cli] Databricks CLI present ($ver).")
} else {
    $status.Add('[cli] Databricks CLI ABSENT. Onboarding requis : winget install Databricks.DatabricksCLI')
}

# --- 3/3 : Etat de l'authentification -------------------------------------------------
$authOk = $false
if ($cliOk) {
    try {
        $me = (& databricks current-user me 2>$null | Out-String)
        if ($me -match 'userName') { $authOk = $true }
    } catch { $authOk = $false }

    if ($authOk) {
        $status.Add('[auth] Authentifie sur Databricks (profil valide).')
    } else {
        $status.Add('[auth] NON authentifie. Onboarding requis : databricks auth login --host <url-workspace> (OAuth navigateur).')
    }
} else {
    $status.Add('[auth] Non verifiable (CLI absent).')
}

# --- 4/4 : Node.js (requis pour les apps React / AppKit) ------------------------------
$nodeOk = $false
if (Test-CommandExists 'node') {
    $nodeVer = (& node --version 2>$null)   # ex : v22.3.0
    $major = 0
    if ($nodeVer -match 'v(\d+)\.') { $major = [int]$Matches[1] }
    if ($major -ge 22) {
        $nodeOk = $true
        $status.Add("[node] Node.js $nodeVer present (OK pour AppKit/React).")
    } else {
        $status.Add("[node] Node.js $nodeVer trop ancien (< 22). AppKit requiert Node >= 22 : winget install OpenJS.NodeJS.LTS")
    }
} else {
    $status.Add('[node] Node.js ABSENT. Requis pour les apps React/AppKit : winget install OpenJS.NodeJS.LTS')
}

# --- Sortie : contexte injecte lu par Claude au demarrage -----------------------------
Write-Output '=== Etat environnement Databricks Demo (hook SessionStart) ==='
$status | ForEach-Object { Write-Output $_ }
if (-not $cliOk -or -not $authOk -or -not $nodeOk) {
    Write-Output '>> Action Claude : guider l''utilisateur pour l''etape d''onboarding manquante (voir CLAUDE.md).'
}
