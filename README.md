# image_contours

Sketch Processing qui trace les courbes de niveau d'une image ou d'une carte d'élévation.

---

## Images classiques

Tout fichier image (JPG, PNG) placé dans `data/` peut être utilisé.  
La luminosité des pixels est utilisée comme valeur d'élévation (0–255).

---

## Cartes d'élévation — format Terrarium PNG

Pour une précision maximale (~65 000 niveaux), utiliser les **terrain tiles AWS au format Terrarium**.  
L'élévation est encodée dans les canaux RGB : `elevation (m) = R×256 + G + B/256 − 32768`

Le sketch a un mode **Terrarium** qui décode cette formule au lieu d'utiliser la luminosité brute.

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
