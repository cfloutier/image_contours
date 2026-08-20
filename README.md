# image_contours

Sketch Processing qui trace les courbes de niveau d'une image ou d'une carte d'élévation.

---

## Getting a Release

Aucune installation de Processing, Java ou ControlP5 n'est nécessaire pour lancer une release — tout est inclus dans le zip.

1. Télécharger le zip de release (voir `releases/` ou l'endroit où il t'a été partagé).
2. Le dézipper n'importe où.
3. Lancer le `.exe` à l'intérieur — c'est tout.

---

## Onglets

- **Files** : charger/sauver les réglages, exporter (SVG/PDF/DXF), échelle de page et clipping.
- **Depth** : source de la carte de profondeur (image ou Perlin).
- **Contour** : génération des courbes de niveau.
- **Shading** : ombrage relief (hillshade).
- **Threshold** : filtre les segments de contour selon la luminosité du shading.
- **Shore** : ligne de rivage + lignes de vagues.
- **Style** : couleurs et épaisseur de trait.

---

## Images classiques

Tout fichier image (JPG, PNG) placé dans `data/` peut être utilisé.
La luminosité des pixels est utilisée comme valeur d'élévation (0–255).

Dans l'onglet **Depth**, la carte de profondeur peut maintenant être:

- un fichier (mode classique, `Select Source Image`)
- ou une carte générée procéduralement via **Perlin** (`Use Perlin`)

Le mode Perlin utilise la classe custom du projet (`xLib_MyPerlin.pde`),
pas le `noise()` natif Processing, et est implémente dans des classes derivees
locales au projet (sans modifier `xLib_Image.pde`). Glisser la souris sur le canvas
en mode Perlin permet de se déplacer dans l'espace de bruit.

---

## Contour — paramètres

| Paramètre | Rôle |
|-----------|------|
| `compute` | Calculer les courbes de niveau |
| `draw` | Afficher les courbes de niveau |
| `terrarium_mode` | Décoder l'élévation au format Terrarium (voir plus bas) au lieu de la luminosité brute |
| `quantile_mode` | Niveaux placés aux quantiles (densité visuelle uniforme) plutôt qu'espacés linéairement |
| `contour_levels` | Nombre de niveaux de courbes souhaités |

---

## Shading — paramètres

- Physique : `sun_azimuth_deg`, `sun_altitude_deg`, `z_factor`, `ambient`
- Post-traitement tonal : `contrast`, `gamma`
- Affichage : `compute`, `draw`, `imageAlpha`, `invert`

---

## Threshold — filtre des contours

L'onglet **Threshold** filtre les segments de contour selon la luminosité de l'image de shading sous chaque point : au-dessus/en dessous d'un seuil, le segment est coupé. Le composant (`DataThreshold`) est partagé avec le projet `image_lines` — 6 modes de distribution des seuils selon les niveaux de contour (progressif, miroir, hachures, entrelacé, bissection...).

---

## Shore — rivage et vagues

L'onglet **Shore** extrait une ligne de contour à une seule élévation (`shore_level`), utilisée comme ligne de côte/rivage. Des lignes de "vagues" sont ensuite générées par offsets géométriques successifs de cette ligne (indépendant de la carte d'élévation).

| Paramètre | Rôle |
|-----------|------|
| `enabled` | Activer le rivage |
| `shore_level` | Élévation de la ligne de rivage (0-255 en mode classique, mètres en mode Terrarium) |
| `wave_count` | Nombre de lignes de vagues |
| `wave_step` | Espacement entre vagues (px) — signe négatif pour offset vers l'intérieur |
| `simplify_eps` | Simplification (Douglas-Peucker) des lignes |
| `clip_contours` | Masquer les courbes de niveau sous le rivage |
| `dash_waves` | Dégradé de tirets sur les lignes de vagues |
| `dash_len` | Longueur des tirets (px) |
| `dash_gap_step` | Incrément d'espace entre tirets, par vague (px) |

---

## Cartes d'élévation — format Terrarium PNG

Pour une précision maximale (~65 000 niveaux), le sketch peut lire des **terrain tiles au format Terrarium** (AWS) au lieu d'une image classique.
L'élévation y est encodée dans les canaux RGB : `elevation (m) = R×256 + G + B/256 − 32768`.

Active le mode **Terrarium** dans l'onglet **Contour** pour utiliser cette formule au lieu de la luminosité brute d'une image classique.

### Installation de l'environnement Python (Conda)

Les outils `tools/gen_terrarium.py` et `tools/fetch_terrarium_bbox.py` utilisent Python + Pillow.

Option recommandee (reproductible) :

```powershell
conda env create -p ./.condaenv -f environment.yml
```

