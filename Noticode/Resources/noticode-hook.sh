#!/bin/sh
# Relais Claude Code -> Noticode : envoie le JSON du hook au socket de l'app.
# Ne bloque jamais Claude Code : si l'app ne répond pas, on sort tout de suite.
DIR="$HOME/Library/Application Support/Noticode"
SOCK="$DIR/noticode.sock"

# Une seule ligne : le saut de ligne final marque la fin du message attendue par l'app.
INPUT=$(tr '\n' ' ')

if [ -S "$SOCK" ] && printf '%s\n' "$INPUT" | /usr/bin/nc -U -w 1 "$SOCK" >/dev/null 2>&1; then
    exit 0
fi

# L'app ne répond pas : au démarrage d'une session, on l'ouvre si le réglage est actif
# (fichier launch-app présent). `open` est détaché : même lent (1er lancement), il ne fait pas attendre.
# SessionStart revient aussi après /clear, /compact et /resume : on n'ouvre que pour un vrai démarrage.
case "$INPUT" in
    *'"hook_event_name":"SessionStart"'* | *'"hook_event_name": "SessionStart"'*) ;;
    *) exit 0 ;;
esac
case "$INPUT" in
    *'"source":"startup"'* | *'"source": "startup"'*)
        APP=$(cat "$DIR/launch-app" 2>/dev/null)
        if [ -n "$APP" ] && [ -d "$APP" ]; then
            ( /usr/bin/open -g "$APP" >/dev/null 2>&1 & )
        fi
        ;;
esac
exit 0
