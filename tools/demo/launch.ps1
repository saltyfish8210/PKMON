param([ValidateRange(0,65535)][int]$Port = 4191, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$demoRoot = $PSScriptRoot
$java = Join-Path $demoRoot 'runtime\bin\java.exe'
if (-not (Test-Path -LiteralPath $java)) {
    if ($env:JAVA_HOME) { $java = Join-Path $env:JAVA_HOME 'bin\java.exe' }
    if (-not (Test-Path -LiteralPath $java)) {
        $javaCommand = Get-Command java.exe -ErrorAction SilentlyContinue
        if (-not $javaCommand) { throw 'Java 17 is required. Use the package that includes runtime/.' }
        $java = $javaCommand.Source
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $demoRoot 'pkmon-demo.jar'))) {
    throw 'pkmon-demo.jar is missing. Extract the entire ZIP before starting.'
}
if ($Port -ne 0) {
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $probe.Start() }
    catch { Write-Host "Port $Port is busy. Selecting a free port; no other process will be stopped."; $Port = 0 }
    finally { $probe.Stop() }
}
$logDir = Join-Path $demoRoot 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$runName = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$stdout = Join-Path $logDir "$runName.out.log"
$stderr = Join-Path $logDir "$runName.err.log"
$argsList = @('-jar', 'pkmon-demo.jar', '--server.address=127.0.0.1', "--server.port=$Port",
    '--spring.profiles.active=dev', '--pkmon.capture.dev-user-header=false',
    '--pkmon.capture.dev-spawn-enabled=true', '--pkmon.study.rules.required-seconds=4',
    '--pkmon.study.rules.cooldown-seconds=0', '--spring.datasource.url=jdbc:h2:file:./data/pkmon-classroom')
$serverProcess = $null
try {
    $serverProcess = Start-Process -FilePath $java -ArgumentList $argsList -WorkingDirectory $demoRoot `
        -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    $url = $null
    while ([DateTime]::UtcNow -lt $deadline) {
        $serverProcess.Refresh()
        if ($serverProcess.HasExited) { throw "Server exited. Check $stdout and $stderr. Another copy may already be using this package's database." }
        if (Test-Path -LiteralPath $stdout) {
            $content = Get-Content -LiteralPath $stdout -Raw
            if ($content -match 'Tomcat started on port (\d+)') {
                $url = "http://127.0.0.1:$($Matches[1])/"
                break
            }
        }
        Start-Sleep -Milliseconds 300
    }
    if (-not $url) { throw "Startup timed out. Check $stdout" }
    Write-Host "PKMon is ready: $url"
    Write-Host 'Keep this window open. Press Enter here to stop this demo safely.'
    Write-Host 'Data is stored in data/. Do not delete it to restart a presentation.'
    if (-not $NoBrowser) { Start-Process $url }
    [void](Read-Host)
}
finally {
    if ($serverProcess) {
        $serverProcess.Refresh()
        if (-not $serverProcess.HasExited) {
            # Only the process created by this launch is stopped.
            Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue
            $serverProcess.WaitForExit()
        }
    }
}
