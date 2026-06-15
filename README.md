# package_updater

| Bouton | Script | Log |
|--------|--------|-----|
| Venv audit | `scripts/venv-audit.sh` | `venv_audit_jj-MM-aaaa_HH-mm-ss_pid{N}.log` |
| Mettre à jour matrice (auto) | `scripts/update-matrix-auto.sh` | `maj_matrice_jj-MM-aaaa_HH-mm-ss_pid{N}.log` |
| Rattacher nouveaux projets | `scripts/discover-project-attachments.sh` + `scripts/apply-project-attachments.sh` | `rattache_projets_jj-MM-aaaa_HH-mm-ss_pid{N}.log` |

La mise à jour auto remonte uniquement les versions minimales. Les nouvelles applis sont proposées via **Rattacher nouveaux projets** (confirmation Oui/Non par projet dans l'app).
| Sync installateur | `scripts/sync-installer.sh` | `sync_installer_jj-MM-aaaa_HH-mm-ss_pid{N}.log` |

Matrice : `package_updater_latest_matrix.txt` (racine du projet)  
Historique : `history/YYYYMMDD_HHMMSS_…` (un fichier par archive, horodaté)  
Logs : `~/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater/` — **type, horodatage FR, pid** (`venv_audit_02-06-2026_16-49-30_pid4321.log`, …)
