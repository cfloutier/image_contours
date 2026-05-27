# Reprise du projet image_contours

Date: 2026-05-27

## Resume ultra court

- Le sketch est stable en mode classic + Terrarium.
- Le pipeline est decouple: image / contour / shading.
- L'outil cartographique bbox est operationnel (auto-zoom par taille cible + warning gros download).
- HUD ajoute: temps de calcul contour + nombre total de lignes.

## Reprise sur un autre PC

1. Ouvrir le dossier `image_contours/`.
2. Creer l'env conda:

```powershell
conda env create -p ./.condaenv -f environment.yml
```

3. Lancer l'outil bbox si besoin de nouvelles cartes:

```powershell
.\fetch_terrarium_bbox.cmd
```

4. Ouvrir `image_contours.pde` et lancer le sketch.

## Architecture actuelle

- `ElevationGrid.pde`:
  - source abstraction
  - classic brightness
  - Terrarium decode-first puis resize/blur float

- `MarchingSquares.pde`:
  - algo contour pur (reutilisable)

- `ContourGenerator.pde`:
  - glue data -> grid -> marching squares -> polyline group

- `ReliefShading.pde`:
  - hillshade (sun azimuth/altitude, z_factor, ambient)
  - tone mapping post-light (`contrast`, `gamma`)

- `image_contours.pde`:
  - boucle draw allégée
  - fonction `rebuildIfNeeded()` pour rebuild cible
  - HUD bas d'ecran

## Rebuild policy (important)

- changement image => rebuild contours + shading
- changement contour => rebuild contours seulement
- changement shading => rebuild shading seulement
- changement page/global => update export scale (et rebuild selon flags globaux)

## Outil bbox Terrarium (etat actuel)

Fichier: `tools/fetch_terrarium_bbox.py`

- Format unique des coordonnees: `lon,lat,lon,lat`
- Choix taille cible: 256 / 512 / 1024 / 2048 / 4096 / custom
- Zoom auto choisi selon la taille cible (cote long)
- `--zoom` force le zoom manuellement
- warning gros download:
  - `--warn-tiles` (defaut 100)
  - `--yes` pour auto-confirmer
- nom auto de sortie: suffixe `_z<zoom>` si pas de `--output`

Lanceur Windows: `fetch_terrarium_bbox.cmd`

## HUD contours

Affiche en bas:

- `lines`: total des polylines de contour
- `calc contour`: duree du dernier `generator.build()`

## Points d'attention

- `Settings/default.json` contient des valeurs de travail (pas forcement neutres).
- Si besoin de presets propres, creer des fichiers dedies dans `Settings/`.

## Prochaine etape candidate

`ContourShadeFilter` (a la maniere de `image_lines/ThresholdFilter`) pour filtrer les segments de contour selon la luminance de l'ombrage relief.
