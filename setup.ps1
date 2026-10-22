# Setup della chiave di firma condivisa. Da lanciare una volta sul PC (PowerShell, con gh loggato).
# - crea il keystore (solo se non esiste gia')
# - carica chiave e token nei secret di mtt0000/shared-workflows
# - avvia subito la sincronizzazione verso tutti i repo Android

$OWNER = "mtt0000"
$HUB   = "$OWNER/shared-workflows"
$ALIAS = "mtt_alias"
$KS    = "$HOME\keys\mtt_master_key.jks"

function Read-Secret($prompt) {
    [System.Net.NetworkCredential]::new("", (Read-Host $prompt -AsSecureString)).Password
}

# keytool: dal PATH, da JAVA_HOME, da Android Studio o da un JDK Temurin installato
function Find-Keytool {
    $cmd = (Get-Command keytool -ErrorAction SilentlyContinue).Source
    if ($cmd) { return $cmd }
    $candidates = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
    )
    $candidates += Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium\*\bin\keytool.exe", `
        "$env:ProgramFiles\Java\*\bin\keytool.exe", `
        "$env:ProgramFiles\Microsoft\jdk-*\bin\keytool.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | ForEach-Object FullName
    $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
$keytool = Find-Keytool

$PW = Read-Secret "Password del keystore (min 6 caratteri, niente virgolette)"

if (Test-Path $KS) {
    Write-Host "Uso il keystore esistente: $KS"
} else {
    if (-not $keytool) {
        Write-Host "keytool non trovato: installo il JDK Temurin 21 con winget..."
        winget install --id EclipseAdoptium.Temurin.21.JDK -e --silent --accept-package-agreements --accept-source-agreements
        $keytool = Find-Keytool
        if (-not $keytool) { throw "keytool ancora non trovato: chiudi e riapri PowerShell, poi rilancia lo script." }
    }
    Write-Host "Uso keytool: $keytool"
    New-Item -ItemType Directory -Force (Split-Path $KS) | Out-Null
    & $keytool -genkeypair -keystore $KS -storetype PKCS12 -alias $ALIAS `
        -keyalg RSA -keysize 4096 -validity 10000 `
        -storepass $PW -keypass $PW -dname "CN=$OWNER"
    if ($LASTEXITCODE -ne 0) { throw "Creazione del keystore fallita." }
    Write-Host "`nKeystore creato: $KS" -ForegroundColor Green
    Write-Host "FANNE UN BACKUP (chiavetta + password manager) insieme alla password!" -ForegroundColor Yellow
}

$B64   = [Convert]::ToBase64String([IO.File]::ReadAllBytes($KS))
$TOKEN = Read-Secret "Fine-grained token (SYNC_TOKEN)"

gh secret set KEYSTORE_BASE64 -R $HUB --body $B64
gh secret set STORE_PASSWORD  -R $HUB --body $PW
gh secret set KEY_PASSWORD    -R $HUB --body $PW
gh secret set KEY_ALIAS       -R $HUB --body $ALIAS
gh secret set SYNC_TOKEN      -R $HUB --body $TOKEN

# Se il repo e' privato, permette agli altri tuoi repo di usare android-release.yml
gh api -X PUT "repos/$HUB/actions/permissions/access" -f access_level=user 2>$null | Out-Null

gh workflow run sync-signing-secrets.yml -R $HUB
Write-Host "`nFatto. Controlla la sincronizzazione: https://github.com/$HUB/actions" -ForegroundColor Green