Option manuelle :

Depuis le dossier du projet :

```powershell
conda create -y -p ./.condaenv python=3.11
conda install -y -p ./.condaenv pillow numpy
```

Exécution des scripts avec cet environnement :

```powershell
conda run -p ./.condaenv python tools/gen_terrarium.py concentric --size 256 -o data/terrarium_concentric.png
conda run -p ./.condaenv python tools/fetch_terrarium_bbox.py
```

Option Windows (sans `conda run`) :

```powershell
.\.condaenv\python.exe tools\fetch_terrarium_bbox.py
```

Le lanceur `fetch_terrarium_bbox.cmd` utilise automatiquement `./.condaenv/python.exe`.

### Workflow simple (copier-coller de coordonnées)

Le script local `tools/fetch_terrarium_bbox.py` permet de coller soit une bbox lon/lat,
soit un GeoJSON brut (par exemple depuis geojson.io), de télécharger automatiquement
les tiles Terrarium AWS de la zone, puis de sauvegarder un PNG Terrarium recadré dans `data/`.

Lorsqu'une bbox couvre plusieurs tuiles, l'outil applique aussi un lissage léger sur les
jointures internes entre tuiles, pour réduire les artefacts visibles dans les courbes de niveau.

**Lanceur Windows (double-clic)** : `fetch_terrarium_bbox.cmd`

**CLI directe** :
```
python tools/fetch_terrarium_bbox.py
```

Le lanceur Windows `fetch_terrarium_bbox.cmd` exécute automatiquement
`./.condaenv/python.exe` puis garde la fenêtre ouverte pour afficher le résultat.

Sans `--zoom`, le script propose une **taille cible** et calcule automatiquement
le zoom le plus proche :

- `Petite` (~256 px)
- `Moyenne` (~512 px)
- `Grande` (~1024 px)
- `Tres grande` (~2048 px)
- `Ultra` (~4096 px)
- `Personnalisee` (taille en px)

Le calcul est approximatif et depend de la forme de la zone (ratio L/H).
Il est aussi limite par la resolution source effectivement disponible sur les tuiles Terrarium.
En pratique, ce workflow est plafonne a `z15`, donc une cible `Ultra` ne garantit pas
une image proche de `4096 px` si la bbox est trop petite.

Tu peux aussi passer la taille cible en CLI :
```
python tools/fetch_terrarium_bbox.py --target-size 512
```

`--zoom` reste disponible pour forcer manuellement un niveau precis.
Pour ce workflow Terrarium, le zoom manuel est borne a `0..15`.

Warning gros download :

- Le script fait un pre-check du nombre de tuiles avant telechargement.
- Si le total depasse le seuil (100 par defaut), il demande confirmation.
- Options utiles :

```bash
python tools/fetch_terrarium_bbox.py --warn-tiles 150
python tools/fetch_terrarium_bbox.py --yes
```

Sans `--output`, le script demande un nom de fichier et ajoute automatiquement
le suffixe du niveau choisi : `_z<zoom>.png`.

Exemple : si tu entres `corse`, la sortie devient `data/corse_z12.png` (si zoom retenu = 12).

Formats acceptes :

- `lon, lat, lon, lat`
- GeoJSON brut collé depuis **geojson.io** (`FeatureCollection`, `Feature`, `Polygon`, `bbox`, etc.)

Arguments utiles :

- `--coords` : texte bbox classique ou texte libre contenant `lon,lat,lon,lat`
- `--geojson` : GeoJSON brut passé directement en argument
- `--geojson-file` : chemin vers un fichier `.geojson` ou `.json`

Les modes `--coords`, `--geojson` et `--geojson-file` sont mutuellement exclusifs.

Exemples :
```
python tools/fetch_terrarium_bbox.py --coords "45.98,6.85,45.82,7.10" --zoom 11 -o data/alps_terrarium.png
python tools/fetch_terrarium_bbox.py --geojson-file data/selection.geojson --target-size 1024
python tools/fetch_terrarium_bbox.py --geojson "{\"type\":\"FeatureCollection\",...}" --zoom 12
```

### Sites pratiques pour récupérer les coordonnées

