[CmdletBinding()]
param([int]$GuideCount = 120)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "athena-scale-$([guid]::NewGuid().ToString('N'))"
$docs = Join-Path $testRoot 'docs'
New-Item -ItemType Directory -Path $docs | Out-Null

try {
    foreach ($number in 1..$GuideCount) {
        $slug = 'guide-{0:d3}' -f $number
        $markdown = "<!-- athena: {`"kind`":`"guide`",`"date`":`"2026-08-19`",`"author`":`"Scale Test`",`"summary`":`"Synthetic guide $number`",`"tags`":[`"Test`"],`"slug`":`"$slug`"} -->`n# Synthetic guide $number`n`nSearchable content $number.`n"
        [IO.File]::WriteAllText((Join-Path $docs "$slug.md"), $markdown, [Text.UTF8Encoding]::new($false))
    }

    & (Join-Path $PSScriptRoot 'build.ps1') -Source $testRoot -IgnoreLinks
    $contentCount = @(Get-ChildItem -LiteralPath (Join-Path $project 'dist\content') -Filter '*.md').Count
    $guides = [IO.File]::ReadAllText((Join-Path $project 'dist\guides.md'), [Text.Encoding]::UTF8)
    $config = [IO.File]::ReadAllText((Join-Path $project 'dist\config.js'), [Text.Encoding]::UTF8)
    if ($contentCount -ne $GuideCount) { throw "Expected $GuideCount content routes, found $contentCount." }
    if ([regex]::Matches($guides, 'class="library-card"').Count -ne $GuideCount) { throw 'The Guides card count is incorrect.' }
    if ([regex]::Matches($config, '"/content/guide-').Count -ne $GuideCount) { throw 'The explicit search-path count is incorrect.' }
    Write-Host "Scale check passed with $GuideCount guides."
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedTestRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove a test directory outside the system temp directory.' }
    if (Test-Path -LiteralPath $resolvedTestRoot) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force }
}
