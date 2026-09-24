param([string]$Repository = 'ProfGans/DartTunier')
$ErrorActionPreference = 'Stop'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) installieren und gh auth login ausführen. Alternativ die vier Secrets laut docs/android-releases.md im GitHub-Webinterface hinterlegen.'
}
$secretsPath = Join-Path $PSScriptRoot '../.secrets/android/github-secrets.json'
$signingSecrets = Get-Content -LiteralPath $secretsPath -Raw | ConvertFrom-Json
foreach ($name in @('ANDROID_KEYSTORE_BASE64', 'ANDROID_STORE_PASSWORD', 'ANDROID_KEY_PASSWORD', 'ANDROID_KEY_ALIAS')) {
    $value = $signingSecrets.$name
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Secret fehlt: $name" }
    # Pipe secrets on stdin, never in command-line arguments or console output.
    $value | & gh secret set $name --repo $Repository
    if ($LASTEXITCODE -ne 0) { throw "Secret konnte nicht gesetzt werden: $name" }
}
Write-Output "Android-Signing-Secrets in $Repository eingerichtet."
