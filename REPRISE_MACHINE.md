# Reprise du projet image_contours

Date: 2026-05-27

## Objectif en cours

Construire un pipeline similaire a image_lines:
1. Generer beaucoup de lignes source (ici: contours depuis elevation map).
2. Construire une image intermediaire exploitable pour filtrer ces lignes.
3. Utiliser cette image (luminosite) pour garder/supprimer des segments, comme un stage threshold.

La premiere etape complexe est deja implementee: generation d'une image N&B d'ombrage relief (hillshade) basee sur la carte d'elevation.

## Ce qui est implemente

### Nouveau module dedie
- Fichier ajoute: ReliefShading.pde
- Classes ajoutees:
  - DataShading
  - ShadingGUI
  - ReliefShadingGenerator

### Integration au sketch
- DataGlobal.pde:
  - Ajout du chapitre Shading dans ImgContourData
  - Reset pris en charge (CopyFrom)
- DataGUI.pde:
  - Ajout d'un onglet GUI Shading
- image_contours.pde:
  - Ajout de ReliefShadingGenerator shading_generator
  - Build shading dans le bloc data.any_change()
  - Draw shading apres l'image source, avant les contours

### Config par defaut
- Settings/default.json:
  - Ajout de la section Shading
  - Parametres:
    - draw
    - imageAlpha
    - sun_azimuth_deg
    - sun_altitude_deg
    - z_factor
    - ambient
    - invert

## Details techniques hillshade

- Source elevation:
  - Mode classique: ElevationGrid depuis image transformee (brightness)
  - Mode terrarium: ElevationGrid decode RGB terrarium puis resize/blur
- Formule:
  - Gradient local (dzdx, dzdy)
  - Calcul pente/aspect
  - Eclairement directionnel selon azimuth/altitude du soleil
  - Melange ambient + direct
- z_factor:
  - Multiplie les gradients (exageration verticale)
  - >1 = ombres plus contrastees, <1 = rendu plus doux

## Etat git au moment de ce resume

Fichiers modifies:
- DataGUI.pde
- DataGlobal.pde
- Settings/default.json
- image_contours.pde

Nouveau fichier:
- ReliefShading.pde

Ce fichier de reprise est a commiter aussi:
- REPRISE_MACHINE.md

## Point d'attention

Le fichier Settings/default.json contient actuellement des valeurs de travail (pas des valeurs neutres), par exemple:
- terrarium_mode=true
- contour_levels ~11.29
- lineWidth ~0.45
- image.draw=false
- blur et scale modifies

Si besoin d'un preset plus "propre", creer un second preset dans Settings/ plutot que d'ecraser ce fichier.

## Prochaine etape (a faire)

Implementer le filtre de segments de contours base sur la luminosite de l'image d'ombrage, a la maniere de image_lines/ThresholdFilter:

1. Ajouter un data chapitre dedie (ex: DataContourFilter)
- draw
- black/white mode
- mirror
- nb_values + thresholds
- use_power/power
- min/max

2. Ajouter un GUI tab dedie (ex: ContourFilterGUI)
- sliders/toggles analogues a ThresholdGUI

3. Ajouter un generateur filtre (ex: ContourShadeFilter)
- Entree: group contours source + image d'ombrage
- Sortie: PolylineGroup filtre
- Logique: parcours points, seuil lumineux, close/open segments

4. Brancher le pipeline dans draw()
- build contours source
- build shading image
- build filtered group
- exporter le groupe filtre (file_ui.export_group = groupe final)

5. Eventuel debug utile
- afficher min/max/mean de luminance shading pour aider au reglage des seuils

## Rappel architecture cible

Reference de design: image_lines
- generation source -> post-filtre -> rendu final
- export branche sur resultat final, pas sur la source brute

Ici il faut tendre vers:
- ContourGenerator (source)
- ReliefShadingGenerator (map luminosite)
- ContourShadeFilter (resultat final exportable)
