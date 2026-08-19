[CmdletBinding()]
param([int]$GuideCount = 120)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$build = Join-Path $PSScriptRoot 'build.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "athena-build-$([guid]::NewGuid().ToString('N'))"

function New-Source([string]$Name) {
    $root = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force | Out-Null
    return $root
}

function Write-Guide([string]$Root, [string]$Name, [string]$Metadata, [string]$Title = 'Test guide') {
    $markdown = "<!-- athena: $Metadata -->`n# $Title`n`nSearchable UTF-8 content: Guía de implementación.`n"
    [IO.File]::WriteAllText((Join-Path $Root "docs\$Name.md"), $markdown, [Text.UTF8Encoding]::new($false))
}

function Assert-BuildFails([string]$Root, [string]$Expected) {
    try {
        & $build -Source $Root -IgnoreLinks | Out-Null
    } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw "Expected '$Expected', got: $($_.Exception.Message)" }
        return
    }
    throw "Build unexpectedly passed; expected: $Expected"
}

New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
    $scale = New-Source 'scale'
    foreach ($number in 1..$GuideCount) {
        $slug = 'guide-{0:d3}' -f $number
        $metadata = "{`"kind`":`"guide`",`"date`":`"2026-08-19`",`"author`":`"Scale Test`",`"summary`":`"Synthetic guide $number`",`"tags`": [`"Test`"],`"slug`":`"$slug`"}"
        Write-Guide $scale $slug $metadata "Synthetic guide $number"
    }
    [IO.File]::WriteAllText((Join-Path $scale 'package.jar'), 'test', [Text.Encoding]::ASCII)
    [IO.File]::WriteAllBytes((Join-Path $scale 'docs\reference.pdf'), [Text.Encoding]::ASCII.GetBytes("%PDF-1.4`n%%EOF"))

    & $build -Source $scale -IgnoreLinks | Out-Null
    $dist = Join-Path $project 'dist'
    $contentCount = @(Get-ChildItem -LiteralPath (Join-Path $dist 'content') -Filter '*.md').Count
    $guides = [IO.File]::ReadAllText((Join-Path $dist 'guides.md'), [Text.Encoding]::UTF8)
    $config = [IO.File]::ReadAllText((Join-Path $dist 'config.js'), [Text.Encoding]::UTF8)
    $catalog = [IO.File]::ReadAllText((Join-Path $dist 'catalog.json'), [Text.Encoding]::UTF8)
    $firstGuide = [IO.File]::ReadAllText((Join-Path $dist 'content\guide-001.md'), [Text.Encoding]::UTF8)
    if ($contentCount -ne $GuideCount) { throw "Expected $GuideCount content routes, found $contentCount." }
    if ([regex]::Matches($guides, 'class="library-card"').Count -ne ($GuideCount + 1)) { throw 'The Guides card count is incorrect.' }
    if ([regex]::Matches($config, '"/content/guide-').Count -ne $GuideCount) { throw 'The explicit search-path count is incorrect.' }
    if ($guides -notmatch '<option value="PDF">PDF</option>' -or $guides -notmatch 'data-tags="PDF"') { throw 'Unmatched PDFs must have a selectable PDF tag.' }
    if (-not (Test-Path -LiteralPath (Join-Path $dist 'content\guide-001.md'))) { throw 'An existing guide route was not preserved.' }
    if ($firstGuide -notmatch 'Guía de implementación' -or $firstGuide -match 'GuÃ') { throw 'UTF-8 guide text was not preserved.' }
    if ($catalog -match '1drv\.ms|onedrive\.live\.com') { throw 'Private OneDrive links entered catalog.json.' }

    $scalar = New-Source 'scalar-tags'
    Write-Guide $scalar 'scalar' '{"kind":"guide","date":"2026-08-19","author":"Test","summary":"Test","tags":"Test","slug":"scalar"}'
    Assert-BuildFails $scalar 'Metadata tags must be an array'

    $escaped = New-Source 'escaped-pdf'
    [IO.File]::WriteAllBytes((Join-Path $escaped 'outside.pdf'), [Text.Encoding]::ASCII.GetBytes('%PDF-1.4'))
    Write-Guide $escaped 'escaped' '{"kind":"guide","date":"2026-08-19","author":"Test","summary":"Test","tags":[],"slug":"escaped","pdf":"../outside.pdf"}'
    Assert-BuildFails $escaped 'does not exist below docs'

    $missing = New-Source 'missing-pdf'
    Write-Guide $missing 'missing' '{"kind":"guide","date":"2026-08-19","author":"Test","summary":"Test","tags":[],"slug":"missing","pdf":"missing.pdf"}'
    Assert-BuildFails $missing 'does not exist below docs'

    $oversized = New-Source 'oversized-pdf'
    $stream = [IO.File]::Create((Join-Path $oversized 'docs\large.pdf'))
    try { $stream.SetLength(25MB) } finally { $stream.Dispose() }
    Assert-BuildFails $oversized 'PDF files must be smaller than 25 MiB'

    Write-Host "Build checks passed with $GuideCount guides and metadata, PDF, UTF-8, route, tag, and link regressions."
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $cleanupRelative = [IO.Path]::GetRelativePath($resolvedTemp, $resolvedTestRoot)
    $escapesTemp = [IO.Path]::IsPathRooted($cleanupRelative) -or $cleanupRelative -eq '..' -or $cleanupRelative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal) -or $cleanupRelative.StartsWith("..$([IO.Path]::AltDirectorySeparatorChar)", [StringComparison]::Ordinal)
    if ($escapesTemp) { throw 'Refusing to remove a test directory outside the system temp directory.' }
    if (Test-Path -LiteralPath $resolvedTestRoot) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force }
}
