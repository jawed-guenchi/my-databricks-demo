# setup-node.ps1
# Installe Node.js v22 en mode PORTABLE (sans droits administrateur) pour AppKit/React.
#
# Pourquoi : `winget install OpenJS.NodeJS` exige une elevation admin (fenetre UAC) souvent
# bloquee sur les postes d'entreprise. Cette methode telecharge l'archive officielle et
# l'extrait dans le profil utilisateur, puis l'ajoute au PATH utilisateur. Aucun admin requis.
#
# Idempotent : si un Node >= 22 est deja disponible, ne fait rien.

$ErrorActionPreference = 'Stop'

function Get-NodeMajor {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $cmd) { return 0 }
    try {
        $v = & node --version 2>$null   # ex : v22.3.0
        if ($v -match 'v(\d+)\.') { return [int]$Matches[1] }
    } catch {}
    return 0
}

# 1. Deja bon ?
$major = Get-NodeMajor
if ($major -ge 22) {
    Write-Output "Node.js deja present et suffisant (v$major). Rien a faire."
    return
}

# 2. Determiner la derniere v22 LTS
Write-Output "Node.js absent ou trop ancien. Installation portable (sans admin)..."
$idx = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -UseBasicParsing
$v22 = ($idx | Where-Object { $_.version -like 'v22.*' } | Select-Object -First 1).version
if (-not $v22) { throw "Impossible de determiner une version Node v22." }

$zipUrl  = "https://nodejs.org/dist/$v22/node-$v22-win-x64.zip"
$destRoot = Join-Path $env:LOCALAPPDATA 'node-portable'
$zipPath = Join-Path $env:TEMP "node-$v22.zip"

# 3. Telecharger + extraire
Write-Output "Telechargement $zipUrl ..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
if (Test-Path $destRoot) { Remove-Item -Recurse -Force $destRoot }
Expand-Archive -Path $zipPath -DestinationPath $destRoot -Force
Remove-Item $zipPath -Force
$nodeDir = (Get-ChildItem $destRoot -Directory | Select-Object -First 1).FullName
Write-Output "Node.js extrait dans : $nodeDir"

# 4. Ajouter au PATH utilisateur (persistant, sans admin)
$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$nodeDir*") {
    [System.Environment]::SetEnvironmentVariable('Path', "$userPath;$nodeDir", 'User')
    Write-Output "Ajoute au PATH utilisateur."
}

# 5. Rendre dispo dans la session courante + verifier
$env:Path = "$nodeDir;$env:Path"
$nodeVer = & "$nodeDir\node.exe" --version
$npmVer  = & "$nodeDir\npm.cmd" --version
Write-Output "OK : node $nodeVer / npm $npmVer"
Write-Output ">> Node est pret. Dans un shell deja ouvert, ajoute '$nodeDir' au debut du PATH avant d'appeler node/npm."
