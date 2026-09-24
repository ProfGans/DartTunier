param([switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $projectPath
try {
  $outputPath = Join-Path $projectPath 'build\tournament_audit'
  New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
  $checks = @()
  $jobs = @(
    @{ Name='Statische Analyse'; Args=@('analyze'); Log='analyze.log' },
    @{ Name='Turniersimulation und Regressionstests'; Args=@('test','test/tournament_audit_test.dart','test/tournament_simulation_matrix_test.dart','test/tournament_format_planner_test.dart','test/planning_automatic_formats_test.dart','test/planning_duration_test.dart','test/planning_leg_estimate_test.dart','test/planning_group_limit_test.dart','test/planning_match_breakdown_test.dart','test/planning_order_of_play_integration_test.dart','test/group_bye_seeding_test.dart','test/qualification_certainty_test.dart','test/order_of_play_test.dart','test/order_of_play_widget_test.dart'); Log='tests.log' }
  )
  foreach ($job in $jobs) {
    Write-Host $job.Name
    $arguments = $job.Args
    # Windows PowerShell wraps native stderr as an error record. Analysis
    # notices must not abort the test suite or prevent the report being written.
    $ErrorActionPreference = 'Continue'
    try {
      & flutter @arguments 2>&1 | Tee-Object -FilePath (Join-Path $outputPath $job.Log) | Out-Host
      $checkExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    $checks += @{ name=$job.Name; exitCode=$checkExitCode; log=$job.Log }
  }
  $checks | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $outputPath 'checks.json')
  $rows = foreach ($check in $checks) {
    $status = if ($check.exitCode -eq 0) {'BESTANDEN'} else {'PRUEFEN (Exit '+$check.exitCode+')'}
    '<li><strong>'+$check.name+': '+$status+'</strong> - <a href="'+$check.log+'">Protokoll</a></li>'
  }
  $html = '<!doctype html><html lang="de"><meta charset="utf-8"><title>Turniertester</title><style>body{font:18px system-ui;max-width:1000px;margin:50px auto;padding:20px;line-height:1.7;background:#f3f7f5}a{color:#006846}</style><h1>Turniertester</h1><p>Prüflauf: '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+'</p><ul>'+($rows -join '')+'</ul><p><a href="simulation.html">Simulationen und vollständige Matchbäume öffnen</a></p><p><a href="simulation.json">Simulationsdaten als JSON</a></p><p>Analysehinweise können einen Fehlercode erzeugen, obwohl die Turniertests bestehen. Details stehen im jeweiligen Protokoll.</p></html>'
  $reportPath = Join-Path $outputPath 'index.html'
  [System.IO.File]::WriteAllText($reportPath,$html)
  Write-Host "Bericht: $reportPath"
  if (-not $NoOpen) { Invoke-Item -LiteralPath $reportPath }
  if (@($checks | Where-Object { $_.exitCode -ne 0 }).Count -gt 0) { exit 1 }
} finally { Pop-Location }
