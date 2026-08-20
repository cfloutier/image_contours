# image_contours — Développement

Notes d'implémentation, pipeline, et procédure de build pour `image_contours`. Pour l'usage/les paramètres, voir [README.md](README.md).

---

## Mise en place pour développer

Uniquement nécessaire pour ouvrir/modifier/lancer le sketch depuis les sources — pas nécessaire pour juste lancer une release (voir [README.md](README.md#getting-a-release)).

1. **Installer Processing** : télécharger depuis https://processing.org/download et installer (mode Java, celui par défaut).
2. **Installer ControlP5** : dans l'IDE Processing, `Sketch > Import Library... > Manage Libraries...`, chercher **ControlP5**, cliquer Install. La lib est alors installée directement dans le dossier `libraries/` du sketchbook — pas de téléchargement/dézippage manuel. (Page de la lib, pour référence : http://www.sojamo.de/libraries/controlP5)
3. Ouvrir `image_contours.pde` dans Processing et lancer.

---

## Pipeline actuel

1. `DataImage.buildTransformedImage()` prepare l'image transformee.
2. `rebuildIfNeeded()` (dans `image_contours.pde`) decide quoi recalculer, decouple par chapitre :
   - changement image => rebuild contours + shading + shore (le shore depend aussi de l'image)
   - changement contour => rebuild contours seulement
   - changement shading => rebuild shading seulement
   - changement threshold (filtre) => rebuild du filtre uniquement, pas des contours/shading eux-memes
   - changement shore => rebuild shore uniquement
   - le filtre (`ContourShadeFilter`) est reconstruit des que contours, shading ou threshold changent
   - `display_group` (ce que `drawFiltered()` affiche) et `export_group` (fusion contours filtres + shore + vagues, utilise a l'identique pour l'affichage et l'export) sont reconstruits des que le filtre ou le shore changent
3. Rendu :
   - image source (optionnelle)
   - shading relief (optionnel)
   - contours (optionnels, apres filtrage)
   - shore + lignes de vagues (si actif)

### Modules principaux

- `ElevationGrid.pde` : adaptation source (classic + Terrarium decode-first)
- `MarchingSquares.pde` : algo contour pur (reutilisable)
- `ContourGenerator.pde` : glue data -> algo -> groupe de lignes
- `ReliefShading.pde` : hillshade + GUI shading
- `DataShore.pde` : ligne de rivage (contour a une seule elevation `shore_level`) + lignes de "vagues" (offsets geometriques du rivage, sans lien avec la carte d'elevation)
- `ContourShadeFilter.pde` : filtre les segments de contour selon la luminosite de l'image de shading, reutilise `DataThreshold`/`ThresholdGUI` (partage avec `image_lines`, `xLib_ThresholdData.pde`) — deja implemente, pas juste une piste (voir Statut dev plus bas)

### HUD

Un HUD en bas affiche :

- nombre total de lignes de contour
- temps du dernier calcul contour
- temps du dernier calcul shore
- temps du dernier rendu (draw)

---

## Statut dev

Base stable :

- generation contours fonctionnelle (classic + Terrarium)
- shading relief fonctionnel (incluant contrast/gamma)
- outil bbox Terrarium outille pour production data
- rebuild decouple (image / contour / shading / threshold / shore)
- `ContourShadeFilter` (filtre les segments de contour selon la luminosite du shading, via `DataThreshold`) — implemente et branche dans le pipeline
- `DataShore` (ligne de rivage + lignes de vagues offset) — implemente, onglet **Shore** dedie

Prochaine etape candidate : passer le mode Perlin en decodage Terrarium (actuellement
seul un fichier image peut utiliser le mode Terrarium ; la carte procedurale Perlin
reste en luminosite brute).

---

## Building a Release

`export_app.ps1` (racine du projet) construit une application autonome, sans installeur, et la packages en zip.

```powershell
.\export_app.ps1
```

Ce que ça fait :
1. Exporte le sketch en application autonome via `processing-java --export` (embarque un JRE et toutes les libs, dont ControlP5 — rien à installer côté utilisateur final).
2. Copie `Settings/` dans l'export (l'étape d'export Processing ne l'inclut **pas**, et le sketch plante au démarrage sans `Settings/default.json` à charger).
3. Zippe le résultat dans `releases/image_contours_<variant>_<date>.zip`, prêt à distribuer.

Options utiles :
```powershell
.\export_app.ps1 -ProcessingPath "D:\tools\processing-4.3\processing-java.exe"  # autre installation Processing
.\export_app.ps1 -Zip $false                                                    # sans le zip de release
```

**Remarque :** le build cible toujours l'OS sur lequel le script tourne — `-Variant` ne cross-compile pas pour une autre plateforme (vérifié empiriquement : demander `linux-amd64` depuis Windows produit quand même un build Windows). Pour un vrai build macOS ou Linux, lance ce script depuis une machine tournant sous cet OS.
