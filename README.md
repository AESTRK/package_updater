# package_updater (macOS)

Application SwiftUI pour maintenir la **matrice des dépendances** Python/Rust de la stack.

Bundle : `io.aestrk.PackageUpdater`

## Prérequis build

Package SPM local **AlphaLagoonPaths** :

```text
~/XcodeProjects/AlphaLagoonPaths
```

Sibling de `package_updater/` — résolution de `config/generated/pip_matrix.txt`.

Projet complémentaire : [**installer**](../installer) (clone Git, venv, build Rust, DMG launcher).

## Actions

| Bouton | Mode script | Rôle |
|--------|-------------|------|
| **Venv audit** | `audit` | Compare les venvs locaux à la matrice |
| **Mettre à jour matrice (auto)** | `audit-apply` | Remonte les versions minimales détectées |
| **Rattacher nouveaux projets…** | interactif | Découvre `requirements.txt` / `Cargo.toml` non référencés — confirmation par projet |
| **Archiver matrice** | `archive-matrix` | Archive un snapshot de `config/generated/pip_matrix.txt` |

Éditeur intégré : matrice canonique `config/generated/pip_matrix.txt` (Enregistrer / Recharger / Ouvrir dans l’éditeur par défaut).

## Fichiers

| Fichier | Usage |
|---------|-------|
| `config/generated/pip_matrix.txt` | Matrice canonique (config_manager, git) |
| `history/YYYYMMDD_HHMMSS_pip_matrix.txt` | Archives horodatées |
| `scripts/venv-audit.sh` | Audit venv |
| `scripts/update-matrix-auto.sh` | Mise à jour auto |
| `scripts/discover-project-attachments.sh` | Détection nouveaux projets |
| `scripts/apply-project-attachments.sh` | Application des rattachements |
| `scripts/archive-matrix.sh` | Archive la matrice canonique |

## Logs

Racine : `~/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater/`

Convention : `<type>_jj-MM-aaaa_HH-mm-ss_pid<N>.log` — ex. `venv_audit_02-06-2026_16-49-30_pid4321.log`, `archive_matrix_…`, `maj_matrice_…`, `rattache_projets_…`.

## Structure du code

```text
package_updater/
├── package_updater/
│   ├── UpdaterPaths.swift
│   ├── Services/
│   │   ├── ScriptRunner.swift
│   │   ├── RequirementsMatrixStore.swift
│   │   └── ProjectAttachmentCoordinator.swift
│   └── Utilities/PackageUpdaterActions.swift
└── scripts/
    ├── venv-audit.sh
    ├── update-matrix-auto.sh
    ├── archive-matrix.sh
    └── lib/project-attachments.sh
```

## Prérequis

- `config_manager` cloné avec `config/generated/pip_matrix.txt` (Sync stack dans Config Manager / installer)
- Venvs Python sous `~/PycharmProjects/<app>/.venv`

## Config (rappel stack)

| Couche | Chemin |
|--------|--------|
| Défauts persist / inject | `config_manager/config/runtime/` → `stack.json` |
| Overrides machine | `config_manager/config/local/<app>.json` |
| Matrice pip | `config_manager/config/generated/pip_matrix.txt` |
