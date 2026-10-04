#!/bin/sh
# Désinstalle Noticode : retire ses hooks de ~/.claude/settings.json (sauvegarde datée, aperçu, confirmation),
# quitte l'app, puis supprime l'app, ses fichiers et ses réglages. Les autres hooks ne sont pas touchés.
#   curl -fsSL https://raw.githubusercontent.com/Raaaphhh/Noticode/main/uninstall.sh | sh
# Option : --dry-run pour seulement afficher ce qui serait fait (via curl : `| sh -s -- --dry-run`).
set -eu

BUNDLE_IDS="io.github.raaaphhh.noticode com.noticode.app"  # actuel, puis celui d'avant le 2026-10-04
SETTINGS="$HOME/.claude/settings.json"
DRY_RUN=0
NL="
"

ask() {
    printf '%s [o/N] ' "$1"
    read -r answer </dev/tty || answer=""
    case "$answer" in o|O|oui|y|Y|yes) return 0 ;; *) return 1 ;; esac
}

# Tout est dans une fonction appelée à la fin : avec `curl | sh`, le script entier est lu avant de commencer.
main() {
    # Une faute de frappe (ex. --dryrun) ne doit jamais lancer une vraie désinstallation.
    case "$*" in
        "") ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "Option inconnue : $* (seule option : --dry-run)" >&2; exit 2 ;;
    esac
    # Fichiers et dossiers à supprimer (seulement ceux qui existent).
    targets=""
    for path in "/Applications/Noticode.app" "$HOME/Applications/Noticode.app"; do
        [ -d "$path" ] || continue
        # Seulement notre app, jamais une autre du même nom.
        id=$(defaults read "$path/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
        case " $BUNDLE_IDS " in *" $id "*) targets="$targets$NL$path" ;; esac
    done
    [ -e "$HOME/Library/Application Support/Noticode" ] && targets="$targets$NL$HOME/Library/Application Support/Noticode"
    for id in $BUNDLE_IDS; do
        for path in "$HOME/Library/Preferences/$id.plist" \
                    "$HOME/Library/Caches/$id" \
                    "$HOME/Library/HTTPStorages/$id" \
                    "$HOME/Library/Saved Application State/$id.savedState"; do
            [ -e "$path" ] && targets="$targets$NL$path"
        done
    done

    # 1. Hooks : on calcule le nouveau settings.json sans les commandes noticode-hook.sh (comme l'app).
    if [ -f "$SETTINGS" ]; then
        command -v python3 >/dev/null 2>&1 \
            || { echo "python3 introuvable : retire d'abord les hooks avec le menu de Noticode." >&2; exit 1; }
        # Si settings.json est un lien (dotfiles), on travaille sur le vrai fichier : le lien reste intact.
        SETTINGS=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$SETTINGS") \
            || { echo "python3 ne fonctionne pas : retire d'abord les hooks avec le menu de Noticode." >&2; exit 1; }
        snapshot=$(mktemp)
        proposed=$(mktemp)
        trap 'rm -f "$snapshot" "$proposed"' EXIT
        cp "$SETTINGS" "$snapshot"

        # Codes de sortie : 0 = hooks à retirer (aperçu affiché), 3 = aucun hook, autre = erreur.
        set +e
        python3 - "$snapshot" "$proposed" <<'PY'
import difflib, json, sys

source, output = sys.argv[1], sys.argv[2]
try:
    with open(source, encoding="utf-8") as f:
        settings = json.load(f)
except (OSError, ValueError) as error:
    sys.exit(f"settings.json illisible : {error}")
if not isinstance(settings, dict):
    sys.exit("settings.json : forme inattendue (pas un objet JSON)")

def is_ours(hook):
    return "noticode-hook.sh" in str(hook.get("command", ""))

hooks = settings.get("hooks")
changed = False
if isinstance(hooks, dict):
    for event in list(hooks):
        groups = hooks[event]
        if not isinstance(groups, list):
            continue
        kept = []
        for group in groups:
            inner = group.get("hooks", []) if isinstance(group, dict) else []
            rest = [h for h in inner if not (isinstance(h, dict) and is_ours(h))]
            if len(rest) == len(inner):
                kept.append(group)
                continue
            changed = True
            if rest:
                kept.append({**group, "hooks": rest})
        if kept:
            hooks[event] = kept
        else:
            del hooks[event]
    if not hooks:
        del settings["hooks"]

if not changed:
    sys.exit(3)

def dump(value):
    return json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n"

with open(source, encoding="utf-8") as f:
    before = dump(json.load(f))
after = dump(settings)
with open(output, "w", encoding="utf-8") as f:
    f.write(after)
sys.stdout.writelines(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                           "settings.json (actuel)", "settings.json (après)"))
PY
        status=$?
        set -e
        if [ "$status" != 0 ] && [ "$status" != 3 ]; then
            echo "Rien n'a été modifié : désinstallation arrêtée (corrige settings.json ou retire les hooks avec le menu de Noticode)." >&2
            exit 1
        fi
        if [ "$status" = 0 ]; then
            echo
            echo "Modifications de $SETTINGS ci-dessus (fichier réécrit avec ses clés triées ; sauvegarde datée avant)."
            if [ "$DRY_RUN" = 1 ]; then
                echo "(--dry-run : hooks non retirés)"
            elif ask "Retirer les hooks Noticode ?"; then
                cmp -s "$SETTINGS" "$snapshot" \
                    || { echo "settings.json a changé entre-temps : relance le script." >&2; exit 1; }
                backup="$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
                [ -e "$backup" ] && backup="$backup-$$"
                cp -p "$SETTINGS" "$backup"
                # Mêmes droits que l'original, puis remplacement en une fois (jamais de fichier incomplet).
                temporary="$SETTINGS.noticode-tmp"
                (umask 077; cp "$proposed" "$temporary")
                chmod "$(stat -L -f %Lp "$SETTINGS")" "$temporary"
                mv -f "$temporary" "$SETTINGS"
                echo "Hooks retirés. Sauvegarde : $backup"
            else
                echo "Hooks conservés : désinstallation annulée (sans Noticode, ils ne feraient rien d'utile)."
                exit 1
            fi
        else
            echo "Aucun hook Noticode dans $SETTINGS."
        fi
    fi

    # 2. App et fichiers
    if [ -z "$targets" ]; then
        echo "Aucun fichier de Noticode à supprimer."
        exit 0
    fi
    echo
    echo "À supprimer :$targets"
    if [ "$DRY_RUN" = 1 ]; then
        echo "(--dry-run : rien n'a été supprimé)"
        exit 0
    fi
    ask "Supprimer ces éléments ?" || { echo "Rien n'a été supprimé."; exit 0; }

    pkill -x Noticode 2>/dev/null || true
    for id in $BUNDLE_IDS; do defaults delete "$id" 2>/dev/null || true; done
    echo "$targets" | while IFS= read -r path; do
        [ -n "$path" ] && rm -rf "$path"
    done
    echo "Noticode est désinstallé."
}

main "$@"
