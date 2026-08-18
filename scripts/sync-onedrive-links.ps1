[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [string]$Source = 'C:\Users\superuser\OneDrive\dev\framework',
    [string]$OneDriveRoot = $env:OneDriveConsumer
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'This script requires PowerShell 7 (pwsh).'
}
if (-not $OneDriveRoot) { $OneDriveRoot = $env:OneDrive }
if (-not $OneDriveRoot) { throw 'OneDrive is not configured for this Windows user.' }

$project = Split-Path $PSScriptRoot -Parent
$sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
$driveRoot = (Resolve-Path -LiteralPath $OneDriveRoot).Path.TrimEnd('\')
if (-not $sourceRoot.StartsWith("$driveRoot\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "The source folder is not inside the configured OneDrive root: $driveRoot"
}

$requestedWhatIf = $WhatIfPreference
$WhatIfPreference = $false
try { & (Join-Path $PSScriptRoot 'build.ps1') -Source $sourceRoot }
finally { $WhatIfPreference = $requestedWhatIf }
$catalog = Get-Content -LiteralPath (Join-Path $project 'dist\catalog.json') -Raw | ConvertFrom-Json
$targets = @($catalog | Where-Object { [IO.Path]::GetExtension($_.relativePath).ToLowerInvariant() -in '.zip', '.jar', '.exe' })
if (-not $targets) { throw 'No ZIP, JAR, or EXE files were found.' }
if (-not $PSCmdlet.ShouldProcess("$($targets.Count) OneDrive files", 'Create anonymous read-only links and replace the local whitelist')) { return }

$moduleVersion = '2.39.0'
$moduleRoot = Join-Path $project '.tools\powershell'
$moduleManifest = Join-Path $moduleRoot "Microsoft.Graph.Authentication\$moduleVersion\Microsoft.Graph.Authentication.psd1"
if (-not (Test-Path -LiteralPath $moduleManifest)) {
    New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
    Write-Host 'Downloading the official Microsoft Graph authentication module into .tools...'
    Save-Module Microsoft.Graph.Authentication -RequiredVersion $moduleVersion -Repository PSGallery -Path $moduleRoot -AcceptLicense
}
Import-Module $moduleManifest -Force

$context = Get-MgContext
if (-not $context -or 'Files.ReadWrite' -notin $context.Scopes) {
    Connect-MgGraph -Scopes Files.ReadWrite -ContextScope CurrentUser -NoWelcome
}

$drive = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/me/drive?$select=driveType'
if ($drive.driveType -ne 'personal') {
    throw 'The Microsoft session is not connected to a personal OneDrive account.'
}

$links = [ordered]@{}
$position = 0
foreach ($target in $targets) {
    $position++
    Write-Progress -Activity 'Creating OneDrive download links' -Status "$position of $($targets.Count)" -PercentComplete (($position / $targets.Count) * 100)

    $localPath = (Resolve-Path -LiteralPath (Join-Path $sourceRoot $target.relativePath)).Path
    if (-not $localPath.StartsWith("$driveRoot\", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Catalog file is outside OneDrive: $($target.relativePath)"
    }
    $drivePath = $localPath.Substring($driveRoot.Length).TrimStart('\')
    $encodedPath = (($drivePath -split '\\' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
    $item = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me/drive/root:/$encodedPath"
    $permission = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/me/drive/items/$($item.id)/createLink" -Body (@{
        type = 'view'
        scope = 'anonymous'
    } | ConvertTo-Json -Compress) -ContentType 'application/json'

    $url = [uri]$permission.link.webUrl
    if ($permission.link.type -ne 'view' -or $permission.link.scope -ne 'anonymous' -or 'write' -in @($permission.roles)) {
        throw "OneDrive did not return a read-only anonymous link for $($target.relativePath)."
    }
    if ($url.Scheme -ne 'https' -or $url.Host.ToLowerInvariant() -notin '1drv.ms', 'onedrive.live.com') {
        throw "OneDrive returned an unexpected link host for $($target.relativePath)."
    }
    $links[$target.key] = $url.AbsoluteUri
}
Write-Progress -Activity 'Creating OneDrive download links' -Completed

$secretDirectory = Join-Path $project '.secrets'
$secretFile = Join-Path $secretDirectory 'onedrive-links.json'
New-Item -ItemType Directory -Force -Path $secretDirectory | Out-Null
$json = $links | ConvertTo-Json -Compress
$byteCount = [Text.Encoding]::UTF8.GetByteCount($json)
if ($byteCount -gt 4900) {
    throw 'The OneDrive link map exceeds the Cloudflare per-secret limit. No whitelist was changed.'
}
[IO.File]::WriteAllText($secretFile, $json, [Text.UTF8Encoding]::new($false))

Write-Host "Saved $($links.Count) approved download links in the private whitelist ($byteCount bytes)."
Write-Host 'Run .\deploy.ps1 to publish them.'