- **BBoxfinder** (très simple pour tracer un rectangle et copier une bbox) : https://bboxfinder.com/
- **geojson.io** (dessin rectangle/polygone + copie des coordonnées) : https://geojson.io/
- **OpenStreetMap Export** (sélection visuelle d'une zone) : https://www.openstreetmap.org/export

En mode texte simple, le script lit les 4 premiers nombres trouvés dans le texte collé,
dans cet ordre : `lon, lat, lon, lat`.

En mode GeoJSON, il extrait toutes les coordonnées disponibles, calcule leur enveloppe,
et utilise cette bbox pour le téléchargement/crop final.

### Trouver et télécharger un tile manuellement

**URL directe :**
```
https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png
```

**Outil visuel recommandé — Tangrams Heightmapper :**
https://tangrams.github.io/heightmapper/

1. Naviguer vers la zone souhaitée
2. Décocher "auto-expose" pour conserver les valeurs absolues
3. Cliquer **Export** → s'ouvre dans un nouvel onglet → Enregistrer sous

> ⚠️ L'export de Tangrams est une image *auto-exposée* (niveaux relatifs à la vue).
> Pour des valeurs absolues, télécharger les tiles bruts directement (voir ci-dessous).

### Calculer les coordonnées d'un tile

Pour une zone centrée sur lat/lon au zoom Z :
```
x = floor((lon + 180) / 360 × 2^Z)
y = floor((1 − ln(tan(lat×π/180) + 1/cos(lat×π/180)) / π) / 2 × 2^Z)
```

**Exemples au zoom 7 (tile ≈ 300×300 km) :**

| Zone | Lat | Lon | z | x | y | URL |
|------|-----|-----|---|---|---|-----|
| Alpes suisses | 47°N | 8°E | 7 | 66 | 45 | https://s3.amazonaws.com/elevation-tiles-prod/terrarium/7/66/45.png |
| Îles grecques (Égée) | 38°N | 24°E | 7 | 72 | 49 | https://s3.amazonaws.com/elevation-tiles-prod/terrarium/7/72/49.png |
| Rocheuses (Colorado) | 39°N | -106°E | 7 | 26 | 49 | https://s3.amazonaws.com/elevation-tiles-prod/terrarium/7/26/49.png |
| Hawaii | 20°N | -157°E | 7 | 14 | 56 | https://s3.amazonaws.com/elevation-tiles-prod/terrarium/7/14/56.png |

**Zoom 8** (tile ≈ 150×150 km) : doubler x et y, diviser par 2 la surface couverte.
**Zoom 9** : encore plus de détail (~75×75 km).

### Placer les fichiers

Renommer les tiles téléchargés de façon lisible et les placer dans `data/` :
```
data/
  alpes_z7.png        ← tile 7/66/45
  iles_egee_z7.png    ← tile 7/72/49
  rockies_z7.png      ← tile 7/26/49
```

Ensuite dans le sketch, sélectionner le fichier via l'onglet **Depth** et activer le mode **Terrarium** dans les options de contour.

---

Pour le détail du pipeline, l'architecture, et la procédure de build, voir [DEVELOPMENT.md](DEVELOPMENT.md).

---

## Changelog

### 2026-08-19 — xLib 3.13.4
- **README** : ajout d'une section "Getting a Release" en haut ; ajout des sections **Contour**, **Threshold** et **Shore** (l'onglet Shore n'était documenté nulle part) ; séparation du contenu implémentation (pipeline, modules, HUD) vers un nouveau [DEVELOPMENT.md](DEVELOPMENT.md), en gardant le workflow de préparation des cartes Terrarium ici (c'est un usage du projet, pas une info de développement du sketch) ; correction du statut de `ContourShadeFilter`, qui était encore décrit comme "prochaine étape candidate" alors qu'il est déjà implémenté et branché dans le pipeline.
- **Load / Save** : n'ouvre plus de fenêtre système séparée (qui pouvait parfois s'ouvrir cachée derrière la fenêtre principale) — remplacé par un navigateur de fichiers intégré dans l'onglet **Files**. Load et "Save as..." affichent un bouton par fichier/dossier de `Settings/`, avec un bouton `..` pour remonter et Prev/Next au-delà d'un certain nombre de fichiers. Écraser un fichier existant demande confirmation ; sauver sous un nouveau nom utilise un champ texte pré-rempli avec le nom courant.
- **Clip Ratio** : les contrôles de clipping de l'onglet Files ont un nouveau verrou de proportion — `None` (libre, comme avant), `A4`, `16:9`, `4:3`, `Raisin`, ou `1:1`, plus un toggle `Landscape`/portrait. Avec une proportion active, glisser le slider de largeur ou de hauteur ajuste automatiquement l'autre pour garder le ratio.
- **`export_app.ps1`** : nouveau script de build — exporte le sketch en application autonome (JRE + toutes les libs embarquées, dont ControlP5), copie `Settings/` dans l'export (non inclus par `processing-java --export`, nécessaire au démarrage), et zippe le résultat dans `releases/`. Même script copié tel quel dans chaque projet, même convention que les fichiers partagés `xLib_*.pde`.
- **`.gitignore`** : ignore `build_*/` et `releases/` (sortie de build générée).
