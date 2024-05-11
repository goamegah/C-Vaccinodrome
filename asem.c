#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdarg.h>
#include <time.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include "asem.h"

/*
 * Ce fichier est spécifique pour le projet.
 * Il ne doit en aucun cas être modifié
 */

/******************************************************************************
 * Fioritures d'affichage pour rendre les messages d'erreur, le
 * debug et la trace plus sympathiques
 */

/**
 * @var ase
 * @brief Variable privée pour ce module
 *
 * La variable ci-dessous est utilisée pour stocker des données
 * propres à ce module et qui n'ont pas à être connues ailleurs
 * dans le programme.
 */

static struct
{
    char *prog ;                // pour les messages d'erreur
    struct timespec debut ;     // pour l'horodatage des msg de debug
    pid_t pid ;                 // pour les msg de debug
    int debuglevel ;            // niveau de debug demandé
} ase ;

/*
 * @brief Initialisation du système de debug
 *
 * Cette fonction doit être appelée au démarrage du programme et sert
 * à initialiser le système de debug en mémorisant les informations
 * suivantes :
 * - le nom du programme,
 * - le niveau maximum des messages à afficher (variable d'environnement)
 * - le pid du processus
 * - l'heure de démarrage du programme
 *
 * @param argv0 le nom du programme
 * @result 0 si ok, ou -1 si erreur
 */

int
ainit (char *argv0)
{
    char *debugenv ;

    // pour avoir "a.out" (p.ex.) au lieu de "/home/machin/a.out"
    ase.prog = strrchr (argv0, '/') ;   // chercher le dernier '/'
    if (ase.prog != NULL)
        ase.prog++ ;
    else ase.prog = argv0 ;             // pas de '/' dans argv0

    // niveau de debug : 0 = pas de debug, 99 = bcp de debug
    ase.debuglevel = 0 ;                // par défaut
    debugenv = getenv ("DEBUG_ASE") ;
    if (debugenv != NULL)
        ase.debuglevel = atoi (debugenv) ;

    ase.pid = getpid () ;

    return clock_gettime (CLOCK_MONOTONIC, &ase.debut) ;
}

/**
 * @brief Affiche (ou non) un message de debug
 *
 * Cette fonction utilise la variable d'environnement DEBUG_ASE pour
 * décider si le message doit être affiché ou non. Si le niveau
 * demandé pour ce message est inférieur ou égal au niveau de la
 * variable d'environnement, le message est affiché, sinon il est
 * ignoré.
 * 
 * @param level niveau demandé pour ce message
 * @param format chaîne de format comme pour printf
 * @param ... les arguments de la chaîne de format (comme avec printf)
 * @result aucun résultat
 */

void
adebug (int level, const char *format, ...)
{
    va_list ap;

    if (level <= ase.debuglevel)        // afficher si niveau msg <= niveau var
    {
        struct timespec h ;             // horodatage du message
        int s, ns ;                     // nb de secondes, de nanosecondes

        if (clock_gettime (CLOCK_MONOTONIC, &h) != -1)
        {
            s = h.tv_sec - ase.debut.tv_sec ;
            ns = h.tv_nsec - ase.debut.tv_nsec ;
            if (ns < 0)
            {
                ns += 1000*1000*1000 ;  // ajouter un milliard de nanosecondes
                s -= 1 ;
            }
        }
        else                            // erreur de clock_gettime :
        {
            s = 999 ;                   // on affiche des valeurs incohérentes
            ns = 999000000 ;
        }

        va_start (ap, format) ;
        fprintf (stdout, "%s %d (%d.%03d): ", ase.prog, ase.pid,
                                                s, ns / (1000*1000)) ;
        vfprintf (stdout, format, ap) ;
        fprintf (stdout, "\n") ;
        va_end (ap) ;
        fflush (stdout) ;
    }
}

/*
 * Fonctions utilisées pour afficher les synchronisations
 */

#define OKERR(var)      ((var != -1) ? "ok" : "err")

/**
 * @brief remplace sem_init
 *
 * @param s asem_t à initialiser
 * @param nom nom à attribuer au sémaphore
 * @param pshared voir sem_init
 * @param val voir sem_init
 * @result voir sem_init
 */

int
asem_init (asem_t *s, const char *nom, int pshared, unsigned int val)
{
    int r ;
    strncpy (s->nom, nom, MAX_NOMSEM) ;
    s->nom [MAX_NOMSEM] = '\0' ;
    r = sem_init (& s->sem, pshared, val) ;
    adebug (DBG_SYNC, "init sem %s (%u) %s", nom, val, OKERR(r)) ;
    return r ;
}

/**
 * @brief remplace sem_destroy
 *
 * @param s asem_t à supprimer
 * @result voir sem_init
 */

int
asem_destroy (asem_t *s)
{
    int r ;
    r = sem_destroy (& s->sem) ;
    adebug (DBG_SYNC, "destroy sem %s %s", s->nom, OKERR(r)) ;
    strcpy (s->nom, "(supprime)") ;     // détecter les utilisations erronées
    return r ;
}

/**
 * @brief remplace sem_wait
 *
 * @param s asem_t à utiliser
 * @result voir sem_wait
 */

int
asem_wait (asem_t *s)
{
    int r ;
    adebug (DBG_SYNC, "P(%s) avant", s->nom) ;
    r = sem_wait (& s->sem) ;
    adebug (DBG_SYNC, "P(%s) %s", s->nom, OKERR(r)) ;
    return r ;
}

/**
 * @brief remplace sem_post
 *
 * @param s asem_t à utiliser
 * @result voir sem_post
 */

int
asem_post (asem_t *s)
{
    int r ;
    adebug (DBG_SYNC, "V(%s) avant", s->nom) ;
    r = sem_post (& s->sem) ;
    adebug (DBG_SYNC, "V(%s) %s", s->nom, OKERR(r)) ;
    return r ;
}

/**
 * @brief remplace sem_trywait
 *
 * @param s asem_t à utiliser
 * @result voir sem_trywait
 */

int
asem_trywait (asem_t *s)
{
    int r ;
    adebug (DBG_SYNC, "Ptry(%s) avant", s->nom) ;
    r = sem_trywait (& s->sem) ;
    adebug (DBG_SYNC, "Ptry(%s) %s", s->nom, OKERR(r)) ;
    return r ;
}

#if !defined(__APPLE__)                 // MacOS n'a pas sem_timedwait
/**
 * @brief remplace sem_timedwait
 *
 * Note : cette fontion n'est pas disponible sur MacOS car sem_timedwait
 * ne l'est pas.
 *
 * @param s asem_t à utiliser
 * @param abstimeout voir sem_timedwait
 * @result voir sem_timewait
 */

int
asem_timedwait (asem_t *s, const struct timespec *abstimeout)
{
    int r ;
    adebug (DBG_SYNC, "Ptimed(%s) avant", s->nom) ;
    r = sem_timedwait (& s->sem, abstimeout) ;
    adebug (DBG_SYNC, "Ptimed(%s) %s", s->nom, OKERR(r)) ;
    return r ;
}
#endif

/**
 * @brief remplace sem_getvalue
 *
 * @param s asem_t à utiliser
 * @param sval voir sem_getvalue
 * @result voir sem_getvalue
 */

int
asem_getvalue (asem_t *s, int *sval)
{
    int r ;
    r = sem_getvalue (& s->sem, sval) ;
    adebug (DBG_SYNC, "getval(%s): %d %s", s->nom, *sval, OKERR(r)) ;
    return r ;
}
