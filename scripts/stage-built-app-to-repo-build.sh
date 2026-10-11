#!/bin/bash
# Copie le .app produit par Xcode (DerivedData) vers <repo>/build/<Config>/ — chemin hub canonique.
set -euo pipefail

SRC_APP="${BUILT_PRODUCTS_DIR:?}/${WRAPPER_NAME:?}"
DEST_DIR="${SRCROOT}/build/${CONFIGURATION}"
DEST_APP="${DEST_DIR}/${WRAPPER_NAME}"

[[ -d "$SRC_APP" ]] || exit 0

mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"
ditto "$SRC_APP" "$DEST_APP"
xattr -cr "$DEST_APP" 2>/dev/null || true
