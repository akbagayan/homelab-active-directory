# Active Directory — Version 2

## Unités d’organisation, groupes de sécurité, partage SMB et GPO

Cette deuxième partie poursuit le déploiement du HomeLab Active Directory. Elle explique comment organiser les objets du domaine, attribuer des accès à un service, publier un dossier partagé et appliquer une configuration de bureau avec une stratégie de groupe.

> [!WARNING]
> Ce guide est destiné à un laboratoire isolé. Les noms, comptes, chemins et droits doivent être adaptés avant toute utilisation en production.

## Objectifs

À la fin de cette partie, le laboratoire doit permettre de :

- organiser les utilisateurs dans une unité d’organisation ;
- créer un groupe de sécurité pour le service Ingénierie ;
- gérer les autorisations par groupe plutôt que par utilisateur ;
- créer un partage de fichiers SMB ;
- configurer correctement les permissions de partage et NTFS ;
- vérifier qu’un membre autorisé accède au dossier ;
- vérifier qu’un utilisateur non autorisé reçoit un refus ;
- mapper le partage comme lecteur réseau ;
- créer une GPO liée à l’OU du service ;
- déployer automatiquement un fond d’écran ;
- diagnostiquer l’application d’une GPO.

## Architecture logique

| Élément | Utilisation dans le laboratoire |
|---|---|
| Contrôleur de domaine | `DC` |
| Domaine | `bagayan.local` |
| OU cible | `_ENGINEERING` |
| Groupe de sécurité | `FilePartagerEngenieur` |
| Partage SMB | `FilePartagerEngenieur` |
| Chemin UNC | `\\DC\FilePartagerEngenieur` |
| Lecteur réseau de test | `Z:` |
| GPO | `ImageDeFondEngenieur` |
| Utilisateur autorisé | Paul Kebre |
| Utilisateur non autorisé | Aba |

## 1. Comprendre les unités d’organisation

Une **OU** (Organizational Unit, ou unité d’organisation) est un conteneur logique dans Active Directory. Elle permet de classer les utilisateurs, ordinateurs et groupes selon leur service ou leur fonction.

Dans ce laboratoire, l’OU `_ENGINEERING` regroupe les objets du service Ingénierie. Cette organisation facilite :

- l’administration des comptes ;
- la délégation de certaines tâches ;
- l’application ciblée des GPO ;
- la lecture de la structure du domaine.

Une OU ne constitue pas automatiquement une frontière de sécurité. Les droits d’accès aux fichiers sont attribués avec des groupes et des listes de contrôle d’accès.

## 2. Créer le groupe de sécurité

Dans **Utilisateurs et ordinateurs Active Directory** :

1. ouvrir l’OU `_ENGINEERING` ;
2. créer un nouvel objet **Groupe** ;
3. saisir `FilePartagerEngenieur` ;
4. sélectionner la portée **Globale** ;
5. sélectionner le type **Sécurité** ;
6. ajouter les utilisateurs du service, notamment Paul Kebre ;
7. vérifier la liste des membres.

Un groupe global sert généralement à rassembler les comptes qui possèdent la même fonction. Il vaut mieux attribuer les permissions à un groupe qu’à chaque utilisateur individuellement.

### Méthode AGDLP

La méthode recommandée est :

1. **A — Accounts** : comptes utilisateurs ;
2. **G — Global groups** : groupes globaux correspondant aux métiers ;
3. **DL — Domain Local groups** : groupes locaux de domaine correspondant aux ressources ;
4. **P — Permissions** : permissions attribuées aux groupes locaux.

Pour un petit laboratoire, le groupe global peut recevoir directement les droits. Pour une architecture plus propre et évolutive, utilisez toute la chaîne AGDLP.

## 3. Créer le partage de fichiers SMB

**SMB** (Server Message Block) est le protocole utilisé par Windows pour partager des fichiers, dossiers et imprimantes sur le réseau.

Depuis le **Gestionnaire de serveur** :

1. ouvrir **Services de fichiers et de stockage** ;
2. sélectionner **Partages** ;
3. lancer **Nouveau partage** ;
4. choisir un partage SMB adapté ;
5. sélectionner le volume et le dossier ;
6. nommer le partage `FilePartagerEngenieur` ;
7. vérifier le chemin local et le chemin UNC ;
8. configurer les permissions ;
9. confirmer puis créer le partage.

Le chemin utilisé par les clients est :

