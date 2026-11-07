param(
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$JavaHome,
    [switch]$Build,
    [string]$FlutterHome,
    [string]$MavenExecutable = 'mvn.cmd',
    [string]$MavenRepository,
    [switch]$IncludeRuntime
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputRoot) { throw "Output already exists; choose a new directory: $outputRoot" }
$env:JAVA_HOME = $JavaHome
$env:PATH = "$(Join-Path $JavaHome 'bin');$env:PATH"
if ($Build) {
    if (-not $FlutterHome) { throw 'Specify -FlutterHome when using -Build.' }
    Push-Location (Join-Path $repoRoot 'client')
    try {
        $flutter = Join-Path $FlutterHome 'bin\flutter.bat'
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed.' }
        & $flutter analyze --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
        & $flutter test --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
        & $flutter build web --release --no-web-resources-cdn --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed.' }
    } finally { Pop-Location }
    Push-Location $repoRoot
    try {
        $mavenArgs = @('-f', 'server/pom.xml', 'clean', 'verify')
        if ($MavenRepository) { $mavenArgs += "-Dmaven.repo.local=$MavenRepository" }
        & $MavenExecutable @mavenArgs
        if ($LASTEXITCODE -ne 0) { throw 'Maven verification failed.' }
    } finally { Pop-Location }
}
$web = Join-Path $repoRoot 'client\build\web'
$serverJar = Join-Path $repoRoot 'server\target\pkmon-server-0.1.0.jar'
if (-not (Test-Path -LiteralPath (Join-Path $web 'main.dart.js'))) { throw 'Build the Flutter Web release first.' }
if (-not (Test-Path -LiteralPath $serverJar)) { throw 'Build the server JAR first.' }
New-Item -ItemType Directory -Path $outputRoot | Out-Null
$targetJar = Join-Path $outputRoot 'pkmon-demo.jar'
Copy-Item -LiteralPath $serverJar -Destination $targetJar
$assetStage = Join-Path $outputRoot '.assets-stage'
$staticAssets = Join-Path $assetStage 'BOOT-INF\classes\static'
New-Item -ItemType Directory -Path $staticAssets -Force | Out-Null
Get-ChildItem -LiteralPath $web | Copy-Item -Destination $staticAssets -Recurse
# Use the JDK's archive tool so Spring Boot's nested JAR offsets stay valid.
& (Join-Path $JavaHome 'bin\jar.exe') --update --file $targetJar -C $assetStage BOOT-INF
if ($LASTEXITCODE -ne 0) { throw 'Embedding Web assets failed.' }
$resolvedStage = (Resolve-Path -LiteralPath $assetStage).Path
if (-not $resolvedStage.StartsWith($outputRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unexpected staging path; refusing cleanup.'
}
Remove-Item -LiteralPath $resolvedStage -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'launch.ps1') -Destination $outputRoot
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cmd' | Copy-Item -Destination $outputRoot
if ($IncludeRuntime) {
    & (Join-Path $JavaHome 'bin\jlink.exe') --add-modules java.se,jdk.crypto.ec,jdk.unsupported,jdk.zipfs `
        --strip-debug --no-header-files --no-man-pages --compress=2 --output (Join-Path $outputRoot 'runtime')
    if ($LASTEXITCODE -ne 0) { throw 'Runtime creation failed.' }
}
$revision = & git -C $repoRoot rev-parse HEAD
$dirty = [bool](& git -C $repoRoot status --porcelain)
[ordered]@{sourceCommit=$revision; hasLocalChanges=$dirty; jarSha256=(Get-FileHash -LiteralPath $targetJar -Algorithm SHA256).Hash;
    builtAt=(Get-Date).ToString('o'); platform='Windows x64'; profile='dev'; simulatedLocation=$true;
    dwellSeconds=4; cooldownSeconds=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'build-info.json') -Encoding UTF8
Write-Host "Created: $outputRoot"
