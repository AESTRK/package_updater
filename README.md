# package_updater

Application macOS pour **auditer** les `.venv` et **publier** la matrice des packages vers `installer`.

## Rôle dans la stack

| Outil | Rôle |
|--------|------|
| **package_updater** | Édition matrice, audit venv, sync → installateur |
| **installer** | Homebrew, Git, rebuild `.venv` (install uniquement) |

## Premier lancement

```bash
git clone https://github.com/AESTRK/package_updater.git ~/XcodeProjects/package_updater
open ~/XcodeProjects/package_updater/package_updater.xcodeproj
```

⌘R — scheme **package_updater**.

## Interface

| Bouton | Action |
|--------|--------|
| **Venv audit** | Tableaux colorés par projet → `audit/<run>/output/` |
| **Appliquer matrice** | Audit puis bump auto des `>=` (MATRICE_A_RAFRAICHIR) |
| **Sync installateur** | Copie la matrice → `installer/scripts/` |
| **Audit + publier** | Audit + sync installateur |

## Workflow recommandé

1. Modifier la matrice dans Package Updater (ou le fichier `scripts/requirements_matrix.txt`).
2. **Enregistrer** → **Audit + publier** (ou audit puis sync séparément).
3. Ouvrir **installer** → **Venv install** pour rebuild les `.venv`.

## Scripts CLI

```bash
cd ~/XcodeProjects/package_updater/scripts
chmod +x *.sh
./package-updater.sh audit
./package-updater.sh sync-installer
./package-updater.sh publish
```

## Logs

Sous `~/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater/` :

- App : `run_*/`
- Audit : `audit/<timestamp>/output/`
  - `package_check.txt` — tableaux par projet (comme l’ancien Raccourci)
  - `matrix_check.txt` — lignes à rafraîchir dans la matrice
  - `matrix_refresh.tsv` — entrées pour `apply-matrix`
  - `summary.txt`, `paths.txt`
- Lien : `audit/latest` → dernier run

## Variables d'environnement

- `PACKAGE_UPDATER_ROOT` — racine du repo
- `INSTALLER_ROOT` — cible sync (défaut `~/XcodeProjects/installer`)
- `REQUIREMENTS_MATRIX` — matrice source
- `PROJECTS_ROOT` — projets Python (défaut `~/PycharmProjects`)
