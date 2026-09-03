# Homelab Active Directory sous Windows Server 2022

Guide pédagogique pour installer un contrôleur de domaine Active Directory, configurer DNS, DHCP et le routage NAT, créer des utilisateurs avec PowerShell, puis joindre un poste Windows 11 au domaine.

> [!WARNING]
> Ce projet est destiné à un laboratoire isolé. Il regroupe plusieurs rôles sur un seul serveur pour faciliter l’apprentissage. Cette architecture n’est pas recommandée en production.

## Objectifs

À la fin de ce projet, le laboratoire doit permettre de :

- déployer un contrôleur de domaine Windows Server 2022 ;
- créer la forêt et le domaine `bagayan.local` ;
- administrer des unités d’organisation et des comptes utilisateurs ;
- distribuer automatiquement la configuration réseau avec DHCP ;
- fournir un accès Internet au réseau interne avec RRAS et NAT ;
- créer en masse des comptes fictifs avec PowerShell ;
- joindre un client Windows 11 au domaine ;
- ouvrir une session avec un utilisateur Active Directory.

## Architecture du laboratoire

| Élément | Valeur utilisée |
|---|---|
| Serveur | Windows Server 2022 Standard |
| Nom du serveur | `DC` |
| Domaine DNS | `bagayan.local` |
| Nom NetBIOS | `BAGAYAN` |
| Adresse du réseau interne | `172.16.0.0/16` |
| Adresse du contrôleur | `172.16.0.1` |
| Plage DHCP | `172.16.0.50` à `172.16.0.100` |
| Passerelle distribuée | `172.16.0.1` |
| Serveur DNS distribué | `172.16.0.1` |
| Poste client | Windows 11, nommé `CLIENT1` |

Le serveur possède deux cartes réseau :

- une interface externe connectée à Internet ;
- une interface LAN connectée uniquement au réseau du laboratoire.

## Prérequis

- un hyperviseur, par exemple Hyper-V, VMware Workstation ou VirtualBox ;
- une machine virtuelle Windows Server 2022 ;
- une machine virtuelle Windows 11 Pro, Enterprise ou Education ;
- deux réseaux virtuels : un réseau externe et un réseau interne ;
- un compte administrateur local sur le serveur ;
- des instantanés des machines avant les changements importants.

Windows 11 Famille ne peut pas rejoindre un domaine Active Directory.

## 1. Préparer Windows Server

1. Renommer le serveur en `DC`.
2. Identifier clairement les deux cartes réseau, par exemple `_Internet_` et `_Lan_`.
3. Configurer l’interface LAN avec les paramètres suivants :
   - adresse : `172.16.0.1` ;
   - masque : `255.255.0.0` ;
   - passerelle : aucune sur l’interface LAN ;
   - DNS préféré : `172.16.0.1` après l’installation du rôle DNS.
4. Laisser l’interface externe obtenir une configuration compatible avec le réseau donnant accès à Internet.
5. Redémarrer le serveur après le changement de nom.

> [!IMPORTANT]
> Une seule carte doit avoir une passerelle par défaut : l’interface externe. Deux passerelles peuvent provoquer un routage imprévisible.

## 2. Installer Active Directory Domain Services

Dans le Gestionnaire de serveur :

1. ouvrir **Gérer > Ajouter des rôles et fonctionnalités** ;
2. choisir **Installation basée sur un rôle ou une fonctionnalité** ;
3. sélectionner le serveur `DC` ;
4. cocher **Services AD DS** ;
5. accepter les outils d’administration proposés ;
6. lancer l’installation ;
7. cliquer sur **Promouvoir ce serveur en contrôleur de domaine**.

### Créer la forêt

1. choisir **Ajouter une nouvelle forêt** ;
2. saisir `bagayan.local` comme nom de domaine racine ;
3. conserver DNS et le catalogue global activés ;
4. définir un mot de passe DSRM robuste ;
5. vérifier le nom NetBIOS `BAGAYAN` ;
6. contrôler les chemins de la base AD DS, des journaux et de SYSVOL ;
7. lancer la vérification des prérequis puis l’installation.

Le serveur redémarre automatiquement. La connexion peut ensuite être effectuée avec `BAGAYAN\Administrator`.

> [!NOTE]
> Le suffixe `.local` convient à ce laboratoire. En production, utilisez de préférence un sous-domaine DNS que vous possédez, par exemple `ad.exemple.fr`.

## 3. Organiser Active Directory

Ouvrir **Utilisateurs et ordinateurs Active Directory** puis créer :

- l’OU `_ADMIN` pour les comptes administratifs ;
- l’OU `_USERS` pour les utilisateurs standards du laboratoire.

Cocher **Protéger le conteneur contre une suppression accidentelle** lors de la création des OU.

### Créer un compte administratif séparé

1. créer un utilisateur dans `_ADMIN` ;
2. lui attribuer un mot de passe robuste ;
3. ajouter le compte au groupe `Domain Admins` uniquement si cela est indispensable ;
4. conserver un compte standard distinct pour l’utilisation quotidienne.

> [!CAUTION]
> Les membres de `Domain Admins` disposent de droits très élevés. N’utilisez pas un compte de ce groupe pour naviguer sur Internet ou effectuer des tâches courantes.

## 4. Configurer RRAS et le NAT

RRAS permet au poste du réseau interne d’accéder à Internet par l’interface externe du serveur.

1. ajouter le rôle **Accès à distance** ;
2. sélectionner les services **DirectAccess et VPN (RAS)** et **Routage** ;
3. terminer l’installation ;
4. ouvrir **Outils > Routage et accès distant** ;
5. sélectionner le serveur puis **Configurer et activer le routage et l’accès distant** ;
6. choisir **Traduction d’adresses réseau (NAT)** ;
7. sélectionner exclusivement l’interface connectée à Internet ;
8. terminer l’assistant et vérifier que le serveur apparaît en état opérationnel.

Ne sélectionnez jamais l’interface LAN comme interface publique NAT.

## 5. Installer et configurer DHCP

### Installer le rôle

1. ajouter le rôle **Serveur DHCP** ;
2. accepter les outils d’administration ;
3. terminer la configuration post-déploiement ;
4. autoriser le serveur DHCP dans Active Directory.

### Créer l’étendue IPv4

Créer une nouvelle étendue avec :

| Paramètre | Valeur |
|---|---|
| Nom | `LAN-172.16.0.0-16` |
| Première adresse | `172.16.0.50` |
| Dernière adresse | `172.16.0.100` |
| Longueur de préfixe | `/16` |
| Masque | `255.255.0.0` |
| Durée du bail | 8 jours pour un laboratoire stable |
| Routeur, option 003 | `172.16.0.1` |
| Domaine DNS | `bagayan.local` |
| Serveur DNS, option 006 | `172.16.0.1` |
| WINS | Aucun |

Activer l’étendue à la fin de l’assistant.

