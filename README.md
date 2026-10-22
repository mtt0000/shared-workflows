# shared-workflows

Una sola chiave di firma per tutte le app Android di mtt0000.

## Come funziona

- I secret di questo repo contengono la chiave: `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, più `SYNC_TOKEN`.
- Ogni notte, oppure a mano da Actions → *Sync signing secrets* → *Run workflow*, `sync-signing-secrets.yml` copia i 4 secret della chiave in **ogni tuo repo con un `gradlew`**. Vale anche per i repo creati in futuro.
- I workflow dei repo leggono quei 4 nomi. Se un secret manca, firmano con la chiave di debug.

## Setup (una volta sola)

1. Crea un **fine-grained token**: GitHub → Settings → Developer settings → Fine-grained tokens.
   - Repository access: **All repositories**
   - Permissions → Repository → **Secrets: Read and write**
   - Permissions → Repository → **Contents: Read-only** (serve per vedere il `gradlew` nei repo privati)
   - Scadenza: la più lunga possibile. Quando scade, la sincronizzazione fallisce in modo visibile qui in Actions.
2. Da PowerShell, con `gh auth login` già fatto, lancia `setup.ps1`.

## Nuovo repo Android

Con i nomi dei secret qui sopra non devi configurare niente. Per un workflow di release già pronto, crea `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  release:
    uses: mtt0000/shared-workflows/.github/workflows/android-release.yml@main
    secrets: inherit
```

## Attenzione

- **Backup** di `mtt_master_key.jks` e della password. Se li perdi, le app installate non si possono più aggiornare.
- Il primo APK firmato con questa chiave non si installa sopra le versioni precedenti, che erano firmate con altre chiavi: va disinstallata la vecchia versione una volta.
