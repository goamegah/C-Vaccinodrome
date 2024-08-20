# C-Vaccinodrome
Implementation en C d'une modélisation d'un vaccinodrome composé d’une salle d’attente contenant n sièges pour les patients et d’un service de vaccination comportant m box occupés éventuellement par des médecins.

Note : ce rapport est très détaillé et essaie d’être aussi précis que possible. Il va sur certains points au-delà
de ce qui était attendu. Les parties essentielles sont la section 2.1 sur la mémoire partagée, la section 3.3 sur
l’interaction entre acteurs, et la section 3.6 pour le traitement des médecins à la fermeture.


# 1. Introduction

Le projet consiste à modéliser un vaccinodrome composé d’une salle d’attente contenant n sièges pour les patients et d’un service de vaccination comportant m box occupés éventuellement par des médecins. Les acteurs
(patients ou médecins) peuvent arriver à tout moment, et la vaccination (de durée fixée t) a lieu dès que possible. La fermeture du vaccinodrome empêche de nouvelles entrées de patients dans la salle d’attente (ou de médecin dans un box), mais les médecins présents continuent de vacciner tant que la salle n’est pas vide. Les acteurs sont tous représentés par des processus indépendants, et les seuls objets de synchronisation disponibles sont les sémaphores
Nous avons choisi de résoudre ce problème de la façon suivante :

— la salle d’attente est vue comme un tampon circulaire borné contenant des sièges 

— chaque patient est un producteur d’une seule unité dans ce tampon (lui-même assis sur un siège)

— chaque médecin consomme, de façon répétée, un patient assis dans le tampon pour le vacciner

— une vaccination est un rendez-vous entre médecin et patient, similaire à celui d’un coiffeur avec ses clients.

Notre projet suit exactement ces modèles : ce sont donc les médecins qui choisissent les patients. La fermeture du vaccinodrome utilise un mécanisme de patients factices (et dans certaines conditions de médecins factices) pour terminer proprement.


# 2. Structure de données
## 2.1 Structures de données partagées

Le tableau suivant décrit tous les éléments présents dans une mémoire partagée par tous les processus. Les trois
zones du segment de mémoire partagée (le bloc de contrôle ```ctl``` et les deux tableaux ```sgs``` et ```bxs```) sont stockées consécutivement dans la mémoire [1].

![Structures de données partagées](assets/vdm2.1.png)

On utilise les types standard size_t pour toutes les positions et tailles, et struct timespec pour la durée. Le
type nom_t contient un nom de taille fixée (10 caractères) et permet l’affectation [4]. Le type `asem_t` est celui
fourni avec le sujet, et représente un sémaphore, muni d’un nom utilisé dans les traces de programmes.

Les sémaphores utilisés sont décrits selon leur usage :

— une *quantité* est un sémaphore « classique » permettant l’attribution de ressources, et sert aux consomma-
teurs (via l’opération **P**) et aux producteurs (via **V**) : ici sglibres et sgoccupes mesurent l’occupation des
sièges de la salle d’attente, qui est un tampon borné contenant des patients ;

— un *verrou* permet l’exclusion mutuelle pour l’accès aux données associées (via **P** et **V** utilisées successivement par un processus) : ici attente protège `ouvert/sgsuiv/bxsuiv`, et service protège sgprem ;

— un *message* permet à un processus de « réveiller » (via **V**) un autre processus qui « attend » (via **P**) ; dans
notre cas les noms des messages sont préfixés par deux caractères indiquant les types des émetteur et
récepteur (`mp` : du médecin au patient, et vice-versa).
Enfin, le segment de mémoire partagée n’est pas accessible avant d’être complètement initialisé, afin de garantir
qu’aucun processus trop empressé ne puisse y trouver un état incorrect [2].

## 2.2 Structures de données non partagées
Chaque processus accède au segment de mémoire partagée via trois pointeurs initialisées au moment de l’attachement par `mmap` [3] ; leurs noms figurent dans la première colonne du tableau ci-dessus. On utilise aussi des variables locales nommées nom, patient, siege ou box pour représenter des données utilisées temporairement par un programme : leurs déclarations n’apparaissent pas dans le pseudo-code ci-après.

# 3. Synchronisations
Les sections suivantes décrivent l’action des différents acteurs (patients, médecins, et processus de fermeture),
sous la forme de pseudo-code. Nous avons conservé dans ce pseudo-code quelques idiosyncrasies du langage
C (les pointeurs, les boucles, les étiquettes) mais omis certains détails :

— chaque programme débute par l’attachement du segment de mémoire partagée (qui initialise `ctl`, `sgs` et
`bxs`), et se termine par le détachement de ce segment ;

— l’imbrication des structures de contrôle est traduite par l’indentation, et toutes les accolades sont omises ;

— les étiquettes d’instruction (« P1: » etc.) ne servent qu’à baliser les fragments de code ; en particulier, elles
sont considérées comme faisant partie de l’indentation ;

— certaines parties non pertinentes sont remplacées par ... et souvent décrites plus loin dans le rapport.
D’autre part, le mécanisme de fermeture du vaccinodrome intervient à divers endroits du code, mais sa description complète est différée à la section ***3.4***.

## 3.1 Arrivée d’un patient
Un patient entrant a besoin d’obtenir un siège libre, après quoi il peut, s’il n’est pas trop tard, occuper le siège
en y inscrivant son nom, et enfin signaler aux éventuels médecins qu’un siège supplémentaire est occupé.

![Arrivée d’un patient](assets/vdm3.1.png)

Le test d’ouverture et l’obtention du siège sont effectués simultanément, en exclusion mutuelle sur l’entrée de
la salle d’attente. Les patients qui « attendent dehors » sont ceux qui sont bloqués sur le sémaphore `sglibres`.

## 3.2 Arrivée d’un médecin
Un médecin doit également accéder à l’entrée de la salle d’attente, afin de vérifier que le vaccinodrome est
ouvert et qu’il est encore possible d’obtenir un box.

![Arrivée d’un médecin](assets/vdm3.2.png)

Un médecin n’attend pas un box : le test de disponibilité est immédiat et définitif. Un médecin retardataire
s’arrête immédiatement. À leur arrivée, les médecins disputent aux patients l’accès à l’entrée de la salle d’attente
à l’aide du verrou attente ; c’est la seule fois au cours de leur exécution qu’ils utilisent ce verrou.