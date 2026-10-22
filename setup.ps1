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

# keytool: dal PATH, altrimenti dal JDK incluso in Android Studio
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    $keytool = @(
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$PW = Read-Secret "Password del keystore (min 6 caratteri, niente virgolette)"

if (Test-Path $KS) {
    Write-Host "Uso il keystore esistente: $KS"
} else {
    if (-not $keytool) { throw "keytool non trovato: installa un JDK o Android Studio." }
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
