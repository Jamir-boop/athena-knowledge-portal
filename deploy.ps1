[CmdletBinding()]
param(
    [string]$ProjectName = 'athena-knowledge-portal'
)

$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
Push-Location $project
try {
    if (-not (Test-Path -LiteralPath (Join-Path $project 'node_modules'))) { npm ci; if ($LASTEXITCODE) { throw 'npm ci failed.' } }
    & (Join-Path $project 'scripts\build.ps1')
    npm test
    if ($LASTEXITCODE) { throw 'Download proxy tests failed.' }

    $secretFile = Join-Path $project '.secrets\onedrive-links.json'
    if (Test-Path -LiteralPath $secretFile) {
        Get-Content -LiteralPath $secretFile -Raw | npx wrangler pages secret put ONEDRIVE_LINKS --project-name $ProjectName
        if ($LASTEXITCODE) { throw 'Cloudflare rejected the download secret.' }
    } else {
        Write-Warning 'No OneDrive links are configured. Downloads will stay marked as pending.'
    }

    npx wrangler pages deploy dist --project-name $ProjectName --branch production
    if ($LASTEXITCODE) { throw 'Cloudflare Pages deployment failed.' }
} finally {
    Pop-Location
}
