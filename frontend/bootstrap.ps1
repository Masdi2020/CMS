$ErrorActionPreference = 'Stop'
$frontendRoot = $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
    throw 'Flutter SDK tidak ditemukan. Instal Flutter dan tambahkan folder bin ke PATH, lalu jalankan ulang skrip ini.'
}
$androidPath = Join-Path $frontendRoot 'android'
if (-not (Test-Path -LiteralPath $androidPath)) {
    $templatePath = Join-Path (Split-Path $frontendRoot -Parent) '.local/flutter-template'
    if (Test-Path -LiteralPath $templatePath) {
        throw 'Folder .local/flutter-template sudah ada. Periksa hasil inisialisasi sebelumnya sebelum menjalankan ulang.'
    }
    & $flutterCommand.Source create --platforms=android --org=id.cms --project-name=cms_mobile --empty --no-pub $templatePath
    if ($LASTEXITCODE -ne 0) { throw 'flutter create gagal.' }
    Copy-Item -LiteralPath (Join-Path $templatePath 'android') -Destination $androidPath -Recurse
    Copy-Item -LiteralPath (Join-Path $templatePath '.metadata') -Destination $frontendRoot
}
$manifestPath = Join-Path $androidPath 'app/src/main/AndroidManifest.xml'
[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
$androidNamespace = 'http://schemas.android.com/apk/res/android'
if (-not ($manifest.manifest.'uses-permission' | Where-Object { $_.GetAttribute('name', $androidNamespace) -eq 'android.permission.INTERNET' })) {
    $permission = $manifest.CreateElement('uses-permission')
    $permission.SetAttribute('name', $androidNamespace, 'android.permission.INTERNET')
    [void]$manifest.manifest.PrependChild($permission)
}
$manifest.manifest.application.SetAttribute('label', $androidNamespace, 'CMS')
$manifest.Save($manifestPath)
$debugPath = Join-Path $androidPath 'app/src/debug/AndroidManifest.xml'
[xml]$debugManifest = Get-Content -LiteralPath $debugPath -Raw
$debugApplication = $debugManifest.manifest.SelectSingleNode('application')
if (-not $debugApplication) {
    $debugApplication = $debugManifest.CreateElement('application')
    [void]$debugManifest.manifest.AppendChild($debugApplication)
}
$debugApplication.SetAttribute('usesCleartextTraffic', $androidNamespace, 'true')
$debugManifest.Save($debugPath)
Push-Location $frontendRoot
try {
    & $flutterCommand.Source pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get gagal.' }
    & $flutterCommand.Source analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze gagal.' }
} finally {
    Pop-Location
}