```text
\\DC\FilePartagerEngenieur
```

Un chemin **UNC** (Universal Naming Convention) désigne une ressource réseau avec la forme `\\serveur\partage`.

## 4. Configurer les permissions

Deux couches de permissions s’appliquent à un dossier partagé :

- les permissions de partage SMB ;
- les permissions du système de fichiers NTFS.

Lors d’un accès par le réseau, Windows combine les deux couches et applique le résultat le plus restrictif.

### Permissions recommandées

| Identité | Permission conseillée |
|---|---|
| SYSTEM | Contrôle total |
| Administrators | Contrôle total |
| Groupe du service Ingénierie | Modifier |
| Utilisateurs non autorisés | Aucun droit |

Pour sécuriser le dossier :

1. ouvrir les paramètres de sécurité avancés ;
2. désactiver l’héritage si les droits du dossier parent sont trop larges ;
3. convertir les autorisations héritées si nécessaire ;
4. retirer les groupes génériques inutiles, comme `Users` ou `Everyone` ;
5. conserver `SYSTEM` et les administrateurs ;
6. ajouter le groupe du service ;
7. lui accorder uniquement les droits nécessaires.

> [!IMPORTANT]
> Le principe du moindre privilège consiste à donner seulement les permissions nécessaires. Le droit **Modifier** suffit généralement pour travailler dans un dossier ; le **Contrôle total** n’est pas requis.

## 5. Tester les accès

### Test avec un membre autorisé

Ouvrir une session avec Paul Kebre, puis accéder à :

```text
\\DC\FilePartagerEngenieur
```

Vérifier que l’utilisateur peut effectuer les actions prévues, par exemple lire, créer, modifier et supprimer un fichier de test.

Le partage peut également être associé à la lettre `Z:` :

1. ouvrir l’Explorateur de fichiers ;
2. sélectionner **Connecter un lecteur réseau** ;
3. choisir la lettre `Z:` ;
4. saisir `\\DC\FilePartagerEngenieur` ;
5. activer la reconnexion à l’ouverture de session si nécessaire.

### Test avec un utilisateur non autorisé

Ouvrir une session avec Aba, qui ne fait pas partie du groupe autorisé, puis essayer d’ouvrir le même chemin UNC.

Le résultat attendu est un refus d’accès. Ce test négatif est aussi important que le test autorisé : il démontre que la restriction fonctionne réellement.

> [!NOTE]
> Après l’ajout d’un utilisateur à un groupe, une fermeture et une réouverture de session peuvent être nécessaires pour renouveler son jeton de sécurité.

## 6. Préparer le fond d’écran

Le fichier image utilisé par la GPO doit être accessible en lecture par tous les utilisateurs ciblés. Dans ce laboratoire, il est placé dans un emplacement partagé du contrôleur de domaine, par exemple `NETLOGON`.

Exemple de chemin :

```text
\\bagayan.local\NETLOGON\fond-ingenieur.jpg
```

Le chemin réseau doit être utilisé dans la GPO. Un chemin local comme `C:\Images\fond.jpg` pointerait vers le disque du poste client et ne fonctionnerait pas de manière centralisée.

## 7. Créer et lier la GPO

Une **GPO** (Group Policy Object, ou objet de stratégie de groupe) contient des paramètres centralisés appliqués aux utilisateurs ou aux ordinateurs du domaine.

Dans la **GPMC** (Group Policy Management Console) :

1. ouvrir la forêt et le domaine `bagayan.local` ;
2. sélectionner l’OU `_ENGINEERING` ;
3. choisir **Créer un objet GPO dans ce domaine et le lier ici** ;
4. nommer la GPO `ImageDeFondEngenieur` ;
5. modifier la GPO ;
6. ouvrir la configuration utilisateur du Bureau ;
7. activer le paramètre **Desktop Wallpaper** ;
8. saisir le chemin UNC de l’image ;
9. choisir le style d’affichage souhaité ;
10. fermer l’éditeur et vérifier le lien avec l’OU.

Une GPO liée à une OU s’applique aux objets compatibles placés dans cette OU, sous réserve du filtrage de sécurité et des règles d’héritage.

## 8. Actualiser et diagnostiquer la GPO

Sur le poste client, ouvrir PowerShell ou l’invite de commandes :

```powershell
gpupdate /force
gpresult /r
gpresult /h C:\Temp\gpo.html
whoami /groups
```