> [!WARNING]
> N’excluez pas la plage entière `172.16.0.50-172.16.0.100`. Une exclusion signifie que DHCP ne distribuera jamais ces adresses. Ajoutez uniquement les adresses statiques réellement situées dans la plage.

Après l’autorisation, actualiser la console DHCP et vérifier que les branches IPv4 apparaissent sans erreur.

## 6. Créer des utilisateurs avec PowerShell

Le script [`scripts/New-LabADUsers.ps1`](scripts/New-LabADUsers.ps1) lit un fichier texte contenant une personne par ligne :

## 7. Préparer le client Windows 11

1. connecter `CLIENT1` au réseau virtuel interne ;
2. configurer IPv4 et DNS en automatique ;
3. renouveler le bail :

```powershell
ipconfig /release
ipconfig /renew
ipconfig /all
```

Le client doit recevoir :

- une adresse comprise entre `172.16.0.50` et `172.16.0.100` ;
- le masque `255.255.0.0` ;
- la passerelle `172.16.0.1` ;
- le serveur DNS `172.16.0.1` ;
- le suffixe DNS `bagayan.local`.

### Tester le réseau

```powershell
ping 172.16.0.1
nslookup bagayan.local
ping bagayan.local
ping google.com
```

Une réponse de `bagayan.local` valide la résolution interne. Une réponse de `google.com` valide la résolution externe et le NAT.

## 8. Joindre Windows 11 au domaine

1. ouvrir les propriétés système avancées ;
2. modifier le nom ou l’appartenance de l’ordinateur ;
3. sélectionner **Domaine** ;
4. saisir `bagayan.local` ;
5. fournir les identifiants d’un compte autorisé ;
6. vérifier le message de bienvenue dans le domaine ;
7. redémarrer le client.

Après le redémarrage, choisir **Autre utilisateur** et se connecter avec :

```text
BAGAYAN\nom_utilisateur
```

ou :

```text
nom_utilisateur@bagayan.local
```

Vérifier la session :

```powershell
whoami
```

Le résultat attendu ressemble à `bagayan\aba`.

## 9. Vérifications finales

- [ ] `DC` répond sur `172.16.0.1`.
- [ ] Les consoles AD DS, DNS et DHCP s’ouvrent sans erreur.
- [ ] Le serveur DHCP est autorisé.
- [ ] L’étendue DHCP est active.
- [ ] Un bail est visible pour `CLIENT1`.
- [ ] Le client utilise `172.16.0.1` comme DNS.
- [ ] `bagayan.local` est résolu par DNS.
- [ ] L’accès Internet fonctionne à travers le NAT.
- [ ] `CLIENT1` apparaît dans Active Directory.
- [ ] Un utilisateur du domaine peut ouvrir une session.
- [ ] `whoami` affiche le domaine `BAGAYAN`.

## 10. Dépannage

### Le client ne reçoit pas d’adresse

- vérifier que l’étendue DHCP est activée ;
- vérifier que le serveur est autorisé dans Active Directory ;
- contrôler le service DHCP ;
- confirmer que le client et l’interface LAN sont sur le même réseau virtuel ;
- exécuter `ipconfig /release` puis `ipconfig /renew`.

### La jonction au domaine échoue

- configurer le DNS du client sur `172.16.0.1` ;
- tester `nslookup bagayan.local` ;
- vérifier que l’heure du client correspond à celle du contrôleur ;
- contrôler les identifiants utilisés pour la jonction ;
- vérifier que les services AD DS et DNS fonctionnent.

### Le domaine fonctionne, mais pas Internet

- vérifier l’état de RRAS ;
- vérifier que l’interface publique NAT est la bonne ;
- contrôler la passerelle `172.16.0.1` sur le client ;
- vérifier les redirecteurs du serveur DNS ;
- tester d’abord une adresse IP externe, puis un nom DNS.

### Le script PowerShell génère des erreurs

- exécuter `Import-Module ActiveDirectory` ;
- vérifier le chemin LDAP de l’OU ;
- enregistrer le fichier de noms en UTF-8 ;
- vérifier les droits du compte exécutant le script ;
- commencer avec `-WhatIf` ;
- rechercher les doublons et les lignes vides.

## Partie 2 — OU, groupes, partage SMB et GPO

La suite du laboratoire couvre l’organisation des objets Active Directory, la gestion des droits par groupes, la création d’un partage de fichiers SMB et le déploiement d’un fond d’écran avec une GPO.

➡️ **[Consulter le guide Active Directory — Version 2](docs/active-directory-v2.md)**

Cette deuxième partie explique notamment :

- la création de l’OU `_ENGINEERING` ;
- la création du groupe de sécurité `FilePartagerEngenieur` ;
- les permissions SMB et NTFS ;
- les tests d’accès autorisé et refusé ;
- le mappage d’un lecteur réseau ;
- la création de la GPO `ImageDeFondEngenieur` ;
- les commandes `gpupdate`, `gpresult` et `whoami /groups`.

## Glossaire

| Sigle | Signification | Rôle simplifié |
|---|---|---|
| AD | Active Directory | Annuaire Microsoft des utilisateurs, groupes et ordinateurs. |
| AD DS | Active Directory Domain Services | Rôle serveur fournissant Active Directory. |
| DC | Domain Controller | Serveur qui authentifie les comptes du domaine. |
| DNS | Domain Name System | Traduit les noms en adresses IP. |
| DHCP | Dynamic Host Configuration Protocol | Distribue automatiquement la configuration réseau. |
| OU | Organizational Unit | Conteneur logique servant à classer les objets AD. |
| IP | Internet Protocol | Protocole d’adressage réseau. |
| IPv4 / IPv6 | Internet Protocol versions 4 et 6 | Deux versions du protocole IP. |
| LAN | Local Area Network | Réseau local interne. |
| WAN | Wide Area Network | Réseau étendu ou externe. |
| NAT | Network Address Translation | Traduit les adresses privées pour l’accès externe. |
| RRAS | Routing and Remote Access Service | Service Windows de routage et d’accès distant. |
| RAS | Remote Access Service | Composant d’accès distant de RRAS. |
| VPN | Virtual Private Network | Tunnel sécurisé vers un réseau privé. |
| ICMP | Internet Control Message Protocol | Protocole de diagnostic utilisé par `ping`. |
| WINS | Windows Internet Name Service | Ancien service de résolution des noms NetBIOS. |
| UPN | User Principal Name | Identifiant au format `utilisateur@domaine`. |
| FQDN | Fully Qualified Domain Name | Nom DNS complet, comme `dc.bagayan.local`. |
| GPO | Group Policy Object | Paramètres centralisés appliqués aux objets du domaine. |
| IIS | Internet Information Services | Serveur web de Microsoft. |
| ISE | Integrated Scripting Environment | Ancien éditeur graphique PowerShell. |
| VM | Virtual Machine | Machine virtuelle utilisée pour le laboratoire. |
| NIC | Network Interface Card | Carte réseau physique ou virtuelle. |
| UTF-8 | Unicode Transformation Format 8 bits | Encodage conservant correctement les accents. |
| TTL | Time To Live | Durée de vie maximale d’un paquet réseau. |

