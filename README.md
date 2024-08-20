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
s’arrête immédiatement. À leur arrivée, les médecins disputent aux patients l’accès à l’entrée de la salle d’attente à l’aide du verrou attente ; c’est la seule fois au cours de leur exécution qu’ils utilisent ce verrou.

## 3.3 Interactions entre patients et médecins
L’interaction entre médecin et patient est basée sur deux types de synchronisation :

— le médecin est un consommateur de patients dans le tampon formé par les sièges de la salle d’attente ;

— médecin et patient s’échangent des messages pour mener à bien la vaccination.

Le code ci-dessous est exécuté par les acteurs après qu’ils ont obtenu leur accès au vaccinodrome. On trouve un
patient à gauche, et un médecin à droite. L’espacement vertical est sans signification et ne sert qu’à mettre en
regard l’envoi et la réception d’un message.

![Interactions entre patients et médecins](assets/vdm3.3.png)

La décoration représente le rendez-vous (flèches doubles), la synchronisation entre producteur et consommateur (flèches simples), ainsi que la communication de données via la mémoire partagée (flèches pointillées).

Pour assurer la cohérence de la salle d’attente, c’est-à-dire éviter les situations de concurrence destructrice entre médecins cherchant leurs patients simultanément, le premier échange de message (« `entrez` », « `piquez` ») fait partie intégrante de l’opération de consommation du médecin, effectuée sous la protection du verrou service.

## 3.4 Fermeture du vaccinodrome
Au moment de la fermeture, il y a éventuellement des patients assis dans la salle d’attente, et éventuellement
des patients attendant d’y trouver un siège. Il y a ensuite deux possibilités :
1. soit il y a des médecins en train de vacciner ;
2. soit aucun médecin ne s’est présenté jusqu’alors.

Le second cas n’est pas exclu par le sujet, j’ai donc choisi de le traiter.

L’opération de fermeture commence par demander la destruction, par shm_unlink(), du segment de mémoire
partagée : cette opération n’affecte pas les processus en cours d’exécution, mais empêche de nouveaux processus
d’y accéder. Il faut ensuite positionner le booléen ouvert à false, ce qui empêche de nouveaux acteurs de
prendre part à la vaccination.

Pour ce qui est des patients qui n’ont pas encore pu obtenir de siège au moment de la fermeture, la section 3.1
montre qu’il vont traverser la salle d’attente et repartir aussitôt, à condition qu’un siège soit disponible tôt ou
tard. Mais cet événement est garanti par le fait que les médecins continuent de vacciner, et que les patients ne
« produisent » plus de siège occupé : donc, dès qu’un premier siège devient disponible, tous les patients sans
siège ont la possibilité de se terminer. Si il n’y a aucun médecin, la fermeture devra s’assurer qu’un siège devient
disponible tôt ou tard. Il n’y a rien d’autre à faire, et de toute façon les possibilités d’action sont limitées (il est
toujours possible qu’un processus « lent » ait projeté le segment dans son espace d’adressage mais pas encore
demandé un siège via sglibres). Le procédure de fermeture fait son possible, mais pas plus.

Après avoir interdit l’accès au segment de mémoire partagée, la fermeture détermine la situation à laquelle elle
fait face, et conserve dans une variable le nombre de médecins présents, qui ne changera plus :

![Fermeture du vaccinodrome](assets/vdm3.4.png)

La suite de la procédure distingue les deux cas. Dans le premier elle informe les patients assis (s’il y en a) qu’ils
sont expulsés en leur proposant de passer dans un box qui n’existe pas. Dans le second elle présente des patients
factices aux médecins encore présents. Les détails sont donnés dans les deux sections suivantes.

Les deux cas ont toutefois un point commun : la procédure de fermeture doit s’assurer qu’un acteur qui est informé de la fermeture n’a plus besoin d’accéder au segment de mémoire partagée. La raison en est que les sémaphores vont être détruits juste après avec `sem_destroy()`, et tout accès ultérieur y provoquerait un comportement indéfini [5]. L’expulsion d’un patient assis ne pose pas de problème : le message qu’il reçoit est son dernier usage d’un sémaphore. Mais l’arrêt d’un médecin nécessite un acquittement de sa part.

