Projet : Migration d'une application on-premise vers une infrastructure hautement disponible et scalable sur AWS

# Infrastructure AWS avec Terraform

Ce dossier contient la configuration d'infrastructure pour le projet, utilisant Terraform afin de provisionner et gérer les ressources AWS.

## Fichiers présents

- `backend.tf` : Configure le backend distant pour stocker l'état Terraform dans un bucket S3.
- `backend.tfvars`, `variables.tf`, `main.tf`, `provider.tf`, `iam.tf`, `locals.tf` : Fichiers standards de configuration Terraform pour la gestion des ressources, des variables, des providers et des rôles IAM.

## Détail de la configuration du backend

Le backend Terraform est configuré pour utiliser un bucket S3 nommé `myallstatefiles` dans la région `us-east-1`. Le fichier d'état (`terraform.tfstate`) est stocké sous la clé `appfront/terraform.tfstate`. Le verrouillage de l'état (`use_lockfile = true`) est activé pour éviter les conflits lors des modifications concurrentes.

Extrait du fichier `backend.tf` :

```hcl
terraform {
  backend "s3" {
    bucket = "myallstatefiles"
    key    = "appfront/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}
```

## Prochaines étapes

- Compléter la configuration des ressources dans les autres fichiers Terraform.
- Initialiser le backend avec `terraform init`.
- Appliquer la configuration avec `terraform apply`.

## Gestion des workspaces Terraform

Le projet utilise la fonctionnalité des workspaces de Terraform pour gérer différents environnements (par exemple : `default`, `dev`, `prod`).

- Les variables et la configuration sont adaptées dynamiquement selon le workspace courant grâce à l’utilisation de `terraform.workspace` dans les fichiers de configuration.
- Assure-toi que la variable `environment` contient bien une clé pour chaque workspace utilisé.

### Commandes utiles

- Créer un nouveau workspace :
  ```sh
  terraform workspace new <nom_workspace>
  ```
- Changer de workspace :
  ```sh
  terraform workspace select <nom_workspace>
  ```
- Lister les workspaces :
  ```sh
  terraform workspace list
  ```

---

## Configuration de Route53 et ACM (certificats SSL)

### Prérequis
- Disposer d'une zone hébergée Route53 correspondant à votre domaine (ex : `example.com`).
- Avoir les droits nécessaires pour créer/modifier des enregistrements DNS et gérer ACM.

### Logique de la configuration

1. **Récupération de la zone DNS**
   - Utilisation de la ressource `data "aws_route53_zone"` pour pointer vers la zone publique du domaine.

2. **Création du certificat ACM**
   - Le certificat est demandé pour un sous-domaine ou le domaine principal (ex : `www.example.com` ou `example.com`).
   - La validation se fait par DNS.

3. **Création automatique de l'enregistrement DNS de validation**
   - Terraform crée un enregistrement CNAME (ou autre) dans la zone Route53 pour prouver à AWS que vous contrôlez le domaine.

4. **Validation du certificat**
   - Une fois l'enregistrement propagé, ACM valide automatiquement le certificat.

### Exemple d'extrait Terraform

```hcl
# Récupération de la zone DNS
 data "aws_route53_zone" "selected" {
   name = local.env.domain_name
   private_zone = false
 }

# Création du certificat ACM
resource "aws_acm_certificate" "cert" {
  domain_name       = "${local.env.record_name}.${local.env.domain_name}"
  validation_method = "DNS"
}

# Enregistrement DNS pour la validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Validation du certificat
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```

### Points d'attention
- **Correspondance exacte du domaine** : le domaine du certificat doit correspondre à la zone Route53.
- **Propagation DNS** : la validation peut prendre quelques minutes, le temps que l'enregistrement DNS soit visible publiquement.
- **Région ACM** : pour CloudFront, le certificat doit être créé en `us-east-1`.
- **Suppression/récréation** : en cas d'échec de validation, supprimer le certificat ACM et relancer Terraform peut débloquer la situation.

---

## Déploiement initial du site statique

Après la création de l'infrastructure (S3, CloudFront, Route53, ACM), il est nécessaire d'uploader le fichier `index.html` dans le bucket S3 correspondant à votre domaine (exemple : `dev.eksops.site`).

### Étape manuelle (premier déploiement)

Lors du premier déploiement, le fichier `index.html` a été uploadé manuellement dans le bucket S3 créé par Terraform :

1. Se rendre dans la console AWS S3, sélectionner le bucket nommé `dev.eksops.site` (ou le nom généré par vos variables Terraform).
2. Uploader le fichier `index.html` à la racine du bucket.

Ou bien, en ligne de commande :
```sh
aws s3 cp path/to/index.html s3://dev.eksops.site/index.html
```

> ⚠️ Si le fichier n'est pas présent à la racine du bucket, CloudFront retournera une erreur `NoSuchKey` lors de l'accès au site.

Pour automatiser cette étape lors des prochains déploiements, il est recommandé d'utiliser un script ou une commande `aws s3 sync` pour uploader tous les fichiers statiques nécessaires.

*Ce fichier README permet de garder une trace claire de l'état initial de l'infrastructure et de faciliter la reprise ou la révision du projet ultérieurement.* 

---

## Pipelines CI/CD GitHub Actions

Trois workflows automatisent la gestion de l’infrastructure et le déploiement de l’application front-end :

### 1. `apply.yml` — Provisionnement de l’infrastructure
Ce pipeline permet de déployer ou mettre à jour l’infrastructure AWS via Terraform. Il propose le choix de l’environnement (`dev` ou `prod`) et exécute toutes les étapes nécessaires : initialisation, sélection/création du workspace, validation, planification et application des changements.

### 2. `deploy.yml` — Déploiement du front-end sur S3
Ce pipeline permet de déployer automatiquement le contenu du dossier `front-end` dans le bucket S3 correspondant à l’environnement choisi (`dev.eksops.site` ou `prod.eksops.site`). Il s’utilise après la création de l’infrastructure pour mettre à jour le site statique.

### 3. `destroy.yml` — Suppression de l’infrastructure
Ce pipeline permet de détruire toute l’infrastructure provisionnée par Terraform pour l’environnement sélectionné. Il est utile pour nettoyer complètement un environnement (`dev` ou `prod`).

**Utilisation :**
- Les trois workflows sont déclenchables manuellement depuis l’onglet “Actions” de GitHub.
- À chaque lancement, il faut choisir l’environnement cible (`dev` ou `prod`).
- Les identifiants AWS doivent être configurés dans les secrets du dépôt GitHub. 