## Bonnes pratiques de sécurité

- séparer les comptes standards et administratifs ;
- limiter strictement l’appartenance à `Domain Admins` ;
- ne jamais publier de véritable mot de passe, clé ou jeton ;
- ne pas désactiver les protections de sécurité en production ;
- sauvegarder régulièrement l’état système ;
- déployer au moins deux contrôleurs de domaine en production ;
- utiliser un sous-domaine DNS réellement possédé ;
- tester les scripts avec `-WhatIf` avant toute création en masse.

## Avertissement

Les noms, comptes et mots de passe employés dans ce projet sont fictifs et réservés aux tests. Adaptez les adresses, les politiques de mot de passe, les délégations et l’architecture avant toute utilisation réelle.

## Captures et déroulement du laboratoire Active Directory

Cette galerie reprend les étapes du rapport complet dans le même ordre. Les groupes sont repliables afin de conserver un README lisible.

> [!NOTE]
> Deux captures PowerShell contenant un mot de passe de laboratoire en clair et une politique d’exécution `Unrestricted` ne sont pas publiées. En pratique, demandez le mot de passe avec `Read-Host -AsSecureString` et évitez `Unrestricted`.

<details>
<summary><strong>1 — Topologie et périmètre du laboratoire</strong></summary>

#### 1. Topologie logique et plan d’adressage du HomeLab Active Directory

<img src="docs/active-directory/images/001-figure-1-topologie-logique-et-plan-dadressage-du-homelab-active-director.webp" alt="Topologie logique et plan d’adressage du HomeLab Active Directory" width="900">

</details>


<details>
<summary><strong>2 — Installation d’AD DS et création de la forêt</strong></summary>

#### 2. Sélection du serveur de destination nommé DC

<img src="docs/active-directory/images/002-selection-du-serveur-de-destination-nomme-dc.webp" alt="Sélection du serveur de destination nommé DC" width="900">

#### 3. Ajout des outils requis par le rôle AD DS

<img src="docs/active-directory/images/003-ajout-des-outils-requis-par-le-role-ad-ds.webp" alt="Ajout des outils requis par le rôle AD DS" width="900">

#### 4. Sélection du rôle Services de domaine Active Directory

<img src="docs/active-directory/images/004-selection-du-role-services-de-domaine-active-directory.webp" alt="Sélection du rôle Services de domaine Active Directory" width="900">

#### 5. Présentation du rôle AD DS dans l’assistant

<img src="docs/active-directory/images/005-presentation-du-role-ad-ds-dans-lassistant.webp" alt="Présentation du rôle AD DS dans l’assistant" width="900">

#### 6. Fin de l’installation du rôle AD DS

<img src="docs/active-directory/images/006-fin-de-linstallation-du-role-ad-ds.webp" alt="Fin de l’installation du rôle AD DS" width="900">

#### 7. Notification de post-déploiement

<img src="docs/active-directory/images/007-notification-de-post-deploiement.webp" alt="Notification de post-déploiement" width="900">

#### 8. Création d’une nouvelle forêt bagayan.local

<img src="docs/active-directory/images/008-creation-dune-nouvelle-foret-bagayan-local.webp" alt="Création d’une nouvelle forêt bagayan.local" width="900">

#### 9. Options du contrôleur de domaine

<img src="docs/active-directory/images/009-options-du-controleur-de-domaine.webp" alt="Options du contrôleur de domaine" width="900">

#### 10. Emplacements de la base AD, des journaux et de SYSVOL

<img src="docs/active-directory/images/010-emplacements-de-la-base-ad-des-journaux-et-de-sysvol.webp" alt="Emplacements de la base AD, des journaux et de SYSVOL" width="900">

#### 11. Vérification des prérequis avant promotion

<img src="docs/active-directory/images/011-verification-des-prerequis-avant-promotion.webp" alt="Vérification des prérequis avant promotion" width="900">

#### 12. Redémarrage automatique après la promotion

<img src="docs/active-directory/images/012-redemarrage-automatique-apres-la-promotion.webp" alt="Redémarrage automatique après la promotion" width="900">

#### 13. Première connexion avec le compte Administrateur du domaine

<img src="docs/active-directory/images/013-premiere-connexion-avec-le-compte-administrateur-du-domaine.webp" alt="Première connexion avec le compte Administrateur du domaine" width="900">

</details>


<details>
<summary><strong>3 — Organisation de l’administration du domaine</strong></summary>

#### 14. Création de l’unité d’organisation _ADMIN

<img src="docs/active-directory/images/014-creation-de-lunite-dorganisation-admin.webp" alt="Création de l’unité d’organisation _ADMIN" width="900">

#### 15. Commande Nouveau > Utilisateur dans l’OU _ADMIN

<img src="docs/active-directory/images/015-commande-nouveau-utilisateur-dans-lou-admin.webp" alt="Commande Nouveau > Utilisateur dans l’OU _ADMIN" width="900">

#### 16. Saisie de l’identité du compte administrateur délégué

<img src="docs/active-directory/images/016-saisie-de-lidentite-du-compte-administrateur-delegue.webp" alt="Saisie de l’identité du compte administrateur délégué" width="900">

#### 17. Définition du mot de passe du nouveau compte

<img src="docs/active-directory/images/017-definition-du-mot-de-passe-du-nouveau-compte.webp" alt="Définition du mot de passe du nouveau compte" width="900">

#### 18. Ajout d’un groupe dans l’onglet Membre de

<img src="docs/active-directory/images/018-ajout-dun-groupe-dans-longlet-membre-de.webp" alt="Ajout d’un groupe dans l’onglet Membre de" width="900">

#### 19. Compte ajouté au groupe Domain Admins

<img src="docs/active-directory/images/019-compte-ajoute-au-groupe-domain-admins.webp" alt="Compte ajouté au groupe Domain Admins" width="900">

#### 20. Test de connexion avec le nouvel administrateur

<img src="docs/active-directory/images/020-test-de-connexion-avec-le-nouvel-administrateur.webp" alt="Test de connexion avec le nouvel administrateur" width="900">

</details>


<details>
<summary><strong>4 — Configuration de RRAS et du routage NAT</strong></summary>

#### 21. Sélection du serveur avant l’installation d’Accès à distance

<img src="docs/active-directory/images/021-selection-du-serveur-avant-linstallation-dacces-a-distance.webp" alt="Sélection du serveur avant l’installation d’Accès à distance" width="900">

#### 22. Sélection du rôle Accès à distance

<img src="docs/active-directory/images/022-selection-du-role-acces-a-distance.webp" alt="Sélection du rôle Accès à distance" width="900">

#### 23. Ajout des fonctionnalités nécessaires au routage

