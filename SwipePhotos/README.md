# 📸 Swipe Photos — le guide complet

Ce dossier contient **tout** : le projet Xcode prêt à ouvrir, l'icône, les textes App Store et la politique de confidentialité.
Lis ce guide dans l'ordre. Chaque étape est expliquée clic par clic.

---

## Sommaire

1. [Ce que fait l'app](#1-ce-que-fait-lapp)
2. [Contenu du dossier](#2-contenu-du-dossier)
3. [Installer l'app sur ton iPhone](#3-installer-lapp-sur-ton-iphone)
4. [Mettre à jour le code plus tard](#4-mettre-à-jour-le-code-plus-tard)
5. [Si le projet ne s'ouvre pas (plan B)](#5-si-le-projet-ne-souvre-pas-plan-b)
6. [Publier sur l'App Store à 2,99 €](#6-publier-sur-lapp-store-à-299-)
7. [Dépannage](#7-dépannage)

---

## 1. Ce que fait l'app

| Fonction | Comment |
|---|---|
| **Garder** | Swipe à droite (ou bouton ♥) |
| **Jeter** | Swipe à gauche (ou bouton ✕). La photo va dans une corbeille : **rien n'est supprimé tout de suite** |
| **Annuler** | Bouton jaune ↩︎ : la dernière carte revient |
| **Mode normal** | À chaque ouverture, l'app montre **toujours les photos les plus récentes en premier**, même celles que tu avais déjà gardées |
| **Choisir quoi trier** | Touche le **titre en haut à gauche** (« Récentes ⌄ ») : toute la galerie, **un ou plusieurs albums** (coche-les), ou **un mois précis** |
| **Photos / Vidéos** | Le sélecteur « Tout · Photos · Vidéos » sous le titre |
| **Vidéos** | Elles se lisent dans la carte, en boucle, sans le son. Bouton 🔈 pour activer le son |
| **Taille** | Chaque carte affiche son poids (ex : « 4,2 Mo ») |
| **Corbeille** | Bouton rouge en haut à droite : touche une photo pour la récupérer, « Tout garder » pour tout annuler |
| **Tout supprimer** | Dans la corbeille : **une seule** confirmation iOS pour tout effacer |
| **Espace libéré** | Affiché après chaque suppression et en haut de l'écran (total depuis le début) |
| **Langues** | Français et anglais, automatiquement selon la langue de l'iPhone |

> 💡 La corbeille de l'app est **conservée** même si tu fermes l'app : les photos mises de côté ne réapparaissent pas dans la pile tant que tu ne les as pas récupérées ou supprimées.
>
> Si tu quittes l'app plus de 5 minutes, elle repart automatiquement des photos les plus récentes.

---

## 2. Contenu du dossier

```
SwipePhotos/
├── README.md                     ← ce guide
├── SwipePhotos.xcodeproj         ← DOUBLE-CLIQUE ICI pour ouvrir le projet
├── Info.plist                    ← permissions (accès aux photos) — déjà rempli
├── SwipePhotos/                  ← le code de l'app
│   ├── SwipePhotosApp.swift      ← point de départ
│   ├── ContentView.swift         ← écran principal (pile de cartes, swipe)
│   ├── SourcePickerView.swift    ← choix albums / mois
│   ├── TrashView.swift           ← la corbeille
│   ├── MediaViews.swift          ← cartes photo/vidéo, miniatures
│   ├── SwipeStore.swift          ← la logique (pile, corbeille, annuler, stats)
│   ├── LibraryService.swift      ← lecture et suppression dans la galerie
│   ├── Models.swift              ← types de données
│   ├── Localization.swift        ← textes français / anglais
│   ├── Assets.xcassets           ← icône de l'app + couleur
│   ├── fr.lproj / en.lproj       ← texte de la demande d'accès aux photos
└── AppStore/
    ├── Fiche-App-Store.md        ← description, mots-clés, notes pour Apple (FR + EN)
    └── politique-de-confidentialite.html ← page à mettre en ligne (obligatoire)
```

Tout est déjà réglé dans le projet : permission Photos, icône, nom « Swipe Photos », catégorie Photo, iPhone uniquement, mode portrait, français + anglais.

---

## 3. Installer l'app sur ton iPhone

### Étape 1 — Mettre le dossier au bon endroit
1. Décompresse le fichier `.zip` (double-clic dessus).
2. Glisse le dossier **SwipePhotos** dans ton dossier **Documents** (ou sur le Bureau).
   ⚠️ Pas dans iCloud Drive « Optimiser le stockage » : Xcode n'aime pas les fichiers qui ne sont pas téléchargés.

### Étape 2 — Ouvrir le projet
1. Ouvre le dossier **SwipePhotos**.
2. **Double-clique sur `SwipePhotos.xcodeproj`**. Xcode s'ouvre.
3. Ferme l'ancien « Untitled Project » s'il est encore ouvert (tu n'en as plus besoin).

### Étape 3 — Choisir ton compte (signature)
1. Dans la colonne de gauche, clique sur l'icône bleue **SwipePhotos** (tout en haut).
2. Au milieu, sous **TARGETS**, clique sur **SwipePhotos**.
3. Onglet **Signing & Capabilities**.
4. **Team** : choisis **Enzo Bataille (Personal Team)** (ou ton compte développeur payant plus tard).
5. **Bundle Identifier** : il est déjà réglé sur `com.enzobataille.swipephotos`.
   Si une erreur rouge dit qu'il n'est pas disponible, ajoute des chiffres : `com.enzobataille.swipephotos2026`.

### Étape 4 — Lancer sur l'iPhone
1. Branche l'iPhone, déverrouille-le.
2. En haut d'Xcode, à côté de « SwipePhotos › », choisis **ton iPhone**.
3. Clique sur **▶︎**.
4. Sur l'iPhone, l'app **Swipe Photos** apparaît avec la nouvelle icône.
   L'ancienne app « MyApp » peut être supprimée (appui long → Supprimer l'app).

> Si l'iPhone affiche « Développeur non approuvé » : **Réglages → Général → VPN et gestion de l'appareil** → ton Apple ID → **Faire confiance**.

> ⏳ Avec un Apple ID gratuit, l'app expire après **7 jours** : rebranche l'iPhone et clique sur ▶︎ pour la réactiver. Avec le compte développeur payant (99 €/an), elle dure 1 an.

> 🚀 L'app est plus lente quand elle est lancée depuis Xcode (mode débogage). Pour la tester à pleine vitesse : clique sur ■ dans Xcode, puis ouvre-la directement depuis l'écran d'accueil.

---

## 4. Mettre à jour le code plus tard

Quand tu reçois une nouvelle version du code (par exemple un fichier `ContentView.swift` corrigé) :

**Méthode simple — remplacer le contenu d'un fichier**
1. Dans Xcode, colonne de gauche, clique sur le fichier à modifier (ex : **ContentView**).
2. Clique dans le code, **⌘ A** (tout sélectionner), **Suppr**.
3. Colle le nouveau code (**⌘ V**), puis **⌘ S** pour enregistrer.
4. Clique sur **▶︎**.

**Méthode dossier — remplacer des fichiers entiers**
1. Ferme Xcode.
2. Dans le Finder, remplace les anciens fichiers du dossier `SwipePhotos/SwipePhotos/` par les nouveaux (même nom).
3. Rouvre `SwipePhotos.xcodeproj` et clique sur **▶︎**.
   Les nouveaux fichiers `.swift` ajoutés dans ce dossier sont pris en compte automatiquement.

**Pour publier une mise à jour sur l'App Store**
1. Onglet **General** → augmente **Version** (ex : `1.0` → `1.1`) et **Build** (ex : `1` → `2`).
2. Refais l'étape « Envoyer l'app » de la partie 6 (Product → Archive…).

---

## 5. Si le projet ne s'ouvre pas (plan B)

Si Xcode refuse d'ouvrir `SwipePhotos.xcodeproj` (« damaged » ou erreur), recrée un projet en 5 minutes :

1. Xcode → **File → New → Project…** → **iOS** → **App** → **Next**.
2. Product Name : `SwipePhotos` · Team : ton compte · Organization Identifier : `com.enzobataille` · Interface : **SwiftUI** · Language : **Swift** → **Next** → enregistre-le **ailleurs** (ex : Bureau).
3. Dans la colonne de gauche, **supprime** `ContentView.swift` et `SwipePhotosApp.swift` créés par Xcode (clic droit → Delete → Move to Trash).
4. Depuis le Finder, **glisse tous les fichiers `.swift`** de `SwipePhotos/SwipePhotos/` (ce dossier-ci) dans la colonne de gauche d'Xcode, dans le dossier jaune/bleu `SwipePhotos`. Coche **Copy items if needed** → **Finish**.
5. Remplace le dossier **Assets** : supprime `Assets` dans Xcode, puis glisse `Assets.xcassets` de ce dossier.
6. Permission Photos : cible **SwipePhotos** → onglet **Info** → **+** → `Privacy - Photo Library Usage Description` → valeur : `Pour afficher et trier tes photos`.
7. **▶︎**.

---

## 6. Publier sur l'App Store à 2,99 €

### 6.1 Ce qu'il te faut
- **Apple Developer Program : 99 €/an** — obligatoire pour publier. Inscription : <https://developer.apple.com/programs/enroll/> → « Individual » (particulier). Validation : quelques heures à 2 jours.
- **Une page web pour la politique de confidentialité** (obligatoire) : le fichier `AppStore/politique-de-confidentialite.html` est prêt.
  1. Ouvre-le avec TextEdit et remplace `[TON E-MAIL DE CONTACT]` et `[DATE]`.
  2. Mets-le en ligne gratuitement, par exemple : copie le texte dans une page **Notion** publique ou un **Google Doc** partagé « Tous les utilisateurs disposant du lien », et garde l'adresse (URL).
- **Statut fiscal** : les ventes sont des revenus → en France, le plus simple est le statut **micro-entrepreneur** (autoentrepreneur.urssaf.fr).

### 6.2 Préparer le projet
1. Projet → cible **SwipePhotos** → **Signing & Capabilities** → **Team** : choisis ton **compte payant** (plus « Personal Team »).
2. Onglet **General** : vérifie Version `1.0`, Build `1`.

### 6.3 Créer l'app dans App Store Connect
1. Va sur <https://appstoreconnect.apple.com> → **Apps** → **+** → **Nouvelle app**.
2. Plateforme **iOS** · Nom : voir `AppStore/Fiche-App-Store.md` · Langue principale **Français** · Bundle ID : `com.enzobataille.swipephotos` · SKU : `swipephotos001` · Accès : complet.

### 6.4 Fixer le prix à 2,99 €
1. **Business** (ou « Accords, taxes et banques ») → signe le **Paid Apps Agreement** (contrat apps payantes), puis remplis **coordonnées bancaires (RIB)** et **informations fiscales**. Sans ça, impossible de vendre.
2. Ton app → **Prix et disponibilité** → pays de référence **France** → prix **2,99 €**. Apple calcule les prix des autres pays.
3. Inscris-toi au **App Store Small Business Program** (<https://developer.apple.com/app-store/small-business-program/>) : Apple ne prend que **15 %** au lieu de 30 %.
   → Sur une vente à 2,99 € en France, tu touches environ **2,10 €** (après TVA 20 % et commission 15 %).

### 6.5 Remplir la fiche
Tout est prêt dans **`AppStore/Fiche-App-Store.md`** : nom, sous-titre, description, mots-clés (FR + EN), notes pour Apple, réponses confidentialité.
- **Captures d'écran** : au moins 3 au format iPhone 6,9" (fais-les sur ton iPhone Air).
- **Confidentialité de l'app** : « Aucune donnée collectée ».
- **URL de la politique de confidentialité** : celle de l'étape 6.1.
- **Statut de commerçant (DSA — obligatoire dans l'UE)** : app payante → tu dois te déclarer **commerçant**. ⚠️ Ton adresse, ton téléphone et ton e-mail seront **affichés publiquement** sur la fiche. Utilise une adresse e-mail dédiée et, si possible, une adresse professionnelle (domiciliation).

### 6.6 Envoyer l'app à Apple
1. Dans Xcode, en haut, choisis **Any iOS Device (arm64)** à la place de ton iPhone.
2. Menu **Product → Archive**. Attends la fin (1 à 3 min).
3. La fenêtre **Organizer** s'ouvre → **Distribute App** → **App Store Connect** → **Distribute**.
4. Attends ~15 min que le build apparaisse dans App Store Connect (onglet **TestFlight**).
5. Dans ta version 1.0 → section **Build** → **+** → choisis le build.
6. **Ajouter pour vérification** → **Soumettre**.
7. Apple répond en général en **24 à 48 h** par e-mail.

> 💡 Bonus : avant de publier, installe l'app via **TestFlight** sur ton iPhone pour la tester dans les vraies conditions.

### 6.7 Si Apple refuse
Pas de panique, c'est fréquent la première fois. Lis le message dans App Store Connect (**Centre de résolution**), corrige, augmente le **Build** (`2`, `3`…), refais **Archive** et resoumets. Les refus les plus courants :
- **2.1 – App incomplète / bug** → teste bien sur ton iPhone sans Xcode.
- **4.3 – Spam / app trop similaire** → mets en avant ce qui rend l'app unique (tri par mois, albums multiples, vidéos, espace libéré).
- **5.1.1 – Confidentialité** → vérifie l'URL de la politique de confidentialité.

---

## 7. Dépannage

| Problème | Solution |
|---|---|
| `Signing for "SwipePhotos" requires a development team` | Étape 3 : choisis ta **Team** |
| `Failed Registering Bundle Identifier` | Change le Bundle Identifier (ajoute des chiffres) |
| L'app se ferme dès qu'on touche « Autoriser » | La permission Photos manque : vérifie que `Info.plist` contient `NSPhotoLibraryUsageDescription` (déjà fait dans ce projet) |
| « Copying OS libraries… » très long | Normal la 1ʳᵉ fois avec un iPhone : attends 5–15 min |
| L'app semble figée | Lance-la sans Xcode (■ puis ouvre-la depuis l'écran d'accueil). Le premier chargement d'une grosse galerie prend quelques secondes |
| Seulement quelques photos visibles | Tu as choisi « accès limité » : **Réglages → Swipe Photos → Photos → Accès complet** |
| L'espace ne se libère pas | Les photos supprimées restent 30 jours dans **Photos → Supprimés récemment** : vide cet album |
| L'app ne s'ouvre plus après 7 jours | Compte gratuit : rebranche l'iPhone et clique sur ▶︎ |
| Erreur rouge à la compilation | Fais une capture de l'écran (ou clique sur l'erreur → copie le texte) et envoie-la à Claude |
