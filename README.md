# image_contours

Sketch Processing qui trace les courbes de niveau d'une image ou d'une carte d'élévation.

## TODO : 
* [x] nettoyer un peu l'ui du depth: ordre et positions des boutons. alléger
* [x] soucis sur la largeur finale en mode Perlin. difficile à gérer
* [x] l'échelles des sliders est à revoir pour le perlin
* [x] comprendre le Z et ptet juste le modifier son slider 
* [x] ajouter un moyen de scroller dans l'image à la souris
* [ ] passer le perlin noise en terrarium

## Images classiques

Tout fichier image (JPG, PNG) placé dans `data/` peut être utilisé.  
La luminosité des pixels est utilisée comme valeur d'élévation (0–255).

Dans l'onglet **Depth**, la carte de profondeur peut maintenant être:

- un fichier (mode classique, `Select Source Image`)
- ou une carte générée procéduralement via **Perlin** (`Use Perlin`)

Le mode Perlin utilise la classe custom du projet (`xLib_MyPerlin.pde`),
pas le `noise()` natif Processing, et est implémente dans des classes derivees
locales au projet (sans modifier `xLib_Image.pde`).

---

## Cartes d'élévation — format Terrarium PNG

### Installation de l'environnement Python (Conda)

Les outils `tools/gen_terrarium.py` et `tools/fetch_terrarium_bbox.py` utilisent Python + Pillow.

Option recommandee (reproductible):

```powershell
conda env create -p ./.condaenv -f environment.yml
```

Option manuelle:

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

Pour une précision maximale (~65 000 niveaux), utiliser les **terrain tiles AWS au format Terrarium**.  
L'élévation est encodée dans les canaux RGB : `elevation (m) = R×256 + G + B/256 − 32768`

Le sketch a un mode **Terrarium** qui décode cette formule au lieu d'utiliser la luminosité brute.

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

---

## Pipeline actuel

1. `DataImage.buildTransformedImage()` prepare l'image transformee.
2. Rebuild cible dans `image_contours.pde`:
  - changement image => rebuild contours + shading
  - changement contour => rebuild contours seulement
  - changement shading => rebuild shading seulement
3. Rendu:
  - image source (optionnelle)
  - shading relief (optionnel)
  - contours (optionnels)

### Modules principaux

- `ElevationGrid.pde`: adaptation source (classic + Terrarium decode-first)
- `MarchingSquares.pde`: algo contour pur (reutilisable)
- `ContourGenerator.pde`: glue data -> algo -> groupe de lignes
- `ReliefShading.pde`: hillshade + GUI shading

### HUD

Un HUD en bas affiche:

- nombre total de lignes de contour
- temps du dernier calcul contour

### Shading: controls disponibles

- Physique: `sun_azimuth_deg`, `sun_altitude_deg`, `z_factor`, `ambient`
- Post-traitement tonal: `contrast`, `gamma`
- Affichage: `draw`, `imageAlpha`, `invert`

### Trouver et télécharger un tile

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

Ensuite dans le sketch, sélectionner le fichier via l'onglet **Image** et activer le mode **Terrarium** dans les options de contour.

---

## Statut dev

Base stable:

- generation contours fonctionnelle (classic + Terrarium)
- shading relief fonctionnel (incluant contrast/gamma)
- outil bbox Terrarium outille pour production data
- rebuild decouple (image / contour / shading)

Prochaine etape candidate:

- `ContourShadeFilter` (equivalent du `ThresholdFilter` de `image_lines`) pour filtrer les segments de contours selon la luminosite de l'image d'ombrage relief.
