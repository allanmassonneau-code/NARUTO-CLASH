# Mise en ligne (VPS + launcher Windows)

Architecture :
- **VPS** : 2 processus Godot headless : le monde partagé persistant (UDP 7777,
  `naruto-server@1v1`) et le service de comptes du launcher (UDP 7778, `naruto-server@2v2`) + nginx qui sert les mises à jour sur
  `http://<IP>/naruto-clash/`.
- **GitHub Actions** (`.github/workflows/release.yml`) : à chaque push sur `main`, tests →
  build Windows → publication sur le VPS → redémarrage des serveurs.
- **Launcher** (`NarutoClashLauncher.exe`) : lit `version.json`, télécharge et vérifie (SHA-256)
  la nouvelle version, lance le jeu connecté au serveur officiel.

## 1. Créer la clé de déploiement (sur ton PC)
```
ssh-keygen -t ed25519 -f naruto_deploy -N "" -C "naruto-ci"
```
Ça crée `naruto_deploy` (privée, pour GitHub) et `naruto_deploy.pub` (publique, pour le VPS).

## 2. Préparer le VPS (une seule fois, en root)
Copier `deploy/vps_setup.sh` sur le VPS puis :
```
sudo bash vps_setup.sh --inventory                       # voir ce qu'il y a, ne touche à rien
sudo bash vps_setup.sh --wipe --deploy-key "$(cat naruto_deploy.pub)"
```
`--wipe` demande de taper `WIPE` et supprime toutes les anciennes applis (Docker, pm2,
services systemd perso, sites nginx, /opt, /srv, /var/www, crontab root). SSH, utilisateurs et
paquets système sont conservés. Sans `--wipe`, rien n'est supprimé.

## 3. Secrets GitHub
Repo → Settings → Secrets and variables → Actions → New repository secret :

| Nom | Valeur |
|---|---|
| `VPS_HOST` | IP publique du VPS (ex. `51.75.12.34`) |
| `VPS_USER` | `deploy` |
| `VPS_SSH_KEY` | contenu complet du fichier `naruto_deploy` (clé privée) |

## 4. Publier
Merger sur `main` (ou Actions → "Build & deploy" → Run workflow). Le job publie
`NarutoClashLauncher.exe` sur `http://<IP>/naruto-clash/NarutoClashLauncher.exe` :
c'est le seul fichier à donner aux joueurs. Chaque nouveau push = nouvelle version, le
launcher la télécharge au prochain lancement, et le serveur refuse les clients pas à jour.

## Déploiement manuel (sans CI)
```
GODOT=/chemin/vers/godot deploy/build_release.sh 0.3.100 <IP> "notes de version"
deploy/deploy.sh <IP> deploy
```
