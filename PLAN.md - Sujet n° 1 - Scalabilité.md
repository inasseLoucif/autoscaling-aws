# PLAN.md - Sujet n° 1 - Scalabilité  
## Groupe n°12 - Inasse & Sabrina  
  
## Objectifs du sujet:  
Mettre en place un système capable de s’adapter automatiquement à la charge, simuler une charge sur ce système, observer la montée en charge sur CloudWatch et utiliser l’infrastructure as code.  
  
## Sommaire du plan d’action :  
- Établir un point de départ précis.  
- Définir les étapes techniques.  
- Construire les plateformes de rendu avant d’entamer les travaux techniques.  
- Répartir les tâches entre les acteurs du projet.  
  
  
## Point de départ :  
Nous avons accès à AWS Academy et disposons de deux machines physiques. Aucune d’entre nous n’a travaillé sur CloudWatch auparavant. Inasse possède déjà une expérience de Terraform et Ansible, tandis que nous avons toutes les deux une première expérience avec AWS (voir TP1 et TP2).  
  
## Etapes techniques :   
- Rédaction du document « plan.md », qui constituera le premier commit.  
- Mise en place du système de contrôle de version Git avec l’arborescence du projet.  
- Section Terraform :  
    - Créer une VM terraform ?  
    - Rédaction du fichier « main.tf ».  
    - Déploiement sur Amazon Web Services (AWS).  
- Exécution d’un test initial sur AWS afin de vérifier le fonctionnement des instances (voir TP1).  
- Installation d’Amazon CloudWatch sur AWS.  
- Mise en œuvre d’un test de charge.  
- Analyse des résultats du test de charge à l’aide d’Amazon CloudWatch.  
- Elaboration du killswitch afin de ne pas dépasser le budget alloué.  
  
## Construction des rendus :   
1. Créer un dépôt GitHub et l’arborescence du projet.  
2. Rédiger le fichier PLAN.md.  
3. Valider et publier le fichier PLAN.md.  
4. Commit du main.tf  
  
## Répartitions des tâches :  
Les différentes tâches seront attribuées au fur et à mesure de l’avancement du projet, en fonction de la progression individuelle de chaque membre de l’équipe et de ses préférences.  
  
À ce jour, les tâches ont été réparties comme suit :   
  

|  | Inasse | Sabrina |
| -------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Plateforme et rendus | Création de la Repo Git | Rédaction et commit du PLAN.md |
|  | Création de l’arborescence du projet sur Git | 
 |
|  | Rédaction du Read.ME |  |
|  | Initial commit |  |
| Terraform | Installation de Terraform sur poste | Installation de Terraform sur AWS |
|  | Création des instances et de l’autoscalling Group + premier test de déploiement | Exécution d’un test initial sur AWS afin de vérifier le fonctionnement des instances |
|  | Mise au point d’un premier main.tf | Reprise du main et ajout de la partie CloudWatch |
|  | Test Load balancing et calling group sur AWS Academy | Elaboration du système de killswitch |
|  |  | Premier main.tf complet |
|  | Merge | Ecriture de la formule python exécute par lambda |
|  |  | Test de la solution complète sur AWS |
| Présentation | Création du support de présentation | Orchestration du test |
  
  
  
  
  
  
  
