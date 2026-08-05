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

```text
Amadou Diallo
Fatou Ndiaye
Claire Martin
Jean Dupont
```

Aucun point-virgule n’est nécessaire. Le premier mot est utilisé comme prénom et le reste de la ligne comme nom.

### Utilisation recommandée

Ouvrir PowerShell avec un compte autorisé, puis exécuter :

```powershell
Import-Module ActiveDirectory
Set-Location C:\Chemin\du\projet
.\scripts\New-LabADUsers.ps1 -InputFile .\users.txt -TargetOU "OU=_USERS,DC=bagayan,DC=local" -WhatIf
```

Après vérification du résultat simulé, retirer `-WhatIf` :

```powershell
.\scripts\New-LabADUsers.ps1 -InputFile .\users.txt -TargetOU "OU=_USERS,DC=bagayan,DC=local"
```

Le script demande le mot de passe de manière masquée et gère les identifiants déjà utilisés.

> [!WARNING]
> Pour les besoins de certains tests, un mot de passe temporaire peut apparaître en clair dans un exemple ou une ancienne version du script. Cette pratique est limitée à un environnement de laboratoire isolé. N’utilisez jamais ce mot de passe en production et remplacez-le après les essais.

N’utilisez pas `Set-ExecutionPolicy Unrestricted`. Si l’exécution est bloquée, préférez une politique limitée au processus :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

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