<img src="docs/active-directory/images/023-ajout-des-fonctionnalites-necessaires-au-routage.webp" alt="Ajout des fonctionnalités nécessaires au routage" width="900">

#### 24. Sélection des services de rôle Routage et DirectAccess/VPN

<img src="docs/active-directory/images/024-selection-des-services-de-role-routage-et-directaccess-vpn.webp" alt="Sélection des services de rôle Routage et DirectAccess/VPN" width="900">

#### 25. Fin de l’installation d’Accès à distance

<img src="docs/active-directory/images/025-fin-de-linstallation-dacces-a-distance.webp" alt="Fin de l’installation d’Accès à distance" width="900">

#### 26. Ouverture de Routage et accès distant

<img src="docs/active-directory/images/026-ouverture-de-routage-et-acces-distant.webp" alt="Ouverture de Routage et accès distant" width="900">

#### 27. Lancement de l’assistant de configuration RRAS

<img src="docs/active-directory/images/027-lancement-de-lassistant-de-configuration-rras.webp" alt="Lancement de l’assistant de configuration RRAS" width="900">

#### 28. Choix du mode de configuration RRAS

<img src="docs/active-directory/images/028-choix-du-mode-de-configuration-rras.webp" alt="Choix du mode de configuration RRAS" width="900">

#### 29. Sélection de l’interface publique Internet

<img src="docs/active-directory/images/029-selection-de-linterface-publique-internet.webp" alt="Sélection de l’interface publique Internet" width="900">

#### 30. Fin de l’assistant RRAS

<img src="docs/active-directory/images/030-fin-de-lassistant-rras.webp" alt="Fin de l’assistant RRAS" width="900">

#### 31. État opérationnel du service RRAS

<img src="docs/active-directory/images/031-etat-operationnel-du-service-rras.webp" alt="État opérationnel du service RRAS" width="900">

</details>


<details>
<summary><strong>5 — Installation et configuration de DHCP</strong></summary>

#### 32. Sélection du rôle Serveur DHCP

<img src="docs/active-directory/images/032-selection-du-role-serveur-dhcp.webp" alt="Sélection du rôle Serveur DHCP" width="900">

#### 33. Confirmation de l’installation DHCP

<img src="docs/active-directory/images/033-confirmation-de-linstallation-dhcp.webp" alt="Confirmation de l’installation DHCP" width="900">

#### 34. Notification de configuration post-déploiement DHCP

<img src="docs/active-directory/images/034-notification-de-configuration-post-deploiement-dhcp.webp" alt="Notification de configuration post-déploiement DHCP" width="900">

#### 35. Assistant Nouvelle étendue IPv4

<img src="docs/active-directory/images/035-assistant-nouvelle-etendue-ipv4.webp" alt="Assistant Nouvelle étendue IPv4" width="900">

#### 36. Nom de l’étendue DHCP

<img src="docs/active-directory/images/036-nom-de-letendue-dhcp.webp" alt="Nom de l’étendue DHCP" width="900">

#### 37. Plage d’adresses 172.16.0.50 à 172.16.0.100

<img src="docs/active-directory/images/037-plage-dadresses-172-16-0-50-a-172-16-0-100.webp" alt="Plage d’adresses 172.16.0.50 à 172.16.0.100" width="900">

#### 38. Saisie éventuelle d’une exclusion DHCP

<img src="docs/active-directory/images/038-saisie-eventuelle-dune-exclusion-dhcp.webp" alt="Saisie éventuelle d’une exclusion DHCP" width="900">

#### 39. Écran d’exclusion DHCP laissé vide

<img src="docs/active-directory/images/039-ecran-dexclusion-dhcp-laisse-vide.webp" alt="Écran d’exclusion DHCP laissé vide" width="900">

#### 40. Durée du bail DHCP

<img src="docs/active-directory/images/040-duree-du-bail-dhcp.webp" alt="Durée du bail DHCP" width="900">

#### 41. Configuration de la passerelle par défaut

<img src="docs/active-directory/images/041-configuration-de-la-passerelle-par-defaut.webp" alt="Configuration de la passerelle par défaut" width="900">

#### 42. Configuration du domaine et des serveurs DNS

<img src="docs/active-directory/images/042-configuration-du-domaine-et-des-serveurs-dns.webp" alt="Configuration du domaine et des serveurs DNS" width="900">

#### 43. Configuration WINS

<img src="docs/active-directory/images/043-configuration-wins.webp" alt="Configuration WINS" width="900">

#### 44. Activation immédiate de l’étendue

<img src="docs/active-directory/images/044-activation-immediate-de-letendue.webp" alt="Activation immédiate de l’étendue" width="900">

#### 45. Confirmation du choix d’activation

<img src="docs/active-directory/images/045-confirmation-du-choix-dactivation.webp" alt="Confirmation du choix d’activation" width="900">

#### 46. Fin de l’assistant Nouvelle étendue

<img src="docs/active-directory/images/046-fin-de-lassistant-nouvelle-etendue.webp" alt="Fin de l’assistant Nouvelle étendue" width="900">

#### 47. Autorisation du serveur DHCP dans Active Directory

<img src="docs/active-directory/images/047-autorisation-du-serveur-dhcp-dans-active-directory.webp" alt="Autorisation du serveur DHCP dans Active Directory" width="900">

#### 48. Actualisation de la console DHCP

<img src="docs/active-directory/images/048-actualisation-de-la-console-dhcp.webp" alt="Actualisation de la console DHCP" width="900">

#### 49. Serveur DHCP autorisé et opérationnel

<img src="docs/active-directory/images/049-serveur-dhcp-autorise-et-operationnel.webp" alt="Serveur DHCP autorisé et opérationnel" width="900">

#### 50. Plage active dans le pool d’adresses

<img src="docs/active-directory/images/050-plage-active-dans-le-pool-dadresses.webp" alt="Plage active dans le pool d’adresses" width="900">

</details>


<details>
<summary><strong>6 — Création des comptes et finalisation des services</strong></summary>

#### 51. Gestion locale du serveur depuis Server Manager

<img src="docs/active-directory/images/051-gestion-locale-du-serveur-depuis-server-manager.webp" alt="Gestion locale du serveur depuis Server Manager" width="900">

#### 52. Ouverture de Windows PowerShell ISE

<img src="docs/active-directory/images/052-ouverture-de-windows-powershell-ise.webp" alt="Ouverture de Windows PowerShell ISE" width="900">

#### 55. Contrôle des comptes dans Utilisateurs et ordinateurs AD

<img src="docs/active-directory/images/055-controle-des-comptes-dans-utilisateurs-et-ordinateurs-ad.webp" alt="Contrôle des comptes dans Utilisateurs et ordinateurs AD" width="900">

#### 56. Contrôle des options du serveur DHCP

<img src="docs/active-directory/images/056-controle-des-options-du-serveur-dhcp.webp" alt="Contrôle des options du serveur DHCP" width="900">

#### 57. Redémarrage du service DHCP

