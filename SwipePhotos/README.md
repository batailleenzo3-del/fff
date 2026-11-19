# 📸 Swipe Photos — le guide complet (version 2.3)

Ce dossier contient **tout** : le projet Xcode prêt à ouvrir, l'icône, l'achat intégré, les textes App Store en 5 langues, un studio de captures d'écran et la politique de confidentialité.
Lis ce guide dans l'ordre. Chaque étape est expliquée clic par clic.

---

## Sommaire

1. [Ce que fait l'app](#1-ce-que-fait-lapp)
2. [Contenu du dossier](#2-contenu-du-dossier)
3. [Installer l'app sur ton iPhone](#3-installer-lapp-sur-ton-iphone)
4. [Tester l'achat Pro sans payer](#4-tester-lachat-pro-sans-payer)
5. [Mettre à jour le code plus tard](#5-mettre-à-jour-le-code-plus-tard)
6. [Publier sur l'App Store](#6-publier-sur-lapp-store)
7. [Dépannage](#7-dépannage)

---

## 1. Ce que fait l'app

### Trier
| Geste / bouton | Effet |
|---|---|
| Swipe **à droite** / ♥ | Garder |
| Swipe **à gauche** / ✕ | Corbeille (rien n'est supprimé tout de suite) |
| Swipe **vers le haut** / ★ | Garder **et** mettre en Favori dans l'app Photos |
| ↩︎ | Annuler le dernier swipe |
| **Titre en haut à gauche** | Choisir : toute la galerie, un ou plusieurs albums, ou un mois |
| Onglets **Tout · Photos · Vidéos · Doublons** | Filtrer, ou trouver les photos similaires |
| **↻** | Revenir immédiatement aux photos les plus récentes (point rose = nouvelles photos) |
| **💡** | Idées & bugs : les utilisateurs t'envoient leurs suggestions par e-mail |
| **⚙︎** | Réglages + statistiques |
| **🗑 N** | Corbeille : récupérer des photos ou tout supprimer en **une seule** confirmation |

### Nouveautés de la version 2.3 — personnalisation
- **8 couleurs d'accentuation** (⚙︎ → Personnalisation) : Néon (défaut), Océan, Émeraude, Soleil, Rubis, Or, Lavande, Graphite. Elles changent les boutons, dégradés, fonds lumineux, onglets, confettis… en direct.
- **Transparence du verre** : Discret, Équilibré ou **Maximal** (verre « clair » d'iOS 26, quasi transparent).
- **Fond coloré par la photo** : la photo affichée, très floutée, colore le fond de l'écran — le verre en prend les couleurs (désactivable).
- **Plus de Liquid Glass** : nouvelle barre d'onglets en verre avec pastille animée, boutons qui fusionnent (iOS 26), fonds lumineux aux couleurs du thème.

### Nouveautés de la version 2.1
- **100 swipes gratuits** (garder, supprimer ou favori), puis achat unique **à vie** de la version illimitée (**4,99 €**, prix réglé dans App Store Connect et affiché automatiquement par l'App Store dans la devise de l'utilisateur).
- Le bouton **Annuler** ne rend pas de swipe gratuit, mais re-swiper la même photo ne coûte rien : impossible de contourner la limite, sans pénaliser l'utilisateur.
- Au 100e swipe, l'écran de paiement s'ouvre et les cartes sont **bloquées** (panneau « Limite gratuite atteinte »). Un bandeau prévient quand il reste 20 swipes ou moins.
- Écran de paiement : prix dynamique, **Restaurer mes achats**, chargement pendant la transaction, gestion des annulations et des erreurs.
- Onglet **💡 Idées & bugs** : catégories (Nouvelle fonction, Bug, Design, Autre), champ de texte, infos techniques optionnelles, envoi via l'app Mail pré-remplie (ou Messages, WhatsApp…). Le brouillon est conservé.
- La corbeille, les doublons et les suppressions restent illimités : seul le swipe est compté.

### Nouveautés de la version 2.0
- **Doublons** : l'onglet « Doublons » regroupe les rafales et photos quasi identiques (intelligence artificielle d'Apple, sur l'iPhone). La meilleure est gardée automatiquement, les autres sont cochées pour la corbeille.
- **Plus lourdes d'abord** (Réglages → Ordre) : les grosses vidéos en premier pour libérer de l'espace vite.
- **Tutoriel** au premier lancement (4 pages).
- **Réglages** : ordre de tri, fréquence du retour aux plus récentes (24 h, 48 h, semaine, jamais), thème clair/sombre/auto, vibrations, son des vidéos, revoir le tutoriel, noter l'app, contact, confidentialité.
- **Statistiques** : Go libérés, photos swipées, gardées, favoris, supprimées.
- **Accès limité** : si seules quelques photos sont autorisées, un bandeau permet d'en ajouter.
- **Mise à jour automatique** : une photo supprimée depuis l'app Photos disparaît aussi de Swipe Photos.
- **Messages d'erreur** clairs si une photo/vidéo iCloud est indisponible.
- **Liquid Glass** (iOS 26) sur les boutons et panneaux, **confettis** quand tout est trié ou après une suppression, vibrations plus riches.
- **5 langues** : français, anglais, espagnol, allemand, italien (selon la langue de l'iPhone).
- **iPad** : l'app fonctionne aussi sur iPad, en portrait et paysage.
- **Demande de note** App Store, une seule fois, après une belle suppression.

> 💡 Tu reprends toujours là où tu t'étais arrêté. L'app revient aux photos les plus récentes selon la fréquence choisie dans les Réglages (24 h par défaut) ou quand tu touches ↻.

### Ce qui n'est pas inclus (et pourquoi)
- **Widget d'écran d'accueil** : il nécessite le partage de données entre l'app et le widget (« App Groups »), qui **ne fonctionne pas avec un Apple ID gratuit**. Il pourra être ajouté une fois ton compte développeur payant actif.

---

## 2. Contenu du dossier

```
SwipePhotos/
├── README.md                       ← ce guide
├── SwipePhotos.xcodeproj           ← DOUBLE-CLIQUE ICI pour ouvrir le projet
├── Info.plist                      ← permissions (déjà rempli)
├── SwipePhotos.storekit            ← achat Pro de test (pour essayer sans payer)
├── SwipePhotos/                    ← le code de l'app
│   ├── AppConfig.swift             ← ⚠️ À PERSONNALISER avant publication (e-mail, liens…)
│   ├── SwipePhotosApp.swift        ← point de départ
│   ├── ContentView.swift           ← tutoriel → autorisation → écran principal
│   ├── SwipeScreen.swift           ← écran principal (cartes, swipe, boutons)
│   ├── DuplicatesView.swift        ← onglet Doublons
│   ├── TrashView.swift             ← corbeille
│   ├── SourcePickerView.swift      ← choix albums / mois
│   ├── SettingsView.swift          ← réglages + statistiques
│   ├── PaywallView.swift           ← écran de paiement (version illimitée)
│   ├── FeedbackView.swift          ← onglet Idées & bugs
│   ├── OnboardingView.swift        ← tutoriel
│   ├── MediaViews.swift            ← cartes photo/vidéo, miniatures
│   ├── Effects.swift               ← couleurs de thème, Liquid Glass + transparence, fonds, confettis
│   ├── SwipeStore.swift            ← la logique (pile, corbeille, cycle, stats)
│   ├── LibraryService.swift        ← lecture/suppression dans la galerie
│   ├── SimilarityService.swift     ← détection des doublons
│   ├── LibraryObserver.swift       ← suit les changements de la galerie
│   ├── PurchaseManager.swift       ← achat intégré (StoreKit 2)
│   ├── Models.swift                ← types de données et réglages
│   ├── Localization.swift          ← choix de la langue
│   ├── Strings.swift               ← tous les textes dans les 5 langues
│   ├── Assets.xcassets             ← icône + couleur
│   └── fr/en/es/de/it.lproj        ← texte de la demande d'accès aux photos
└── AppStore/
    ├── Fiche-App-Store.md          ← description, mots-clés (5 langues), achat intégré, notes pour Apple
    ├── studio-captures.html        ← crée tes captures App Store (s'ouvre dans Safari)
    └── politique-de-confidentialite.html ← à mettre en ligne (obligatoire)
```

---

## 3. Installer l'app sur ton iPhone

1. **Décompresse** le zip et mets le dossier **SwipePhotos** dans **Documents** (remplace l'ancien).
2. **Double-clique** sur `SwipePhotos.xcodeproj`.
3. Colonne de gauche → icône bleue **SwipePhotos** → sous **TARGETS** : **SwipePhotos** → onglet **Signing & Capabilities** → **Team** : *Enzo Bataille (Personal Team)*.
   - Erreur sur le Bundle Identifier ? Mets `com.enzobataille.swipephotos2026`.
4. Branche l'iPhone, choisis **ton iPhone** en haut (pas un simulateur), clique sur **▶︎**.

> L'app commence par le **tutoriel**, puis demande l'accès aux photos. Ta progression, ta corbeille et tes statistiques de la version précédente sont conservées.

---

## 4. Tester l'achat Pro sans payer

Le projet est déjà configuré en **mode démo** : quand tu lances l'app avec ▶︎ depuis Xcode, l'achat utilise le fichier `SwipePhotos.storekit` (produit à **4,99 €**). Tout s'affiche comme dans la vraie app : écran de paiement, **vraie fenêtre de paiement Apple** (avec la mention « Environment: Xcode »), Face ID simulé, déblocage, « Restaurer mes achats »… **sans aucun paiement réel**.

### Tester le passage au 100e swipe
1. Lance l'app avec **▶︎** (iPhone branché).
2. ⚙︎ **Réglages** → tout en bas, section **🧪 Mode test** → **Aller à 95 swipes**.
3. Ferme les Réglages et swipe 5 photos : au 100e, l'écran de paiement s'ouvre et les cartes se bloquent.
4. Touche **Débloquer pour 4,99 €** → la fenêtre Apple s'ouvre → confirme : c'est débloqué, les swipes sont illimités.

### Recommencer le test
- ⚙︎ → 🧪 Mode test → **Revenir à la version gratuite** et **Remettre les swipes gratuits à 0**.
- Pour effacer le faux achat lui-même : dans Xcode, menu **Debug → StoreKit → Manage Transactions**, sélectionne l'achat → icône 🗑.

> La section 🧪 Mode test n'apparaît **que** quand l'app est lancée depuis Xcode : elle n'existe pas dans la version App Store.

### Si le prix ne s'affiche pas (« Prix indisponible · Réessayer »)
Le faux achat ne fonctionne que si l'app est lancée **avec ▶︎ depuis Xcode** (pas en l'ouvrant depuis l'écran d'accueil). Dans ce cas un bouton **🧪 Débloquer (test uniquement)** apparaît en secours.
Si le problème persiste même avec ▶︎ : menu **Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration** → choisis **SwipePhotos.storekit**.

### Plus tard : la version finale
Quand ton compte développeur payant sera actif, tu créeras le vrai achat intégré dans App Store Connect (partie 6.4) avec le même identifiant que `proProductID`. **Le code ne change pas** : sur l'App Store, la même fenêtre Apple débitera de vrais paiements.

---

## 5. Mettre à jour le code plus tard

- **Un fichier** : clique dessus dans Xcode, **⌘ A**, colle le nouveau code (**⌘ V**), **⌘ S**, puis ▶︎.
- **Tout le dossier** : ferme Xcode, remplace le dossier `SwipePhotos/SwipePhotos/` par le nouveau, rouvre le projet. Les nouveaux fichiers `.swift` sont pris en compte automatiquement.
- **Modifier un texte de l'app** : ouvre `Strings.swift`, cherche le texte, change-le dans la bonne langue.
- **Publier une mise à jour** : onglet **General** → augmente **Version** (`1.0` → `1.1`) et **Build** (`1` → `2`), puis refais la partie 6.6.

---

## 6. Publier sur l'App Store

### 6.1 Prérequis
- **Apple Developer Program : 99 €/an** — <https://developer.apple.com/programs/enroll/> → « Individual ».
- **Statut micro-entrepreneur** recommandé pour déclarer les revenus (autoentrepreneur.urssaf.fr).

### 6.2 Personnaliser `AppConfig.swift`
Ouvre `SwipePhotos/AppConfig.swift` et remplis :
- `privacyPolicyURL` : l'adresse de ta politique de confidentialité en ligne (voir 6.3).
- `supportEmail` : une adresse e-mail de contact dédiée (ex : swipephotos.app@gmail.com).
- `feedbackEmail` : ⚠️ **ton adresse e-mail** qui recevra les idées et bugs (remplace `ton.email@exemple.com`).
- `proProductID` : ⚠️ remplace le placeholder `com.monapp.unlimited` par ton identifiant définitif (ex : `com.enzobataille.swipephotos.unlimited`) — **le même** que dans App Store Connect. Pense aussi à le changer dans `SwipePhotos.storekit` (ouvre-le dans Xcode).
- `appStoreID` : à remplir **après** la création de l'app dans App Store Connect (« Identifiant Apple », 10 chiffres). Pas obligatoire pour la 1ʳᵉ version.

### 6.3 Politique de confidentialité (obligatoire)
1. Ouvre `AppStore/politique-de-confidentialite.html` avec **TextEdit**, remplace `[TON E-MAIL DE CONTACT]` et `[DATE]`.
2. Mets le texte en ligne (page **Notion** publique ou **Google Doc** « Tous les utilisateurs disposant du lien ») et copie l'adresse dans `AppConfig.swift` et dans App Store Connect.

### 6.4 Créer l'app et l'achat intégré
1. <https://appstoreconnect.apple.com> → **Apps** → **+** → **Nouvelle app** : iOS, nom (voir la fiche), langue Français, Bundle ID `com.enzobataille.swipephotos`, SKU `swipephotos001`.
2. **Business** (« Accords, taxes et banques ») → signe le **Paid Apps Agreement**, remplis **RIB** et **infos fiscales** (obligatoire même pour une app gratuite avec achat intégré).
3. **Prix et disponibilité** → **Gratuit**.
4. **Achats intégrés** → **+** → **Non consommable** → identifiant = celui de `proProductID` → prix **4,99 €** (détails dans `AppStore/Fiche-App-Store.md`).
5. Inscris-toi au **Small Business Program** (<https://developer.apple.com/app-store/small-business-program/>) : Apple ne prend que **15 %** → tu touches ≈ **3,50 €** par achat à 4,99 € en France.

### 6.5 Remplir la fiche
- Textes en **5 langues** : copie-colle depuis `AppStore/Fiche-App-Store.md`.
- **Captures** : ouvre `AppStore/studio-captures.html` dans Safari, importe tes captures, choisis un texte, télécharge. Il faut des captures **iPhone 6,9"** **et** **iPad 13"** (simulateur iPad dans Xcode → ⌘ S pour capturer).
- **Confidentialité** : « Aucune donnée collectée ». **Âge** : 4+.
- **DSA (UE)** : déclare-toi **commerçant** (app avec achat intégré). ⚠️ Ton adresse, téléphone et e-mail seront **publics** : utilise une adresse e-mail dédiée et, si possible, une domiciliation.
- **Notes pour Apple** : copie le bloc de la fiche.

### 6.6 Envoyer l'app
1. **Signing & Capabilities** → **Team** : ton **compte payant**.
2. En haut d'Xcode : **Any iOS Device (arm64)**.
3. **Product → Archive** → **Distribute App** → **App Store Connect** → **Distribute**.
4. Après ~15 min, dans App Store Connect : version 1.0 → **Build** → **+** → choisis-le. Ajoute aussi l'**achat intégré** à la version.
5. **Ajouter pour vérification** → **Soumettre**. Réponse en 24–48 h en général.

> 💡 Teste d'abord via **TestFlight** (onglet TestFlight d'App Store Connect) : c'est la vraie version, avec de faux achats.

### 6.7 Si Apple refuse
Lis le message dans le **Centre de résolution**, corrige, augmente le **Build**, refais **Archive**, resoumets. Refus fréquents : 2.1 (bug → teste sans Xcode), 3.1.1 (achat → vérifie que l'achat intégré est ajouté à la version), 5.1.1 (lien de confidentialité manquant).

---

## 7. Dépannage

| Problème | Solution |
|---|---|
| Erreur rouge à la compilation | Clique sur l'erreur, copie le texte (ou fais une photo) et envoie-le à Claude |
| `Signing … requires a development team` | Partie 3, étape 3 |
| `Failed Registering Bundle Identifier` | Change le Bundle Identifier (ajoute des chiffres) |
| L'app se met en pause avec une ligne verte/rouge dans Xcode | Clique sur **▶︎ Continue** (barre du bas) ou lance l'app depuis l'écran d'accueil |
| « Prix indisponible · Réessayer » sur l'écran de paiement | Normal en test sans fichier StoreKit (ou tant que l'achat intégré n'existe pas dans App Store Connect) : utilise le bouton 🧪 ou la partie 4.B |
| « Envoyer par e-mail » ne fait rien | Aucune app Mail configurée : l'app propose de copier le message ; ou utilise « Envoyer autrement » |
| Doublons : l'analyse est longue | Normal la 1ʳᵉ fois sur une grosse galerie (elle tourne sur l'iPhone). Les photos uniquement sur iCloud sont ignorées |
| Trop / pas assez de doublons détectés | Change `similarityThreshold` dans `AppConfig.swift` (plus petit = plus strict) |
| Seulement quelques photos visibles | Accès limité : touche **Gérer** dans le bandeau, ou Réglages iPhone → Swipe Photos → Photos → Accès complet |
| L'espace ne se libère pas | Vide **Photos → Supprimés récemment** |
| L'app ne s'ouvre plus après 7 jours | Compte gratuit : rebranche l'iPhone et clique sur ▶︎ |
