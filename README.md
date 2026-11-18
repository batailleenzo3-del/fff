# Swipe Photos 📸

App iPhone (SwiftUI + PhotoKit) pour trier sa galerie façon Tinder.

- **Swipe à droite** : garder
- **Swipe à gauche** : corbeille temporaire (rien n'est supprimé tout de suite)
- **↩︎ Annuler** : revient sur la photo précédente
- **Bouton corbeille en haut** : affiche le nombre de photos et supprime tout d'un coup → **une seule** pop-up de confirmation iOS
- Touche une photo dans la corbeille pour la récupérer
- La progression est mémorisée : en rouvrant l'app, tu reprends là où tu t'étais arrêté

## Installer sur ton iPhone (il faut un Mac avec Xcode)

1. **Xcode → File → New → Project → iOS → App**
   - Product Name : `SwipePhotos`, Interface : **SwiftUI**, Language : **Swift**
2. Remplace tout le contenu de `ContentView.swift` par celui de [`SwipePhotos/ContentView.swift`](SwipePhotos/ContentView.swift).
3. **Permission galerie** : clique sur le projet (icône bleue) → cible *SwipePhotos* → onglet **Info** → `+` et ajoute :
   - Clé : **Privacy - Photo Library Usage Description** (`NSPhotoLibraryUsageDescription`)
   - Valeur : `L'app a besoin d'accéder à tes photos pour te permettre de les trier et supprimer celles que tu ne veux plus.`
4. Onglet **Signing & Capabilities** → coche *Automatically manage signing* → **Team** : ton Apple ID (un compte gratuit suffit).
5. Branche ton iPhone en USB (ou même Wi-Fi), sélectionne-le en haut d'Xcode, puis ▶︎ **Run**.
6. Sur l'iPhone, la 1ʳᵉ fois :
   - **Réglages → Confidentialité et sécurité → Mode développeur** → activer (redémarrage).
   - **Réglages → Général → VPN et gestion de l'appareil** → faire confiance à ton profil développeur.
7. À l'ouverture, choisis **Autoriser l'accès complet** aux photos.

> Avec un Apple ID gratuit, l'app expire au bout de 7 jours : il suffit de relancer ▶︎ Run depuis Xcode.
> Les photos supprimées vont dans **Supprimés récemment** de l'app Photos (récupérables 30 jours).

Cible minimale : iOS 17.