<img src="docs/active-directory/images/057-redemarrage-du-service-dhcp.webp" alt="Redémarrage du service DHCP" width="900">

</details>


<details>
<summary><strong>7 — Configuration et jonction du client Windows 11</strong></summary>

#### 58. Résultat ipconfig sur le client

<img src="docs/active-directory/images/058-resultat-ipconfig-sur-le-client.webp" alt="Résultat ipconfig sur le client" width="900">

#### 59. Test de résolution et de connectivité vers bagayan.local

<img src="docs/active-directory/images/059-test-de-resolution-et-de-connectivite-vers-bagayan-local.webp" alt="Test de résolution et de connectivité vers bagayan.local" width="900">

#### 60. Test d’accès et de résolution Internet

<img src="docs/active-directory/images/060-test-dacces-et-de-resolution-internet.webp" alt="Test d’accès et de résolution Internet" width="900">

#### 61. Fenêtre de jonction à un domaine

<img src="docs/active-directory/images/061-fenetre-de-jonction-a-un-domaine.webp" alt="Fenêtre de jonction à un domaine" width="900">

#### 62. Authentification d’un administrateur pour la jonction

<img src="docs/active-directory/images/062-authentification-dun-administrateur-pour-la-jonction.webp" alt="Authentification d’un administrateur pour la jonction" width="900">

#### 63. Confirmation de l’entrée dans le domaine

<img src="docs/active-directory/images/063-confirmation-de-lentree-dans-le-domaine.webp" alt="Confirmation de l’entrée dans le domaine" width="900">

#### 64. Bail DHCP attribué à CLIENT1

<img src="docs/active-directory/images/064-bail-dhcp-attribue-a-client1.webp" alt="Bail DHCP attribué à CLIENT1" width="900">

#### 65. Objet ordinateur CLIENT1 dans Active Directory

<img src="docs/active-directory/images/065-objet-ordinateur-client1-dans-active-directory.webp" alt="Objet ordinateur CLIENT1 dans Active Directory" width="900">

#### 66. Ouverture de session du domaine sur Windows 11

<img src="docs/active-directory/images/066-ouverture-de-session-du-domaine-sur-windows-11.webp" alt="Ouverture de session du domaine sur Windows 11" width="900">

#### 67. Session ouverte avec un compte du domaine

<img src="docs/active-directory/images/067-session-ouverte-avec-un-compte-du-domaine.webp" alt="Session ouverte avec un compte du domaine" width="900">

#### 68. Validation avec la commande whoami

<img src="docs/active-directory/images/068-validation-avec-la-commande-whoami.webp" alt="Validation avec la commande whoami" width="900">

</details>


<details>
<summary><strong>8 — Installation et configuration d’AD CS</strong></summary>

#### 69. Sélection du rôle Active Directory Certificate Services

<img src="docs/active-directory/images/069-selection-du-role-active-directory-certificate-services.webp" alt="Sélection du rôle Active Directory Certificate Services" width="900">

#### 70. Ajout des fonctionnalités requises pour AD CS

<img src="docs/active-directory/images/070-ajout-des-fonctionnalites-requises-pour-ad-cs.webp" alt="Ajout des fonctionnalités requises pour AD CS" width="900">

#### 71. Présentation du rôle Active Directory Certificate Services

<img src="docs/active-directory/images/071-presentation-du-role-active-directory-certificate-services.webp" alt="Présentation du rôle Active Directory Certificate Services" width="900">

#### 72. Sélection du service de rôle Autorité de certification

<img src="docs/active-directory/images/072-selection-du-service-de-role-autorite-de-certification.webp" alt="Sélection du service de rôle Autorité de certification" width="900">

#### 73. Confirmation des options d’installation AD CS

<img src="docs/active-directory/images/073-confirmation-des-options-dinstallation-ad-cs.webp" alt="Confirmation des options d’installation AD CS" width="900">

#### 74. Progression de l’installation du rôle AD CS

<img src="docs/active-directory/images/074-progression-de-linstallation-du-role-ad-cs.webp" alt="Progression de l’installation du rôle AD CS" width="900">

#### 75. Notification de configuration post-déploiement AD CS

<img src="docs/active-directory/images/075-notification-de-configuration-post-deploiement-ad-cs.webp" alt="Notification de configuration post-déploiement AD CS" width="900">

#### 76. Sélection du compte utilisé pour configurer AD CS

<img src="docs/active-directory/images/076-selection-du-compte-utilise-pour-configurer-ad-cs.webp" alt="Sélection du compte utilisé pour configurer AD CS" width="900">

#### 77. Sélection du service AD CS à configurer

<img src="docs/active-directory/images/077-selection-du-service-ad-cs-a-configurer.webp" alt="Sélection du service AD CS à configurer" width="900">

#### 78. Choix du type Enterprise CA

<img src="docs/active-directory/images/078-choix-du-type-enterprise-ca.webp" alt="Choix du type Enterprise CA" width="900">

#### 79. Choix du type Root CA

<img src="docs/active-directory/images/079-choix-du-type-root-ca.webp" alt="Choix du type Root CA" width="900">

#### 80. Création d’une nouvelle clé privée pour la CA

<img src="docs/active-directory/images/080-creation-dune-nouvelle-cle-privee-pour-la-ca.webp" alt="Création d’une nouvelle clé privée pour la CA" width="900">

#### 81. Paramètres cryptographiques de l’autorité de certification

<img src="docs/active-directory/images/081-parametres-cryptographiques-de-lautorite-de-certification.webp" alt="Paramètres cryptographiques de l’autorité de certification" width="900">

#### 82. Définition du nom de l’autorité de certification

<img src="docs/active-directory/images/082-definition-du-nom-de-lautorite-de-certification.webp" alt="Définition du nom de l’autorité de certification" width="900">

#### 83. Définition de la période de validité de la CA

<img src="docs/active-directory/images/083-definition-de-la-periode-de-validite-de-la-ca.webp" alt="Définition de la période de validité de la CA" width="900">

#### 84. Emplacements de la base de données AD CS

<img src="docs/active-directory/images/084-emplacements-de-la-base-de-donnees-ad-cs.webp" alt="Emplacements de la base de données AD CS" width="900">

#### 85. Résumé de la configuration de l’autorité de certification

<img src="docs/active-directory/images/085-resume-de-la-configuration-de-lautorite-de-certification.webp" alt="Résumé de la configuration de l’autorité de certification" width="900">

#### 86. Résultat de la configuration de l’autorité de certification

<img src="docs/active-directory/images/086-resultat-de-la-configuration-de-lautorite-de-certification.webp" alt="Résultat de la configuration de l’autorité de certification" width="900">

</details>


<details>
<summary><strong>9 — OU, groupes, partage SMB, permissions NTFS et GPO</strong></summary>

#### 87. Organisation des unités d’organisation du domaine

<img src="docs/active-directory/images/087-organisation-des-unites-dorganisation-du-domaine.webp" alt="Organisation des unités d’organisation du domaine" width="900">

