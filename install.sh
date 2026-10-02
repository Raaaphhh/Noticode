#!/bin/sh
# Installe ou met à jour Noticode (compilé sur ce Mac) dans /Applications (ou ~/Applications).
#   curl -fsSL https://raw.githubusercontent.com/Raaaphhh/Noticode/main/install.sh | sh
# Lancé depuis un dossier des sources, il compile ces sources ; sinon il télécharge la dernière version.
# Prérequis : macOS 14+, Xcode. xcodegen est installé avec Homebrew s'il manque.
set -eu

REPO="https://github.com/Raaaphhh/Noticode.git"
BUNDLE_ID="com.noticode.app"

fail() { echo "Erreur : $1" >&2; exit 1; }

# Tout est dans une fonction appelée à la fin : avec `curl | sh`, le script entier est lu
# avant de commencer (une commande qui lit l'entrée ne peut pas en avaler la suite).
main() {
    # 1. Prérequis
    [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || fail "macOS 14 ou plus récent est requis."
    xcodebuild -version >/dev/null 2>&1 \
        || fail "Xcode est requis (App Store). Ouvre-le une fois, puis : sudo xcode-select -s /Applications/Xcode.app"
    if ! command -v xcodegen >/dev/null 2>&1; then
        command -v brew >/dev/null 2>&1 \
            || fail "xcodegen est requis. Installe Homebrew (https://brew.sh) puis relance cette commande."
        echo "Installation de xcodegen avec Homebrew…"
        brew install xcodegen </dev/null
    fi

    # 2. Sources : ce dossier s'il en contient, sinon une copie temporaire de la dernière version.
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    here=""
    case "$0" in */install.sh | install.sh) here=$(cd "$(dirname "$0")" && pwd) ;; esac  # sinon : lu via `curl | sh`
    if [ -n "$here" ] && [ -f "$here/project.yml" ] && [ -d "$here/Noticode" ]; then
        src="$here"
    else
        echo "Téléchargement de Noticode…"
        git clone --quiet --depth 1 "$REPO" "$work/src" </dev/null || fail "téléchargement impossible depuis $REPO."
        src="$work/src"
        [ -f "$src/project.yml" ] || fail "$REPO ne contient pas les sources de Noticode."
    fi

    # 3. Compilation (signature locale « ad hoc » : aucun compte Apple nécessaire)
    echo "Compilation de Noticode (une à deux minutes)…"
    (cd "$src" && xcodegen generate --quiet) </dev/null
    xcodebuild -project "$src/Noticode.xcodeproj" -scheme Noticode -configuration Release \
        -destination "generic/platform=macOS" -derivedDataPath "$work/build" \
        CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= -quiet build </dev/null
    built="$work/build/Build/Products/Release/Noticode.app"
    [ -d "$built" ] || fail "la compilation n'a pas produit Noticode.app."

    # 4. Installation
    dest="/Applications"
    [ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
    target="$dest/Noticode.app"
    update=0
    if [ -d "$target" ]; then
        # On ne remplace qu'une ancienne version de Noticode, jamais une autre app du même nom.
        existing=$(defaults read "$target/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
        [ "$existing" = "$BUNDLE_ID" ] || fail "$target existe mais n'est pas Noticode : rien n'a été modifié."
        update=1
    fi
    # Copie à côté d'abord : si elle échoue, l'ancienne version reste en place.
    staging="$dest/.Noticode.app.new"
    rm -rf "$staging"
    ditto "$built" "$staging"
    if [ "$update" = 1 ]; then
        pkill -x Noticode 2>/dev/null || true
        rm -rf "$target"
    fi
    mv "$staging" "$target"
    open "$target"

    if [ "$update" = 1 ]; then
        echo "Noticode est à jour ($target)."
    else
        echo "Noticode est installé dans $target"
        cat <<EOF

Dernière étape (une seule fois) : icône Noticode dans la barre des menus
> « Installer les hooks Claude Code… ». Puis relance tes sessions Claude Code ouvertes.
EOF
    fi
}

main "$@"
