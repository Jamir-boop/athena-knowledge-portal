[CmdletBinding()]
param(
    [string]$ProjectName = 'athena-knowledge-portal',
    [uri]$SiteUrl = 'https://athena-knowledge-portal.pages.dev/'
)

$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
Push-Location $project
try {
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    try { $response = $client.GetAsync($SiteUrl).GetAwaiter().GetResult() }
    finally { $client.Dispose(); $handler.Dispose() }
    $redirect = if ($response.Headers.Location) { [uri]::new($SiteUrl, $response.Headers.Location) } else { $null }
    $accessProtected = [int]$response.StatusCode -in 301, 302, 303, 307, 308 -and $redirect -and (
        $redirect.Host.EndsWith('.cloudflareaccess.com', [StringComparison]::OrdinalIgnoreCase) -or
        $redirect.AbsolutePath.StartsWith('/cdn-cgi/access', [StringComparison]::OrdinalIgnoreCase)
    )
    if (-not $accessProtected) {
        throw "Cloudflare Access is not protecting $SiteUrl. Downloads were not built or deployed."
    }

    if (-not (Test-Path -LiteralPath (Join-Path $project 'node_modules'))) { npm ci; if ($LASTEXITCODE) { throw 'npm ci failed.' } }
    pwsh -NoProfile -NonInteractive -File (Join-Path $project 'scripts\build.ps1')
    if ($LASTEXITCODE) { throw 'Build failed.' }
    npx wrangler pages deploy dist --project-name $ProjectName --branch production
    if ($LASTEXITCODE) { throw 'Cloudflare Pages deployment failed.' }
} finally {
    Pop-Location
}
