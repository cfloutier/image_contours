# image_contours

Sketch Processing qui trace les courbes de niveau d'une image ou d'une carte d'élévation.

---

## Images classiques

Tout fichier image (JPG, PNG) placé dans `data/` peut être utilisé.  
La luminosité des pixels est utilisée comme valeur d'élévation (0–255).

---

## Cartes d'élévation — format Terrarium PNG

### Installation de l'environnement Python (Conda)

Les outils `tools/gen_terrarium.py` et `tools/fetch_terrarium_bbox.py` utilisent Python + Pillow.

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

Le script local `tools/fetch_terrarium_bbox.py` permet de coller deux points lat/lon,
de télécharger automatiquement les tiles Terrarium AWS de la zone, puis de sauvegarder
un PNG Terrarium recadré dans `data/`.

**Lanceur Windows (double-clic)** : `fetch_terrarium_bbox.cmd`

**CLI directe** :
```
python tools/fetch_terrarium_bbox.py
```

Sans `--zoom`, le script propose un choix de definition :

- `Basse` (zoom 8) : grande zone (ex: Corse)
- `Moyenne` (zoom 10) : region
- `Haute` (zoom 12) : ville / petite zone
- `Personnalisee` (zoom 0-15)

Sans `--output`, le script demande un nom de fichier et ajoute automatiquement
le suffixe du niveau : `_z<zoom>.png`.

Exemple : si tu entres `corse`, la sortie devient `data/corse_z8.png` (si zoom 8).

Format accepte (unique, style BBoxfinder) :

- `west, south, east, north` (W,S,E,N)

Exemple :
```
python tools/fetch_terrarium_bbox.py --coords "45.98,6.85,45.82,7.10" --zoom 11 -o data/alps_terrarium.png
```

### Sites pratiques pour récupérer les coordonnées

- **BBoxfinder** (très simple pour tracer un rectangle et copier une bbox) : https://bboxfinder.com/
- **geojson.io** (dessin rectangle/polygone + copie des coordonnées) : https://geojson.io/
- **OpenStreetMap Export** (sélection visuelle d'une zone) : https://www.openstreetmap.org/export

Le script lit les 4 premiers nombres trouvés dans le texte collé, dans cet ordre :
`west, south, east, north`.

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

OK pour la base actuelle.

Prochaine etape prevue : implementer `ContourShadeFilter` (equivalent du `ThresholdFilter` de `image_lines`) pour filtrer les segments de contours selon la luminosite de l'image d'ombrage relief.
