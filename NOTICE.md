# Noticode — licence et crédits

Copyright (c) 2026 Raphaël Descamps

Noticode est un logiciel libre : vous pouvez le redistribuer et le modifier selon les termes de la
**GNU Affero General Public License version 3** (texte complet dans [`LICENSE`](LICENSE)).
Il est distribué sans aucune garantie.

Code source : <https://github.com/Raaaphhh/Noticode>

Noticode est un projet indépendant, non affilié à Anthropic ni approuvé par Anthropic.
« Claude » et « Claude Code » sont des marques d'Anthropic.

## Code d'autres projets

### Bible Strong Avatar Lab — AGPL-3.0

- Auteur : Stéphane Montlouis-Calixte — <https://github.com/smontlouis/bible-strong-avatar-lab>
- `Noticode/Notiboy/` : **port en Swift** du moteur d'animation `AvatarProceduralEngine`
  (paquet `@bible-strong/avatar-core`, AGPL-3.0-only ; code source dans le dépôt ci-dessus, version du
  25 août 2026, commit `79fe9ba06e48`) : projection des surfaces, yeux, transitions et
  clignements, modifié pour un dessin natif dans un `Canvas` SwiftUI. Modifications faites en
  septembre-octobre 2026 pour Noticode.

C'est la raison pour laquelle Noticode est sous AGPL-3.0.

### Coucou — MIT

- Copyright (c) 2026 Louis Raillé — licence MIT.
- Le serveur de hooks (`Noticode/Hooks/HookServer.swift`) et les animations du notch s'en inspirent.
  Le nom, le personnage, les icônes et les sons de Coucou ne sont **pas** repris.

Texte de la licence MIT de Coucou :

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Personnage, icônes et sons

- **Notiboy** (formes, couleurs, expressions, animations ; `Noticode/Resources/notiboy/notiboy.json`,
  icônes de l'app et de la barre de menus) : créé par Raphaël Descamps avec Bible Strong Avatar Lab.
  Même licence que le projet. `notiboy.json` est la forme sous laquelle Notiboy est distribué et
  modifié dans ce dépôt ; s'il est un jour retravaillé dans l'Avatar Lab, l'export du Lab sera ajouté ici.
- **Sons** (`Noticode/Resources/sounds/`) : synthétisés pour le projet (aucun échantillon extérieur,
  réverbération Freeverb de Jezar, domaine public), même licence que le projet.
