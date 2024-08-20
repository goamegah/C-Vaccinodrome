# C-Vaccinodrome
Implementation en C d'une modélisation d'un vaccinodrome composé d’une salle d’attente contenant n sièges pour les patients et d’un service de vaccination comportant m box occupés éventuellement par des médecins.

Note : ce rapport est très détaillé et essaie d’être aussi précis que possible. Il va sur certains points au-delà
de ce qui était attendu. Les parties essentielles sont la section 2.1 sur la mémoire partagée, la section 3.3 sur
l’interaction entre acteurs, et la section 3.6 pour le traitement des médecins à la fermeture.


# Introduction

Le projet consiste à modéliser un vaccinodrome composé d’une salle d’attente contenant n sièges pour les patients et d’un service de vaccination comportant m box occupés éventuellement par des médecins. Les acteurs
(patients ou médecins) peuvent arriver à tout moment, et la vaccination (de durée fixée t) a lieu dès que possible. La fermeture du vaccinodrome empêche de nouvelles entrées de patients dans la salle d’attente (ou de médecin dans un box), mais les médecins présents continuent de vacciner tant que la salle n’est pas vide. Les acteurs sont tous représentés par des processus indépendants, et les seuls objets de synchronisation disponibles sont les sémaphores
Nous avons choisi de résoudre ce problème de la façon suivante :

— la salle d’attente est vue comme un tampon circulaire borné contenant des sièges 

— chaque patient est un producteur d’une seule unité dans ce tampon (lui-même assis sur un siège)

— chaque médecin consomme, de façon répétée, un patient assis dans le tampon pour le vacciner

— une vaccination est un rendez-vous entre médecin et patient, similaire à celui d’un coiffeur avec ses clients.

Notre projet suit exactement ces modèles : ce sont donc les médecins qui choisissent les patients. La fermeture du vaccinodrome utilise un mécanisme de patients factices (et dans certaines conditions de médecins factices) pour terminer proprement.


# Structure de données
## Structures de données partagées

Le tableau suivant décrit tous les éléments présents dans une mémoire partagée par tous les processus. Les trois
zones du segment de mémoire partagée (le bloc de contrôle ```ctl``` et les deux tableaux ```sgs``` et ```bxs```) sont stockées consécutivement dans la mémoire [1].

![Description de l'image](assets/vdm2.1.png)

On utilise les types standard size_t pour toutes les positions et tailles, et struct timespec pour la durée. Le
type nom_t contient un nom de taille fixée (10 caractères) et permet l’affectation [4]. Le type `asem_t` est celui
fourni avec le sujet, et représente un sémaphore, muni d’un nom utilisé dans les traces de programmes.



## Structures de données non partagées
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