## 3.5 Patients après fermeture
Cette section détaille ce qui se passe entre le processus de fermeture et les patients de la salle d’attente lorsqu’il
n’y a aucun médecin dans la vaccinodrome : c’est donc le cas medecin == 0 dans la section précédente.

![Patients après fermeture](assets/vdm3.5.png)

Le code du patient (à gauche, repris de la section 3.3) précise simplement que s’il trouve un numéro de box
égal au nombre total de box **m**, cela signifie qu’il est expulsé. La suite de son exécution consiste à se détacher du
segment de mémoire partagée via munmap(), sans avoir besoin d’accéder au moindre sémaphore.

Le processus chargé de la fermeture (à droite) prend le rôle d’un médecin : puisqu’il est seul dans ce rôle il peut
conserver le verrou service sans pénaliser aucun autre acteur. Il parcourt les patients présents en consultant
les noms sur les sièges (qui sont factices pour tous les sièges inoccupés – c’est garanti par l’initialisation et par
l’action des médecins après le choix d’un patient). Pour chaque siège occupé, il « attend » (sans délai possible)
de trouver un patient assis, le « consomme » en mettant à jour la salle d’attente et en envoyant un message
d’expulsion. Il incrémente ensuite le compteur de places libres au cas où des patients attendraient pour traverser
l’entrée et repartir sans être vacciné, ce qui ne peut arriver qu’une seule fois à la première itération de la boucle.
Il répète l’opération tant qu’il trouve des patients encore assis.


## 3.6 Médecins après fermeture
Cette section détaille ce qui se passe entre le processus de fermeture et les médecins qui vaccinent encore : c’est
donc le cas else ... à la fin du pseudo-code dans la section ***3.4***.

![Médecins après fermeture](assets/vdm3.6.png)


On voit ici (à gauche) qu’un médecin qui trouve un patient factice « rend » une place libre à la salle d’attente
(les indices ont déjà été mis à jour – cf. section ***3.3***), puis il répond en envoyant un message d’acquittement
via le sémaphore mp_entrez du siège qu’il vient de consommer. Ici cet envoi de message n’est pas fait sous la
protection du verrou service, contrairement à ce qui se passe avec un patient normal : d’une part, le siège ne
sera pas réutilisé et il n’y a aucun risque de concurrence destructrice, et d’autre part ce message d’acquittement
doit être sa dernière utilisation d’un sémaphore, et ne peut donc pas être suivie d’une opération **V()** sur le verrou service. Le médecin se termine ensuite après avoir détaché le segment de mémoire partagée.

Le processus de fermeture (à droite) quant à lui attend une place libre (ce qui arrivera certainement puisqu’il reste des médecins), « produit » un patient factice, signale son existence aux médecins, et attend l’acquittement d’un médecin via le sémaphore `mp_entrez` du siège. Il répète cette opération pour chaque médecin. Le fait qu’il relâche le verrou attente entre deux créations de patients factices est délibéré, afin que les patients retardataires aient la possibilité d’entrer dans la salle d’attente pour trouver le vaccinodrome fermé.

Cette procédure d’information des médecins ne fonctionne que parce que nous utilisons un tampon borné circulaire. On a la garantie que les patients factices arrivent après tous les patients réels déjà assis, et qu’aucun patient réel ne peut plus arriver sur un siège de la salle d’attente (le vaccinodrome est fermé). Puisque les médecins traitent les patients exactement dans l’ordre d’arrivée, l’apparition d’un patient factice dans un box assure au médecin qu’il ne verra plus jamais de patient réel. Il peut donc s’arrêter.

La procédure de fermeture dans son ensemble garantit que tous les verrous sont relâchés, que tous les messages envoyés sont reçus, et que tous les compteurs retrouvent leur valeur initiale. Les indices `sgprem` et `sgsuiv` ont
également une valeur correcte ; si le segment de mémoire n’avait pas été détruit, il suffirait de redonner à `bxsuiv`
la valeur 0 pour pouvoir à nouveau ouvrir le vaccinodrome, et accueillir de nouveaux patients et médecins.