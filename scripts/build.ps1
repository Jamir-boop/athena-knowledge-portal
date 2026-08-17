[CmdletBinding()]
param(
    [string]$Source = 'C:\Users\superuser\OneDrive\dev\framework'
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Athena builds require PowerShell 7 (pwsh) so UTF-8 text is decoded correctly.'
}
$project = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $project 'dist'
$sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')

if (-not $dist.StartsWith($project, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The output directory is outside the project.'
}
if (Test-Path -LiteralPath $dist) {
    Remove-Item -LiteralPath $dist -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dist, (Join-Path $dist 'content'), (Join-Path $dist 'vendor'), (Join-Path $dist 'fonts'), (Join-Path $dist 'assets') | Out-Null

Copy-Item -LiteralPath (Join-Path $project 'src\index.html'), (Join-Path $project 'src\styles.css'), (Join-Path $project 'src\config.js'), (Join-Path $project 'src\app.js'), (Join-Path $project 'src\_headers'), (Join-Path $project 'src\_routes.json') -Destination $dist
Copy-Item -LiteralPath (Join-Path $project 'node_modules\docsify\lib\docsify.min.js') -Destination (Join-Path $dist 'vendor\docsify.min.js')
Copy-Item -LiteralPath (Join-Path $project 'node_modules\docsify\lib\plugins\search.min.js') -Destination (Join-Path $dist 'vendor\search.min.js')
Copy-Item -LiteralPath (Join-Path $project 'node_modules\docsify\lib\themes\vue.css') -Destination (Join-Path $dist 'vendor\vue.css')
$themePath = Join-Path $dist 'vendor\vue.css'
$themeCss = [IO.File]::ReadAllText($themePath, [Text.Encoding]::UTF8).Replace('#34495e', '#ffb900')
[IO.File]::WriteAllText($themePath, $themeCss, [Text.UTF8Encoding]::new($false))
Copy-Item -Path (Join-Path $project 'src\fonts\*') -Destination (Join-Path $dist 'fonts')
Copy-Item -Path (Join-Path $project 'src\assets\*') -Destination (Join-Path $dist 'assets')

function Get-Key([string]$relativePath) {
    $name = [IO.Path]::GetFileNameWithoutExtension($relativePath).ToLowerInvariant()
    $slug = ($name -replace '[^a-z0-9]+', '-').Trim('-')
    if (-not $slug) { $slug = 'archivo' }
    if ($slug.Length -gt 42) { $slug = $slug.Substring(0, 42).TrimEnd('-') }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($relativePath.ToLowerInvariant()))).Replace('-', '').Substring(0, 8).ToLowerInvariant() }
    finally { $sha.Dispose() }
    return "$slug-$hash"
}

