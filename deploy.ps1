[CmdletBinding()]
param(
    [string]$ProjectName = 'athena-knowledge-portal'
)

$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
Push-Location $project
try {
    if (-not (Test-Path -LiteralPath (Join-Path $project 'node_modules'))) { npm ci; if ($LASTEXITCODE) { throw 'npm ci failed.' } }
    pwsh -NoProfile -NonInteractive -File (Join-Path $project 'scripts\build.ps1')
    if ($LASTEXITCODE) { throw 'Build failed.' }
    npx wrangler pages deploy dist --project-name $ProjectName --branch production
    if ($LASTEXITCODE) { throw 'Cloudflare Pages deployment failed.' }
} finally {
    Pop-Location
}