#### 88. Création du groupe de sécurité FilePartagerEngenieur

<img src="docs/active-directory/images/088-creation-du-groupe-de-securite-filepartagerengenieur.webp" alt="Création du groupe de sécurité FilePartagerEngenieur" width="900">

#### 89. Sélection des utilisateurs du service ingénierie

<img src="docs/active-directory/images/089-selection-des-utilisateurs-du-service-ingenierie.webp" alt="Sélection des utilisateurs du service ingénierie" width="900">

#### 90. Choix du profil de partage SMB

<img src="docs/active-directory/images/090-choix-du-profil-de-partage-smb.webp" alt="Choix du profil de partage SMB" width="900">

#### 91. Sélection du serveur et du chemin du partage

<img src="docs/active-directory/images/091-selection-du-serveur-et-du-chemin-du-partage.webp" alt="Sélection du serveur et du chemin du partage" width="900">

#### 92. Définition du nom FilePartagerEngenieur

<img src="docs/active-directory/images/092-definition-du-nom-filepartagerengenieur.webp" alt="Définition du nom FilePartagerEngenieur" width="900">

#### 93. Configuration des options du partage SMB

<img src="docs/active-directory/images/093-configuration-des-options-du-partage-smb.webp" alt="Configuration des options du partage SMB" width="900">

#### 94. Ouverture de la configuration des permissions

<img src="docs/active-directory/images/094-ouverture-de-la-configuration-des-permissions.webp" alt="Ouverture de la configuration des permissions" width="900">

#### 95. Affichage des permissions NTFS héritées

<img src="docs/active-directory/images/095-affichage-des-permissions-ntfs-heritees.webp" alt="Affichage des permissions NTFS héritées" width="900">

#### 96. Blocage de l’héritage des permissions

<img src="docs/active-directory/images/096-blocage-de-lheritage-des-permissions.webp" alt="Blocage de l’héritage des permissions" width="900">

#### 97. Permissions explicites après conversion

<img src="docs/active-directory/images/097-permissions-explicites-apres-conversion.webp" alt="Permissions explicites après conversion" width="900">

#### 98. Suppression d’une permission trop large

<img src="docs/active-directory/images/098-suppression-dune-permission-trop-large.webp" alt="Suppression d’une permission trop large" width="900">

#### 99. Liste NTFS restreinte aux principaux nécessaires

<img src="docs/active-directory/images/099-liste-ntfs-restreinte-aux-principaux-necessaires.webp" alt="Liste NTFS restreinte aux principaux nécessaires" width="900">

#### 100. Ajout d’une nouvelle entrée de permission

<img src="docs/active-directory/images/100-ajout-dune-nouvelle-entree-de-permission.webp" alt="Ajout d’une nouvelle entrée de permission" width="900">

#### 101. Sélection du groupe FilePartagerEngenieur

<img src="docs/active-directory/images/101-selection-du-groupe-filepartagerengenieur.webp" alt="Sélection du groupe FilePartagerEngenieur" width="900">

#### 102. Attribution des droits au groupe d’ingénierie

<img src="docs/active-directory/images/102-attribution-des-droits-au-groupe-dingenierie.webp" alt="Attribution des droits au groupe d’ingénierie" width="900">

#### 103. Propriétés générales du partage

<img src="docs/active-directory/images/103-proprietes-generales-du-partage.webp" alt="Propriétés générales du partage" width="900">

#### 104. Synthèse des permissions de partage et NTFS

<img src="docs/active-directory/images/104-synthese-des-permissions-de-partage-et-ntfs.webp" alt="Synthèse des permissions de partage et NTFS" width="900">

#### 105. Confirmation des paramètres du nouveau partage

<img src="docs/active-directory/images/105-confirmation-des-parametres-du-nouveau-partage.webp" alt="Confirmation des paramètres du nouveau partage" width="900">

#### 106. Création réussie du partage SMB

<img src="docs/active-directory/images/106-creation-reussie-du-partage-smb.webp" alt="Création réussie du partage SMB" width="900">

#### 107. Connexion avec le compte Paul Kebre

<img src="docs/active-directory/images/107-connexion-avec-le-compte-paul-kebre.webp" alt="Connexion avec le compte Paul Kebre" width="900">

#### 108. Ouverture de session de Paul Kebre

<img src="docs/active-directory/images/108-ouverture-de-session-de-paul-kebre.webp" alt="Ouverture de session de Paul Kebre" width="900">

#### 109. Accès au partage FilePartagerEngenieur

<img src="docs/active-directory/images/109-acces-au-partage-filepartagerengenieur.webp" alt="Accès au partage FilePartagerEngenieur" width="900">

#### 110. Ouverture de Ce PC pour connecter un lecteur

<img src="docs/active-directory/images/110-ouverture-de-ce-pc-pour-connecter-un-lecteur.webp" alt="Ouverture de Ce PC pour connecter un lecteur" width="900">

#### 111. Assistant de connexion d’un lecteur réseau

<img src="docs/active-directory/images/111-assistant-de-connexion-dun-lecteur-reseau.webp" alt="Assistant de connexion d’un lecteur réseau" width="900">

#### 112. Lecteur réseau Z connecté au partage

<img src="docs/active-directory/images/112-lecteur-reseau-z-connecte-au-partage.webp" alt="Lecteur réseau Z connecté au partage" width="900">

#### 113. Connexion avec le compte Aba

<img src="docs/active-directory/images/113-connexion-avec-le-compte-aba.webp" alt="Connexion avec le compte Aba" width="900">

#### 114. Ouverture de session du compte Aba

<img src="docs/active-directory/images/114-ouverture-de-session-du-compte-aba.webp" alt="Ouverture de session du compte Aba" width="900">

#### 115. Refus d’accès au partage pour Aba

<img src="docs/active-directory/images/115-refus-dacces-au-partage-pour-aba.webp" alt="Refus d’accès au partage pour Aba" width="900">

#### 116. Fond d’écran destiné au département Ingénieur

<img src="docs/active-directory/images/116-fond-decran-destine-au-departement-ingenieur.webp" alt="Fond d’écran destiné au département Ingénieur" width="900">

#### 117. Présence du partage dans Server Manager

<img src="docs/active-directory/images/117-presence-du-partage-dans-server-manager.webp" alt="Présence du partage dans Server Manager" width="900">

#### 118. Copie du fichier d’image dans NETLOGON

<img src="docs/active-directory/images/118-copie-du-fichier-dimage-dans-netlogon.webp" alt="Copie du fichier d’image dans NETLOGON" width="900">

#### 119. Ouverture de la console Group Policy Management

<img src="docs/active-directory/images/119-ouverture-de-la-console-group-policy-management.webp" alt="Ouverture de la console Group Policy Management" width="900">

#### 120. Création d’une GPO liée à l’OU _ENGINEERING

