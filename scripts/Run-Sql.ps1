<#
.SYNOPSIS
  Execute un fichier .sql instruction par instruction sur un SQL Warehouse Databricks,
  via la Statement Execution API (a travers le CLI `databricks`). Sans dependance Python.

.DESCRIPTION
  - Decoupe le fichier sur ';' (pas de ';' dans les chaines de ce type de script).
  - Poll chaque instruction jusqu'a etat terminal ; stoppe a la premiere erreur.
  - Utilise pour : generer les fausses donnees (CTAS story-driven) et valider (SELECT).

.PARAMETER SqlFile      Chemin du fichier .sql.
.PARAMETER WarehouseId  Id du SQL Warehouse (ex : databricks warehouses list).
.PARAMETER Profile      Profil ~/.databrickscfg (optionnel).
.PARAMETER ShowResults  Affiche les lignes retournees (pour les SELECT de validation).

.EXAMPLE
  ./scripts/Run-Sql.ps1 -SqlFile demos/x/setup/generate_data.sql -WarehouseId 722773539c1f483b
  ./scripts/Run-Sql.ps1 -SqlFile checks.sql -WarehouseId 722... -ShowResults
#>
param(
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$WarehouseId,
    [string]$Profile,
    [switch]$ShowResults
)

# En PS 5.1 la stderr d'un exe natif peut lever une erreur terminale : on reste en 'Continue'
# et on verifie le contenu JSON / l'etat retourne nous-memes.
$ErrorActionPreference = 'Continue'

function Invoke-DbxApi {
    param([string]$Method, [string]$Path, [hashtable]$Payload)
    $args = @('api', $Method, $Path)
    if ($Profile) { $args += @('--profile', $Profile) }
    $tmp = $null
    if ($Payload) {
        $tmp = [System.IO.Path]::GetTempFileName()
        # UTF-8 SANS BOM : Set-Content -Encoding utf8 (PS 5.1) ajoute un BOM que le CLI rejette.
        [System.IO.File]::WriteAllText($tmp, ($Payload | ConvertTo-Json -Compress -Depth 6), [System.Text.UTF8Encoding]::new($false))
        $args += @('--json', "@$tmp")
    }
    try {
        $out = & databricks @args 2>&1 | Out-String
    } finally {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Force }
    }
    try { return $out | ConvertFrom-Json }
    catch { throw "Reponse CLI non-JSON : $out" }
}

function Invoke-Statement {
    param([string]$Sql)
    $resp = Invoke-DbxApi 'post' '/api/2.0/sql/statements' @{ warehouse_id = $WarehouseId; statement = $Sql; wait_timeout = '50s' }
    $id = $resp.statement_id
    while ($resp.status.state -in @('PENDING', 'RUNNING')) {
        Start-Sleep -Seconds 3
        $resp = Invoke-DbxApi 'get' "/api/2.0/sql/statements/$id"
    }
    if ($resp.status.state -ne 'SUCCEEDED') {
        throw "Etat $($resp.status.state) : $($resp.status.error.message)"
    }
    return $resp
}

if (-not (Test-Path $SqlFile)) { throw "Fichier introuvable : $SqlFile" }

# Retirer les lignes de commentaire pleines puis decouper sur ';'
$raw = Get-Content -Path $SqlFile -Raw
$noComments = ($raw -split "`n" | Where-Object { $_.TrimStart() -notlike '--*' }) -join "`n"
$statements = $noComments -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

Write-Output "$($statements.Count) instruction(s) sur le warehouse $WarehouseId`n"
$i = 0
foreach ($stmt in $statements) {
    $i++
    $label = ($stmt -replace '\s+', ' ').Substring(0, [Math]::Min(70, $stmt.Length))
    Write-Output "[$i/$($statements.Count)] $label ..."
    $resp = Invoke-Statement $stmt
    if ($ShowResults -and $resp.result -and $resp.result.data_array) {
        $cols = ($resp.manifest.schema.columns | ForEach-Object { $_.name }) -join ' | '
        Write-Output "    $cols"
        foreach ($row in $resp.result.data_array) {
            Write-Output "    $(($row | ForEach-Object { if ($null -eq $_) { '' } else { "$_" } }) -join ' | ')"
        }
    } else {
        Write-Output "    OK"
    }
}
Write-Output "`nTermine."
