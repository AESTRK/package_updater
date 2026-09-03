# package_updater (macOS)

Application SwiftUI pour maintenir la **matrice des dépendances** Python/Rust de la stack et synchroniser l’installateur.

Bundle : `io.aestrk.PackageUpdater`

Projet complémentaire : [**installer**](../installer) (clone Git, venv, build Rust, DMG launcher).

## Actions

| Bouton | Mode script | Rôle |
|--------|-------------|------|
| **Venv audit** | `audit` | Compare les venvs locaux à la matrice |
| **Mettre à jour matrice (auto)** | `audit-apply` | Remonte les versions minimales détectées |
| **Rattacher nouveaux projets…** | interactif | Découvre `requirements.txt` / `Cargo.toml` non référencés — confirmation par projet |
| **Sync installateur** | `sync-installer` | Copie la matrice vers `config/generated/pip_matrix.txt` |

Éditeur intégré : matrice pip (canonique `config/generated/pip_matrix.txt` si présente, sinon copie locale `package_updater_latest_matrix.txt`).

## Fichiers

| Fichier | Usage |
|---------|-------|
| `config/generated/pip_matrix.txt` | Matrice canonique (config_manager, git) |
| `package_updater_latest_matrix.txt` | Copie locale de travail (fallback éditeur) |
| `history/YYYYMMDD_HHMMSS_…` | Archives horodatées de la matrice |
| `scripts/venv-audit.sh` | Audit venv |
| `scripts/update-matrix-auto.sh` | Mise à jour auto |
| `scripts/discover-project-attachments.sh` | Détection nouveaux projets |
| `scripts/apply-project-attachments.sh` | Application des rattachements |
| `scripts/sync-installer.sh` | Copie vers `config/generated/pip_matrix.txt` |

## Logs

Racine : `~/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater/`

Convention : `<type>_jj-MM-aaaa_HH-mm-ss_pid<N>.log` — ex. `venv_audit_02-06-2026_16-49-30_pid4321.log`, `sync_installer_…`, `maj_matrice_…`, `rattache_projets_…`.

## Structure du code

```text
package_updater/
├── package_updaterApp.swift
├── PackageUpdaterAppDelegate.swift
├── UpdaterPaths.swift
├── Services/
│   ├── ScriptRunner.swift
│   ├── RequirementsMatrixStore.swift
│   └── ProjectAttachmentCoordinator.swift
├── Views/
│   ├── PackageUpdaterView.swift
│   ├── AnsiLogView.swift
│   └── AnsiParser.swift
└── Utilities/
    ├── PackageUpdaterActions.swift
    └── PackageUpdaterQuickActionsMenu.swift
```

## Lancement

```text
~/XcodeProjects/package_updater/package_updater.xcodeproj
```

Scheme **package_updater** → **My Mac** → ⌘R.

## Workflow typique

1. **Venv audit** — voir les écarts
2. **Mettre à jour matrice (auto)** — intégrer les versions détectées
3. **Rattacher nouveaux projets** — si de nouveaux crates/repos apparaissent
4. **Sync installateur** — pousser vers l’app installer
5. Dans **installer** : onglet Python → recréer les `.venv`
