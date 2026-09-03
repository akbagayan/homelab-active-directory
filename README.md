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

