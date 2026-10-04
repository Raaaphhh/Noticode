# Noticode

Petite app macOS qui affiche dans le **notch** ce que fait [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) : réponse terminée, question, autorisation demandée, erreur. Une animation de **Notiboy**, un son court, et tu sais sans regarder le terminal que Claude attend après toi.

- Marche avec **tous les terminaux** et toutes les sessions Claude Code ouvertes.
- Le notch **affiche seulement** : on répond toujours dans le terminal. Pour le fermer, glisse vers le haut (deux doigts, ou clic maintenu), sinon il se ferme seul.
- Léger : 0 % de processeur quand rien ne s'affiche.
- **Aucun réseau, aucune télémétrie** : tout passe par un socket local sur ton Mac.

> L'interface est en français.

## Ce que montre le notch

Le notch s'élargit à peine, à sa propre hauteur : Notiboy et un mot de couleur à gauche, le projet à droite (« +2 » si d'autres notifications attendent). Quand tu dois agir, une ligne de détail s'ajoute dessous. Le bord du bas se vide pendant le temps d'affichage ; garde la souris sur le notch pour arrêter le temps (30 s au plus) et lire le détail en entier.

- **Terminé** (vert) : Claude a fini de répondre.
- **Autoriser ?** (ambre) : Claude veut utiliser un outil ; l'outil (Bash, Edit…) et la commande ou le fichier s'affichent dessous.
- **Question** (bleu) : Claude te pose une question. Après un moment sans réponse, rappel **En attente** (gris, sans détail).
- **Erreur** (corail) : la réponse a échoué (limite atteinte, erreur réseau…), expliqué en une phrase.
- **Mode auto** : dans une session en mode `auto`, « Terminé », « Erreur » et le rappel s'affichent sans détail, avec un contour jaune, « AUTO » à droite et un son plus discret.

Sur un Mac sans notch, la même chose s'affiche en haut au centre de l'écran.

## Installation