| Commande | Utilité |
|---|---|
| `gpupdate /force` | Force l’actualisation des stratégies utilisateur et ordinateur. |
| `gpresult /r` | Affiche les GPO appliquées et refusées. |
| `gpresult /h C:\Temp\gpo.html` | Génère un rapport HTML détaillé. |
| `whoami /groups` | Affiche les groupes présents dans le jeton de sécurité. |

Le résultat attendu est l’apparition du fond d’écran pour un utilisateur de l’OU `_ENGINEERING`.

## 9. Vérifications finales

- [ ] L’OU `_ENGINEERING` contient uniquement les objets prévus.
- [ ] Le groupe de sécurité est placé dans la bonne OU.
- [ ] Les membres du groupe ont été vérifiés.
- [ ] Le partage est visible dans le Gestionnaire de serveur.
- [ ] `SYSTEM` et les administrateurs conservent le contrôle total.
- [ ] Le groupe d’Ingénierie possède le droit **Modifier**.
- [ ] Paul Kebre accède au partage.
- [ ] Aba reçoit un refus d’accès.
- [ ] La GPO est liée à `_ENGINEERING`.
- [ ] Le fichier image est accessible en lecture.
- [ ] `gpresult` confirme l’application de la GPO.

## 10. Dépannage

| Problème | Contrôles |
|---|---|
| Accès refusé pour un membre | Vérifier l’appartenance au groupe, renouveler la session et contrôler les droits SMB et NTFS. |
| Accès autorisé à tout le monde | Rechercher `Everyone`, `Domain Users` ou `Users` dans les deux couches de permissions. |
| Le lecteur Z: ne revient pas | Activer la reconnexion ou déployer le lecteur avec les préférences de stratégie de groupe. |
| Le fond d’écran ne s’applique pas | Tester le chemin UNC, exécuter `gpupdate /force`, consulter `gpresult` et vérifier le lien de la GPO. |
| La GPO est refusée | Contrôler le filtrage de sécurité, les droits **Read/Apply Group Policy** et l’emplacement du compte. |

## Glossaire

| Sigle ou terme | Définition |
|---|---|
| AD | Active Directory : annuaire Microsoft centralisant utilisateurs, ordinateurs, groupes et politiques. |
| AD DS | Active Directory Domain Services : rôle serveur fournissant l’annuaire et l’authentification. |
| DC | Domain Controller : contrôleur de domaine hébergeant AD DS. |
| OU | Organizational Unit : unité d’organisation servant à classer les objets et cibler les GPO. |
| GPO | Group Policy Object : objet contenant des paramètres administratifs centralisés. |
| GPMC | Group Policy Management Console : console de gestion des GPO. |
| SMB | Server Message Block : protocole Windows de partage de fichiers et d’imprimantes. |
| NTFS | New Technology File System : système de fichiers Windows gérant les permissions détaillées. |
| UNC | Universal Naming Convention : format `\\serveur\partage` d’une ressource réseau. |
| ACL | Access Control List : liste des autorisations et refus d’une ressource. |
| AGDLP | Accounts, Global groups, Domain Local groups, Permissions : modèle d’attribution des droits. |
| SYSVOL | Partage système répliqué entre les contrôleurs de domaine et utilisé par les GPO. |
| NETLOGON | Partage système utilisé pour les scripts et certaines ressources d’ouverture de session. |
| DNS | Domain Name System : service de résolution de noms indispensable à Active Directory. |
| DHCP | Dynamic Host Configuration Protocol : service attribuant automatiquement les paramètres IP. |

## Bonnes pratiques

- attribuer les droits à des groupes plutôt qu’à des utilisateurs ;
- documenter la finalité, le propriétaire et les membres de chaque groupe ;
- séparer les groupes d’appartenance des groupes portant les permissions ;
- appliquer le principe du moindre privilège ;
- éviter les refus explicites lorsqu’ils ne sont pas indispensables ;
- tester systématiquement un utilisateur autorisé et un utilisateur interdit ;
- sauvegarder les données partagées ;
- protéger les emplacements `SYSVOL` et `NETLOGON` ;
- limiter chaque GPO à un objectif clair ;
- adopter une convention de nommage explicite.

## Résultat attendu

Les membres du service Ingénierie accèdent au dossier partagé et reçoivent la configuration de bureau prévue. Les autres utilisateurs restent sans accès. Chaque résultat peut être vérifié avec les consoles Active Directory, les permissions du système de fichiers et les outils Group Policy.