<img src="docs/active-directory/images/120-creation-dune-gpo-liee-a-lou-engineering.webp" alt="Création d’une GPO liée à l’OU _ENGINEERING" width="900">

#### 121. Nom de la GPO ImageDeFondEngenieur

<img src="docs/active-directory/images/121-nom-de-la-gpo-imagedefondengenieur.webp" alt="Nom de la GPO ImageDeFondEngenieur" width="900">

#### 122. Sélection du paramètre Desktop Wallpaper

<img src="docs/active-directory/images/122-selection-du-parametre-desktop-wallpaper.webp" alt="Sélection du paramètre Desktop Wallpaper" width="900">

#### 123. Activation et configuration du fond d’écran

<img src="docs/active-directory/images/123-activation-et-configuration-du-fond-decran.webp" alt="Activation et configuration du fond d’écran" width="900">

#### 124. Nouvelle connexion de Paul Kebre

<img src="docs/active-directory/images/124-nouvelle-connexion-de-paul-kebre.webp" alt="Nouvelle connexion de Paul Kebre" width="900">

#### 125. Fond d’écran appliqué au département Ingénieur

<img src="docs/active-directory/images/125-fond-decran-applique-au-departement-ingenieur.webp" alt="Fond d’écran appliqué au département Ingénieur" width="900">

</details>


---

## Partie 3 — Déploiement d’un SIEM avec Wazuh

Cette troisième partie poursuit le HomeLab en ajoutant une couche de supervision et de détection. Elle ne reprend pas le déploiement Active Directory : les machines déjà présentes deviennent des actifs supervisés par Wazuh.

### Objectifs

- déployer Wazuh avec Docker sur un serveur Ubuntu ;
- comprendre le rôle du Manager, de l’Indexer, du Dashboard et des agents ;
- superviser un hôte Windows et un serveur Ubuntu ;
- inventorier les services exposés avec Nmap dans un cadre autorisé ;
- configurer le **File Integrity Monitoring (FIM)** ;
- détecter la création d’un fichier en temps réel ;
- rechercher et interpréter des événements de sécurité Windows ;
- relier une alerte à son agent, son utilisateur, sa cible et son contexte.

### Architecture SIEM observée

| Composant | Adresse | Rôle |
|---|---:|---|
| Serveur Ubuntu / SRV-WAZUH | `172.16.0.60` | Docker, Wazuh Manager, Indexer, Dashboard et agent local |
| Hôte Windows `DC` | `172.16.0.1` | Actif supervisé et source d’événements Windows |
| Machine Kali | `172.16.0.61` | Validation réseau et génération contrôlée de télémétrie |
| Réseau du laboratoire | `172.16.0.0/16` | Communication entre le SIEM, les agents et la machine de test |

### Chaîne de traitement comprise

1. Une activité se produit sur un poste ou un serveur.
2. L’agent Wazuh collecte les journaux et informations utiles.
3. Le Manager décode les événements et applique ses règles.
4. L’Indexer conserve les données et permet leur recherche.
5. Le Dashboard restitue les alertes et le contexte d’investigation.

> [!WARNING]
> Les scans Nmap présentés ci-dessous sont réalisés uniquement dans un laboratoire autorisé. Un port ouvert n’est pas automatiquement une vulnérabilité, et un résultat négatif de `--script vuln` ne prouve pas qu’un système est exempt de vulnérabilités.

### Captures et déroulement du laboratoire

<details>
<summary><strong>1 — Préparation du serveur, Docker et Wazuh</strong></summary>

#### 1. Adresse réseau du serveur Ubuntu Wazuh

<img src="docs/siem-wazuh/images/01-reseau-serveur-wazuh.webp" alt="Adresse réseau du serveur Ubuntu Wazuh" width="900">

#### 2. Test de connectivité vers l’hôte Windows

<img src="docs/siem-wazuh/images/02-connectivite-hote-windows.webp" alt="Test de connectivité vers l’hôte Windows" width="900">

#### 3. Ajout de la clé et du dépôt Docker

<img src="docs/siem-wazuh/images/03-depot-docker.webp" alt="Ajout de la clé et du dépôt Docker" width="900">

#### 4. Installation de Docker Engine et Compose

<img src="docs/siem-wazuh/images/04-installation-docker.webp" alt="Installation de Docker Engine et Compose" width="900">

#### 5. Vérification du service Docker

<img src="docs/siem-wazuh/images/05-service-docker.webp" alt="Vérification du service Docker" width="900">

#### 6. Réglage de vm.max_map_count

<img src="docs/siem-wazuh/images/06-vm-max-map-count.webp" alt="Réglage de vm.max_map_count" width="900">

#### 7. Installation de Git

<img src="docs/siem-wazuh/images/07-installation-git.webp" alt="Installation de Git" width="900">

#### 8. Clonage de wazuh-docker v4.14.7

<img src="docs/siem-wazuh/images/08-clone-wazuh-docker.webp" alt="Clonage de wazuh-docker v4.14.7" width="900">

#### 9. Contrôle de l’arborescence Wazuh

<img src="docs/siem-wazuh/images/09-arborescence-wazuh.webp" alt="Contrôle de l’arborescence Wazuh" width="900">

</details>


<details>
<summary><strong>2 — Accès au Dashboard et contrôles de santé</strong></summary>

#### 10. Page de connexion Wazuh

<img src="docs/siem-wazuh/images/10-connexion-wazuh.webp" alt="Page de connexion Wazuh" width="900">

#### 11. Authentification administrateur

<img src="docs/siem-wazuh/images/11-authentification-wazuh.webp" alt="Authentification administrateur" width="900">

#### 12. Contrôles de santé de la plateforme

<img src="docs/siem-wazuh/images/12-health-check.webp" alt="Contrôles de santé de la plateforme" width="900">

#### 13. Tableau de bord avant l’ajout des agents

<img src="docs/siem-wazuh/images/13-dashboard-initial.webp" alt="Tableau de bord avant l’ajout des agents" width="900">

</details>


<details>
<summary><strong>3 — Enregistrement des agents Windows et Ubuntu</strong></summary>

#### 14. Agent Windows actif dans Wazuh

<img src="docs/siem-wazuh/images/14-agent-windows.webp" alt="Agent Windows actif dans Wazuh" width="900">

#### 15. Détails et inventaire de l’agent Windows

<img src="docs/siem-wazuh/images/15-details-agent-windows.webp" alt="Détails et inventaire de l’agent Windows" width="900">

#### 16. Installation de l’agent sur Ubuntu

<img src="docs/siem-wazuh/images/16-installation-agent-ubuntu.webp" alt="Installation de l’agent sur Ubuntu" width="900">

#### 17. Deux agents actifs dans le SIEM

<img src="docs/siem-wazuh/images/17-deux-agents-actifs.webp" alt="Deux agents actifs dans le SIEM" width="900">

</details>


<details>
<summary><strong>4 — Découverte réseau et validation avec Nmap</strong></summary>