Prérequis : macOS 14 (Sonoma) ou plus récent et [Xcode](https://apps.apple.com/app/xcode/id497799835) (gratuit, App Store), ouvert une fois pour accepter sa licence. Si [XcodeGen](https://github.com/yonaskolb/XcodeGen) manque, le script l'installe avec [Homebrew](https://brew.sh).

1. Dans le Terminal :

   ```sh
   curl -fsSL https://raw.githubusercontent.com/Raaaphhh/Noticode/main/install.sh | sh
   ```

   Le script télécharge la dernière version, compile l'app sur ton Mac (une à deux minutes, aucun compte Apple nécessaire), l'installe dans `/Applications` (ou `~/Applications` si tu n'as pas les droits) puis l'ouvre. L'icône de Notiboy apparaît dans la barre des menus.

2. **Installe les hooks** (une seule fois) : icône Noticode dans la barre des menus › **Installer les hooks Claude Code…**. Noticode montre les lignes ajoutées à `~/.claude/settings.json` et n'écrit qu'après ta confirmation, avec une sauvegarde datée du fichier. Les hooks déjà présents (d'autres outils) sont conservés.

3. Relance les sessions Claude Code déjà ouvertes : les nouvelles sont prises en compte tout de suite.

> Avant de lancer un script téléchargé, tu peux le lire : [`install.sh`](install.sh), [`uninstall.sh`](uninstall.sh).

## Réglages

Icône dans la barre des menus › **Réglages…** :

- **Volume** des sons, et **Couper le son** directement dans le menu ;
- **Durée** des notifications : courte, normale ou longue ;
- **Taille** : compacte (détail sur une ligne, déplié au survol) ou détaillée (jusqu'à 3 lignes d'office) ;
- **Ouvrir Noticode au démarrage d'une session Claude Code** : si l'app est fermée, elle s'ouvre toute seule (nouvelle session seulement, pas après `/clear`, `/compact` ou `/resume`) ;
- onglet **Aide** : légende des notchs, état des hooks, dépannage.

## Mise à jour

La même commande que pour l'installation : elle remplace l'app par la dernière version et la relance.

```sh
curl -fsSL https://raw.githubusercontent.com/Raaaphhh/Noticode/main/install.sh | sh
```

Les réglages et les hooks sont conservés.

## Désinstallation

```sh
curl -fsSL https://raw.githubusercontent.com/Raaaphhh/Noticode/main/uninstall.sh | sh
```

Pour voir d'abord ce qui serait fait, sans rien changer : `… | sh -s -- --dry-run` (toute autre option est refusée).

Le script :
1. retire les hooks Noticode de `~/.claude/settings.json` après aperçu et confirmation, avec une sauvegarde datée (les autres hooks ne sont pas touchés) ;
2. quitte l'app puis supprime, après une seconde confirmation, l'app, son dossier `~/Library/Application Support/Noticode` et ses réglages.

Si `settings.json` est un lien symbolique (dotfiles), c'est le fichier pointé qui est modifié et le lien reste. Si `settings.json` est illisible (JSON invalide), le script s'arrête sans rien supprimer.

Pour retirer seulement les hooks : menu de Noticode › **Retirer les hooks Claude Code…**.

## Dépannage

- **Aucune notification** : vérifie que Noticode tourne (icône dans la barre des menus) et que les hooks sont installés (onglet Aide), puis relance les sessions Claude Code déjà ouvertes.
- **Pas de son** : vérifie « Couper le son » dans le menu, le volume dans les Réglages et le volume du Mac.
- **Pas de rappel « En attente »** : Claude Code ne l'envoie que si tu sembles loin du terminal depuis environ une minute.
- **`install.sh` échoue sur Xcode** : ouvre Xcode une fois, puis `sudo xcode-select -s /Applications/Xcode.app`.
- **« Noticode.app existe mais n'est pas Noticode »** : une autre app porte ce nom dans `/Applications` ; le script ne la touche pas. Renomme-la ou déplace-la.
- **`uninstall.sh` s'arrête sur « settings.json illisible »** : corrige le JSON de `~/.claude/settings.json` (ou retire les hooks depuis le menu de Noticode), puis relance la commande.
- **macOS refuse d'ouvrir l'app** : elle est signée localement par ton Mac, ce qui suffit d'habitude. Sinon, clic droit sur l'app › **Ouvrir**.

## Comment ça marche

Claude Code lance un petit script (`noticode-hook.sh`) à chaque événement `Stop`, `StopFailure`, `Notification`, `PermissionRequest` et `SessionStart`. Ce script envoie le message à l'app par un socket local (`~/Library/Application Support/Noticode/noticode.sock`) et sort tout de suite : si Noticode ne répond pas, **Claude Code n'est jamais bloqué**.

## Développement

Swift 6, SwiftUI + AppKit, sans dépendance externe. Le projet Xcode est généré par XcodeGen depuis `project.yml`.

```sh
git clone https://github.com/Raaaphhh/Noticode.git && cd Noticode
./install.sh      # compile et installe ces sources-là (même résultat que la commande curl)
xcodegen generate && open Noticode.xcodeproj
```

Le code de l'app est dans `Noticode/` (`App/`, `Hooks/`, `Notch/`, `Notiboy/`, `Settings/`), les sons, les données de Notiboy et le script du hook dans `Noticode/Resources/`.

## Licence et crédits

© 2026 Raphaël Descamps. Logiciel libre sous licence **GNU AGPL v3** (voir [`LICENSE`](LICENSE)), fourni sans aucune garantie.

- Notiboy est animé par un port Swift du moteur de [Bible Strong Avatar Lab](https://github.com/smontlouis/bible-strong-avatar-lab) (AGPL-3.0), d'où la licence du projet.
- Le serveur des hooks et les animations du notch s'inspirent de [Coucou](https://github.com/Louis-CFM/coucou) (MIT).

Noticode est un projet indépendant, non affilié à Anthropic ni approuvé par Anthropic. « Claude » et « Claude Code » sont des marques d'Anthropic.

Détails dans [`NOTICE.md`](NOTICE.md).
