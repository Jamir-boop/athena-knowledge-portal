[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{0,127}$')][string]$Key,
    [Parameter(Mandatory)][uri]$Url
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$catalogFile = Join-Path $project 'dist\catalog.json'
if (-not (Test-Path -LiteralPath $catalogFile)) {
    & (Join-Path $PSScriptRoot 'build.ps1')
}

$catalog = Get-Content -LiteralPath $catalogFile -Raw | ConvertFrom-Json
if (-not ($catalog.key -contains $Key)) { throw "Unknown catalog key: $Key" }
if ($Url.Scheme -ne 'https' -or $Url.Host.ToLowerInvariant() -notin @('1drv.ms', 'onedrive.live.com')) {
    throw 'Use an HTTPS anonymous sharing URL from 1drv.ms or onedrive.live.com.'
}

$secretDirectory = Join-Path $project '.secrets'
$secretFile = Join-Path $secretDirectory 'onedrive-links.json'
New-Item -ItemType Directory -Force -Path $secretDirectory | Out-Null
$links = @{}
if (Test-Path -LiteralPath $secretFile) {
    $existing = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
    foreach ($property in $existing.PSObject.Properties) { $links[$property.Name] = [string]$property.Value }
}
$links[$Key] = $Url.AbsoluteUri

$ordered = [ordered]@{}
foreach ($name in $links.Keys | Sort-Object) { $ordered[$name] = $links[$name] }
$json = $ordered | ConvertTo-Json -Compress
if ([Text.Encoding]::UTF8.GetByteCount($json) -gt 4900) {
    throw 'The OneDrive link secret is near the Cloudflare per-secret limit. Split storage before adding more links.'
}
[IO.File]::WriteAllText($secretFile, $json, [Text.UTF8Encoding]::new($false))

$item = $catalog | Where-Object key -eq $Key | Select-Object -First 1
Write-Host "Saved a private link for $($item.name). Run .\deploy.ps1 to publish it."
