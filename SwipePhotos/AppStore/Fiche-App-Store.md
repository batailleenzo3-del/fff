# Fiche App Store — textes prêts à copier-coller

Copie ces textes dans App Store Connect (ton app → onglet **Distribution** → version 1.0).
Remplis la version **Français** puis ajoute la langue **Anglais (US)** avec les textes anglais.

---

## 🇫🇷 Français

**Nom de l'app** (30 caractères max, doit être unique sur l'App Store)
```
Swipe Photos – Tri Galerie
```
> Si le nom est déjà pris, essaie : `Swipe Photos : Nettoyeur`, `Swipy – Trier ses photos`…

**Sous-titre** (30 caractères max)
```
Trie tes photos en un swipe
```

**Texte promotionnel** (170 caractères max)
```
Libère des Go en quelques minutes : swipe à droite pour garder, à gauche pour supprimer. Photos, vidéos, albums, mois… tout se trie en un geste.
```

**Description**
```
Ta galerie déborde ? Swipe Photos la remet en ordre en quelques minutes, d'un simple geste du pouce.

• SWIPE À DROITE pour garder, SWIPE À GAUCHE pour jeter
• PHOTOS ET VIDÉOS : les vidéos se lisent directement dans la carte
• CHOISIS CE QUE TU TRIES : toute la galerie, un ou plusieurs albums, ou un mois précis
• ANNULER à tout moment : ton dernier swipe revient en un geste
• CORBEILLE DE SÉCURITÉ : rien n'est supprimé avant que tu le décides, et tu peux récupérer chaque photo
• UNE SEULE CONFIRMATION pour tout supprimer d'un coup
• ESPACE LIBÉRÉ : vois combien de Mo et de Go tu récupères

100 % PRIVÉ
Tes photos ne quittent jamais ton iPhone. Pas de compte, pas de pub, pas de collecte de données.

Les éléments supprimés vont dans « Supprimés récemment » de l'app Photos pendant 30 jours : tu peux toujours changer d'avis.
```

**Mots-clés** (100 caractères max, séparés par des virgules, sans espaces)
```
trier,photos,galerie,nettoyer,supprimer,stockage,espace,doublons,album,vidéos,ranger,cleaner,swipe
```

**Catégorie** : Photo et vidéo (secondaire : Utilitaires)

---

## 🇬🇧 English (U.S.)

**Name**
```
Swipe Photos – Gallery Cleaner
```

**Subtitle**
```
Sort your photos with a swipe
```

**Promotional text**
```
Free up gigabytes in minutes: swipe right to keep, left to delete. Photos, videos, albums, months — sort everything with one gesture.
```

**Description**
```
Is your camera roll overflowing? Swipe Photos cleans it up in minutes, with a simple flick of your thumb.

• SWIPE RIGHT to keep, SWIPE LEFT to delete
• PHOTOS AND VIDEOS: videos play right inside the card
• CHOOSE WHAT TO SORT: your whole library, one or several albums, or a specific month
• UNDO anytime: bring back your last swipe instantly
• SAFE TRASH: nothing is deleted until you decide, and you can restore any photo
• ONE CONFIRMATION to delete everything at once
• SPACE FREED: see how many MB and GB you get back

100% PRIVATE
Your photos never leave your iPhone. No account, no ads, no data collection.

Deleted items go to “Recently Deleted” in the Photos app for 30 days, so you can always change your mind.
```

**Keywords**
```
sort,photos,gallery,clean,cleaner,delete,storage,space,album,videos,organize,swipe,camera roll
```

---

## Notes pour l'équipe de vérification d'Apple (« App Review Information » → Notes)

```
Swipe Photos lets users sort their photo library with swipe gestures.
- Swipe right = keep, swipe left = move to the in-app trash (nothing is deleted yet).
- The trash button (top right) deletes all selected items at once using PHAssetChangeRequest.deleteAssets, which shows the standard iOS confirmation.
- Users can pick the whole library, one or several albums, or a specific month (tap the title at the top left).
- No account, no network access, no data collection. Everything stays on device.
To test: allow full photo library access, then swipe a few photos and open the trash.
```

---

## Confidentialité de l'app (« App Privacy »)

Réponds : **« Non, nous ne collectons aucune donnée de cette app »** (Data Not Collected).

## Classification par âge

Réponds « Aucun » à toutes les questions → l'app sera classée **4+**.

## Captures d'écran (obligatoires)

- Il faut au moins **3 captures** au format iPhone **6,9"** (iPhone Air / Pro Max).
- Fais-les sur ton iPhone Air avec l'app ouverte : bouton latéral + volume haut en même temps.
- Idées : 1) une carte en plein swipe avec le tampon « SUPPRIMER », 2) l'écran de choix d'albums, 3) la corbeille avec « X Go à libérer ».
- L'app est **iPhone uniquement**, donc pas besoin de captures iPad.
