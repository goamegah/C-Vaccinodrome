#include <semaphore.h>

/*
 * Ce fichier est spécifique pour le projet.
 * Il ne doit en aucun cas être modifié
 */

#define MAX_NOMSEM      10              // taille d'un nom de sémaphore

/*
 * Pour faciliter le debug, on utilise une structure contenant
 * à la fois le sem_t et un nom (fourni par votre programme)
 * pour identifier les sémaphores non nommés.
 * Tous les messages de debug utiliseront ce nom.
 */

typedef struct asem
{
    char nom [MAX_NOMSEM + 1] ;
    sem_t sem ;
} asem_t ;

/*
 * Niveau de debug (pour ase_debug) pour les synchronisations.
 * La valeur 1 affiche les informations de synchronisation.
 * Note : il est suggéré de centraliser les autres niveaux de debug
 * des messages dans un fichier .h commun à tous vos programmes
 */

#define DBG_SYNC        1

/*
 * Voir la description des fonctions dans asem.c
 */

// système d'affichage de debug
int ainit (char *) ;
void adebug (int, const char *, ...) ;

// fonctions sur les sémaphores en mémoire partagée (i.e. pas sem_open)
int asem_init (asem_t *, const char *, int, unsigned int) ;
int asem_destroy (asem_t *) ;
int asem_wait (asem_t *) ;
int asem_post (asem_t *) ;
int asem_trywait (asem_t *) ;
int asem_timedwait (asem_t *, const struct timespec *) ;
int asem_trywait (asem_t *) ;
int asem_getvalue (asem_t *, int *) ;
