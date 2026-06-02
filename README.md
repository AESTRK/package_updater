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
| **Venv audit** | Compare versions installées vs matrice |
| **Mettre à jour l'installateur** | Copie `requirements_matrix.txt` → `installer/scripts/` |
| **Audit + publier** | Audit puis sync |

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

- App : `~/Documents/AlphaLagoon/_logs/package_updater/`
- Audit : `~/Documents/AlphaLagoon/_logs/package_audit/`

## Variables d'environnement

- `PACKAGE_UPDATER_ROOT` — racine du repo
- `INSTALLER_ROOT` — cible sync (défaut `~/XcodeProjects/installer`)
- `REQUIREMENTS_MATRIX` — matrice source
- `PROJECTS_ROOT` — projets Python (défaut `~/PycharmProjects`)