function Get-Section([string]$relativePath) {
    if ($relativePath.StartsWith('docs\', [StringComparison]::OrdinalIgnoreCase)) { return 'Guías' }
    if ($relativePath.StartsWith('packages\', [StringComparison]::OrdinalIgnoreCase)) { return 'Paquetes' }
    if ($relativePath.StartsWith('ejercicios\', [StringComparison]::OrdinalIgnoreCase)) { return 'Ejercicios' }
    if ($relativePath.StartsWith('versiones anteriores\', [StringComparison]::OrdinalIgnoreCase)) { return 'Archivo' }
    return 'Framework'
}

function Format-Size([long]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N2} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N1} KB' -f ($bytes / 1KB)) }
    return "$bytes B"
}

$configured = @{}
$secretFile = Join-Path $project '.secrets\onedrive-links.json'
if (Test-Path -LiteralPath $secretFile) {
    $secretObject = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
    foreach ($property in $secretObject.PSObject.Properties) { $configured[$property.Name] = $true }
}

$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse | Sort-Object FullName)
$catalog = foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
    [pscustomobject]@{
        key = Get-Key $relative
        name = $file.Name
        section = Get-Section $relative
        relativePath = $relative
        bytes = $file.Length
        size = Format-Size $file.Length
        available = $configured.ContainsKey((Get-Key $relative))
    }
}

$catalog | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $dist 'catalog.json') -Encoding utf8

function Get-ArticleSlug([string]$name) {
    $slug = ([IO.Path]::GetFileNameWithoutExtension($name).ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if (-not $slug) { throw "Article filename cannot produce a route: $name" }
    return $slug
}

$articleConfig = @{
    'guia_implementacion_core_framework.md' = @{ Target = 'core-framework.md'; Title = 'Implementación de Core Framework' }
    'guia-errores-capture-AA.md' = @{ Target = 'errores-capture.md'; Title = 'Problemas de captura en Automation Anywhere' }
    'cheasheet DOMXPath patterns.md' = @{ Target = 'domxpath.md'; Title = 'Patrones DOMXPath' }
    'contributing.md' = @{ Target = 'contributing.md'; Title = 'Cómo contribuir' }
}

$articleFiles = @($sourceFiles | Where-Object {
    $_.Extension -eq '.md' -and $_.FullName.StartsWith((Join-Path $sourceRoot 'docs\'), [StringComparison]::OrdinalIgnoreCase)
})
$articles = foreach ($file in $articleFiles) {
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
    $body = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    $configuredArticle = $articleConfig[$file.Name]
    $target = if ($configuredArticle) { $configuredArticle.Target } else { "$(Get-ArticleSlug $file.Name).md" }
    $heading = [regex]::Match($body, '(?m)^#\s+(.+?)\s*$')
    $title = if ($configuredArticle) { $configuredArticle.Title } elseif ($heading.Success) { $heading.Groups[1].Value } else { [IO.Path]::GetFileNameWithoutExtension($file.Name) }
    $bodyWithoutTitle = [regex]::Replace($body, '\A(?:\uFEFF)?\s*#\s+[^\r\n]+\r?\n+', '')
    $sourcePath = [Net.WebUtility]::HtmlEncode($relative)
    $sourceNote = "<p class=`"source-note`">Fuente canónica: <code>$sourcePath</code></p>"
    "# $title`n`n$sourceNote`n`n$bodyWithoutTitle" | Set-Content -LiteralPath (Join-Path $dist "content\$target") -Encoding utf8
    [pscustomobject]@{ Source = $relative; Target = $target; Title = $title }
}

$duplicateRoutes = @($articles | Group-Object Target | Where-Object Count -gt 1)
if ($duplicateRoutes) { throw "Two articles produce the same route: $($duplicateRoutes.Name -join ', ')" }

$archiveSource = 'versiones anteriores\README-old.md'
$archiveGuideExists = Test-Path -LiteralPath (Join-Path $sourceRoot $archiveSource)
if ($archiveGuideExists) {
    $archiveBody = Get-Content -LiteralPath (Join-Path $sourceRoot $archiveSource) -Raw -Encoding utf8
    $archiveBody = [regex]::Replace($archiveBody, '\A(?:\uFEFF)?\s*#\s+[^\r\n]+\r?\n+', '')
    "# Framework anterior`n`n<p class=`"source-note`">Fuente canónica: <code>$archiveSource</code></p>`n`n$archiveBody" | Set-Content -LiteralPath (Join-Path $dist 'content\framework-anterior.md') -Encoding utf8
}

function New-CatalogPage([string]$title, [string]$intro, [object[]]$items) {
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("# $title")
    $lines.Add('')
    $lines.Add($intro)
    $lines.Add('')
    $lines.Add('<div class="catalog-list">')
    foreach ($item in $items) {
        $name = [Net.WebUtility]::HtmlEncode($item.name)
        $path = [Net.WebUtility]::HtmlEncode($item.relativePath)
        $lines.Add('<article class="catalog-item">')
        $lines.Add("<div><strong>$name</strong><small>$($item.size)</small><code>$path</code></div>")
        if ($item.available) {
            $lines.Add("<a class=`"download-link`" href=`"/download/$($item.key)`" download=`"$name`">Descargar</a>")
        } else {
            $lines.Add('<span class="download-pending" aria-label="Enlace pendiente">Pendiente</span>')
        }
        $lines.Add('</article>')
    }
    $lines.Add('</div>')
    return $lines -join "`n"
}

$pages = [ordered]@{
    'framework.md' = @{ Title = 'Framework'; Intro = 'La versión actual del Core Framework.'; Section = 'Framework' }
    'packages.md' = @{ Title = 'Paquetes'; Intro = 'Paquetes adicionales usados por los bots.'; Section = 'Paquetes' }
    'exercises.md' = @{ Title = 'Ejercicios'; Intro = 'Material práctico y datos de ejemplo.'; Section = 'Ejercicios' }
    'archive.md' = @{ Title = 'Archivo'; Intro = 'Versiones anteriores. Use la versión actual salvo que necesite reproducir un entorno histórico.'; Section = 'Archivo' }
    'downloads.md' = @{ Title = 'Todas las descargas'; Intro = 'Inventario completo del repositorio canónico.'; Section = $null }
}
foreach ($page in $pages.GetEnumerator()) {
    $items = if ($page.Value.Section) { @($catalog | Where-Object section -eq $page.Value.Section) } else { @($catalog) }
    New-CatalogPage $page.Value.Title $page.Value.Intro $items | Set-Content -LiteralPath (Join-Path $dist $page.Key) -Encoding utf8
}

@'
<section class="hero">
  <div class="hero-copy">
    <h1>Athena</h1>
    <p>Guías, framework, paquetes y ejercicios de Automation Anywhere en un solo lugar.</p>
  </div>
  <img src="/assets/athena-dither.webp" alt="" width="900" height="900">
</section>

## Explorar

<div class="portal-grid">
  <a class="portal-card" href="#/content/core-framework"><span>Core Framework</span><p>Implementación y operación del template actual.</p></a>
  <a class="portal-card" href="#/packages"><span>Paquetes</span><p>JAR, utilidades y complementos.</p></a>
  <a class="portal-card" href="#/exercises"><span>Ejercicios</span><p>Material para probar el flujo completo.</p></a>
  <a class="portal-card" href="#/archive"><span>Archivo</span><p>Versiones anteriores, claramente separadas.</p></a>
</div>

<div class="contribute-note"><p>¿Documentaste una solución que el equipo puede volver a usar?</p><a href="#/content/contributing">Cómo contribuir</a></div>

> Los archivos marcados como **Pendiente** no tienen todavía un vínculo privado configurado en Athena.
'@ | Set-Content -LiteralPath (Join-Path $dist 'README.md') -Encoding utf8

$sidebar = [Collections.Generic.List[string]]::new()
$sidebar.Add('- **Inicio**')
$sidebar.Add('  - [Athena](/)')
$sidebar.Add('- **Guías**')
foreach ($article in $articles | Where-Object Target -ne 'contributing.md' | Sort-Object Title) {
    $sidebar.Add("  - [$($article.Title)](/content/$($article.Target))")
}
$sidebar.Add('- **Recursos**')
$sidebar.Add('  - [Framework](/framework.md)')
$sidebar.Add('  - [Paquetes](/packages.md)')
$sidebar.Add('  - [Ejercicios](/exercises.md)')
$sidebar.Add('  - [Todas las descargas](/downloads.md)')
$sidebar.Add('- **Participar**')
$sidebar.Add('  - [Cómo contribuir](/content/contributing.md)')
$sidebar.Add('- **Archivo**')
$sidebar.Add('  - [Versiones anteriores](/archive.md)')
if ($archiveGuideExists) { $sidebar.Add('  - [Guía anterior](/content/framework-anterior.md)') }
$sidebar -join "`n" | Set-Content -LiteralPath (Join-Path $dist '_sidebar.md') -Encoding utf8

$largeOutput = Get-ChildItem -LiteralPath $dist -File -Recurse | Where-Object Length -ge 25MB
if ($largeOutput) { throw "Pages output contains a file of 25 MB or more: $($largeOutput.FullName -join ', ')" }
if ($catalog.Count -ne $sourceFiles.Count) { throw "Catalog count does not match the source inventory." }
$publicFiles = Get-ChildItem -LiteralPath $dist -File -Recurse
$publicTextFiles = $publicFiles | Where-Object Extension -in '.css', '.html', '.js', '.json', '.md'
$mojibakePattern = '[\u00C2\u00C3][\u0080-\u00BF]|\u00E2\u20AC.|\uFFFD'
$badEncoding = $publicTextFiles | Where-Object {
    [regex]::IsMatch([IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8), $mojibakePattern)
}
if ($badEncoding) {
    throw "Generated text contains invalid UTF-8 or mojibake: $($badEncoding.FullName -join ', ')"
}
if ($publicTextFiles | Select-String -SimpleMatch '#34495e' -ErrorAction SilentlyContinue) {
    throw 'The deprecated low-contrast color #34495e remains in the public output.'
}
if ($publicTextFiles | Select-String -Pattern '1drv\.ms|onedrive\.live\.com' -ErrorAction SilentlyContinue) {
    throw 'A OneDrive origin URL was written into the public output.'
}

Write-Host "Built Athena with $($articles.Count) articles, $($catalog.Count) catalog entries, and $($configured.Count) configured downloads."
