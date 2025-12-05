# Entity Monitor

Dashboard Admin pour surveiller et diagnostiquer les problemes de pool size sur FiveM.

## Fonctionnalites

### Dashboard Principal
- Comptage en temps reel des entites (Vehicules, Peds, Objets)
- Classement des ressources par nombre d'entites creees
- Infos serveur (joueurs connectes, nombre de ressources)
- Auto-refresh optionnel (5 secondes)

### Mode Debug
- Blips sur la map pour localiser les entites "unknown"
- Detection automatique des MLO suspects (zones avec 5+ entites regroupees)
- Markers 3D au-dessus des entites problematiques (< 50m)
- Texte 3D avec type et modele (< 15m)
- Teleportation vers les zones suspectes

### Analyseur de Problemes
- **Props vetements orphelins** : chapeaux, sacs, lunettes, masques, parachutes...
- **Vehicules abandonnes** : sans conducteur, a plus de 100m de tout joueur
- **Entites hors map** : Z < -50 ou Z > 1500
- **Objets dupliques** : plusieurs entites au meme endroit exact
- Boutons de nettoyage par categorie

## Installation

1. Placer le dossier `entity-monitor` dans votre dossier resources
2. Ajouter dans votre `server.cfg` :
```cfg
ensure entity-monitor
```

## Permissions

Le script utilise les permissions ACE standard de FiveM.
Seuls les joueurs avec `group.admin` peuvent acceder au dashboard.

```cfg
add_principal identifier.license:xxxx group.admin
```

## Utilisation

### Commandes
| Commande | Description |
|----------|-------------|
| `/entitymonitor` | Ouvre le dashboard |
| `/em` | Alias court |

### Raccourci
| Touche | Action |
|--------|--------|
| `F7` | Ouvre/Ferme le dashboard |
| `ESC` | Ferme le dashboard |

### Interface

**Boutons Header :**
- **Loupe** : Analyser les problemes (vetements, vehicules orphelins, hors map, duplicatas)
- **Bug** : Mode debug (blips et markers sur les entites unknown)
- **Refresh** : Rafraichir les donnees
- **Horloge** : Activer/desactiver l'auto-refresh

**Couleurs des blips (Mode Debug) :**
- Jaune : Vehicules
- Vert : Peds
- Orange : Objets
- Rouge : MLO suspect

## Structure

```
entity-monitor/
├── fxmanifest.lua
├── client.lua
├── server.lua
├── README.md
└── html/
    ├── index.html
    ├── style.css
    └── script.js
```

## Diagnostic Pool Size

### Causes frequentes de problemes de pool
1. **MLO mal optimises** - Trop d'objets statiques
2. **Scripts de vetements** - Props non supprimes apres changement
3. **Vehicules spawnes** - Non supprimes quand le joueur se deconnecte
4. **Peds de missions** - Non nettoyes apres la mission
5. **Objets de props** - Decorateurs, meubles places par les joueurs

### Solutions
1. Identifier les ressources avec le plus d'entites
2. Utiliser le mode debug pour localiser les zones problematiques
3. Nettoyer les props vetements orphelins
4. Verifier les MLO suspects
5. Redemarrer les ressources fautives si necessaire

## Notes Techniques

- Le tracking des entites par ressource utilise `entityCreated` / `entityRemoved`
- Les entites creees avant le demarrage du script apparaissent comme "unknown"
- Un redemarrage serveur permet un tracking complet
- Les blips/markers sont visibles uniquement par l'admin qui active le debug

## Credits

Developpe par ezekielmsc