#### 18. Adresse IP de la machine Kali

<img src="docs/siem-wazuh/images/18-adresse-kali.webp" alt="Adresse IP de la machine Kali" width="900">

#### 19. Scan TCP SYN de l’hôte Windows

<img src="docs/siem-wazuh/images/19-scan-syn-windows.webp" alt="Scan TCP SYN de l’hôte Windows" width="900">

#### 20. Détection des versions de services

<img src="docs/siem-wazuh/images/20-detection-versions.webp" alt="Détection des versions de services" width="900">

#### 21. Estimation du système d’exploitation

<img src="docs/siem-wazuh/images/21-detection-os.webp" alt="Estimation du système d’exploitation" width="900">

#### 22. Scan avancé de l’hôte Windows

<img src="docs/siem-wazuh/images/22-scan-avance.webp" alt="Scan avancé de l’hôte Windows" width="900">

#### 23. Informations TLS et certificat

<img src="docs/siem-wazuh/images/23-informations-tls.webp" alt="Informations TLS et certificat" width="900">

#### 24. Scan ciblé des ports UDP

<img src="docs/siem-wazuh/images/24-scan-udp.webp" alt="Scan ciblé des ports UDP" width="900">

#### 25. Scan ciblé des services principaux

<img src="docs/siem-wazuh/images/25-scan-ports-cibles.webp" alt="Scan ciblé des services principaux" width="900">

#### 26. Scripts Nmap de vulnérabilité

<img src="docs/siem-wazuh/images/26-scripts-vulnerabilites.webp" alt="Scripts Nmap de vulnérabilité" width="900">

#### 27. Scan complet du serveur Wazuh

<img src="docs/siem-wazuh/images/27-scan-complet-wazuh.webp" alt="Scan complet du serveur Wazuh" width="900">

#### 28. Empreintes des services Wazuh

<img src="docs/siem-wazuh/images/28-empreintes-services.webp" alt="Empreintes des services Wazuh" width="900">

</details>


<details>
<summary><strong>5 — Configuration avancée et surveillance FIM</strong></summary>

#### 29. État des conteneurs Wazuh

<img src="docs/siem-wazuh/images/29-conteneurs-wazuh.webp" alt="État des conteneurs Wazuh" width="900">

#### 30. Ouverture d’un shell dans le manager

<img src="docs/siem-wazuh/images/30-shell-manager.webp" alt="Ouverture d’un shell dans le manager" width="900">

#### 31. Installation d’un éditeur dans le conteneur

<img src="docs/siem-wazuh/images/31-editeur-conteneur.webp" alt="Installation d’un éditeur dans le conteneur" width="900">

#### 32. Options globales de journalisation

<img src="docs/siem-wazuh/images/32-journalisation-wazuh.webp" alt="Options globales de journalisation" width="900">

#### 33. Configuration du File Integrity Monitoring

<img src="docs/siem-wazuh/images/33-configuration-fim.webp" alt="Configuration du File Integrity Monitoring" width="900">

#### 34. Redémarrage et contrôle de l’agent

<img src="docs/siem-wazuh/images/34-redemarrage-agent.webp" alt="Redémarrage et contrôle de l’agent" width="900">

#### 35. Création d’un premier fichier de test

<img src="docs/siem-wazuh/images/35-fichier-test.webp" alt="Création d’un premier fichier de test" width="900">

#### 36. Création de important.txt dans /root

<img src="docs/siem-wazuh/images/36-fichier-important.webp" alt="Création de important.txt dans /root" width="900">

#### 37. Recherche dans wazuh-alerts-*

<img src="docs/siem-wazuh/images/37-recherche-alertes.webp" alt="Recherche dans wazuh-alerts-*" width="900">

#### 38. Détail de l’événement FIM

<img src="docs/siem-wazuh/images/38-evenement-fim.webp" alt="Détail de l’événement FIM" width="900">

#### 39. Chronologie des événements

<img src="docs/siem-wazuh/images/39-chronologie-evenements.webp" alt="Chronologie des événements" width="900">

</details>


<details>
<summary><strong>6 — Collecte d’un événement de sécurité Windows</strong></summary>

#### 40. Action utilisateur sur l’hôte Windows

<img src="docs/siem-wazuh/images/40-action-utilisateur-windows.webp" alt="Action utilisateur sur l’hôte Windows" width="900">

#### 41. Événement Windows 4722 remonté dans Wazuh

<img src="docs/siem-wazuh/images/41-evenement-windows-4722.webp" alt="Événement Windows 4722 remonté dans Wazuh" width="900">

</details>


### Résultat du test FIM

La création du fichier `/root/important.txt` produit un événement contenant notamment :

- le chemin surveillé ;
- l’agent ayant généré l’événement ;
- le mode `realtime` ;
- l’action `added` ;
- les empreintes du fichier ;
- la règle Wazuh correspondante.

Cette validation démontre le parcours complet d’une donnée de sécurité : génération sur l’hôte, collecte par l’agent, traitement par Wazuh, indexation et recherche dans `wazuh-alerts-*`.

### Interprétation de l’événement Windows

La dernière séquence montre la remontée de l’**Event ID 4722**, associé à l’activation d’un compte utilisateur. Les champs Wazuh permettent d’identifier :

- l’agent source ;
- le compte cible ;
- le compte ayant réalisé l’action ;
- le domaine concerné ;
- le journal Windows `Security` ;
- l’horodatage de l’événement.

Un événement isolé ne constitue pas automatiquement un incident. Il doit être comparé aux changements autorisés, à l’horaire, au poste source et aux événements voisins.

### Bonnes pratiques retenues

- remplacer le certificat non approuvé par un certificat adapté au nom DNS utilisé ;
- changer les identifiants initiaux et protéger les comptes administrateurs ;
- limiter les ports Wazuh aux sources strictement nécessaires ;
- ne pas exposer inutilement l’Indexer ou l’API de gestion ;
- rendre persistants les paramètres système et les configurations Docker ;
- définir une politique de rétention et surveiller l’espace disque ;
- limiter `logall`, `logall_json` et le FIM temps réel au périmètre utile ;
- conserver une trace des scans et changements de test pour les distinguer d’un incident réel.

### Vérifications finales

- [ ] Docker est actif.
- [ ] Les conteneurs Manager, Indexer et Dashboard sont démarrés.
- [ ] Les contrôles de santé Wazuh réussissent.
- [ ] Les agents Windows et Ubuntu apparaissent actifs.
- [ ] L’événement FIM pour `/root/important.txt` est visible.
- [ ] L’événement Windows 4722 contient les champs attendus.
- [ ] Les alertes sont analysées avec leur contexte plutôt qu’avec leur seule sévérité.

> [!IMPORTANT]
> Cette architecture est conçue pour l’apprentissage. En production, il faut dimensionner les ressources, protéger les secrets et certificats, filtrer les flux, sauvegarder la configuration et définir un processus formel de traitement des alertes.

