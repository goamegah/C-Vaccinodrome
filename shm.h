/**
 * @file shm.h
 * @author godwin AMEGAH (komlan.godwin.amegah@gmail.com)
 * @brief 
 * @version 0.1
 * @date 2022-01-23
 * 
 * @copyright Copyright (c) 2022
 * 
 */

#ifndef SHM_H
#define SHM_H

#include "asem.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h> /* For mode constants */
#include <fcntl.h>
#include <stdbool.h>
#include <errno.h>
#include <ctype.h>
#include <unistd.h>
#include <time.h>

// renommage des types
typedef struct vaccinodrome vaccinodrome_t;
typedef struct siege siege_t;
typedef struct box box_t;
typedef struct maShm maShm_t;

// Macro vérifiant un invariant, et arrête le programme s'il n'est pas vérifié
#define ASSERT(what, message)                     \
	do                                            \
	{                                             \
		if (!(what))                              \
		{                                         \
			if (errno != 0)                       \
				perror(message);                  \
			else                                  \
				fprintf(stderr, "%s\n", message); \
			exit(EXIT_FAILURE);                   \
		}                                         \
	} while (0)

// Macro pour gérer les erreurs des appels systèmes
#define CHECK(expr) ASSERT((int)(expr) != -1, #expr)

// Macro pour gérer les erreurs des mécanismes de synchronisation
#define P(ps) CHECK(asem_wait(&(ps)))
#define V(ps) CHECK(asem_post(&(ps)))

// constante pour corrompre la mémoire 
#define CORRUPT -1

#define MAX_NOM 10
#define VAX_NAME "/pass_sanitaire"

// definition de type pour le nom des patients
typedef struct
{
	char nom[MAX_NOM + 1];
} nom_t;

// Macro pour initialiser des noms comme des coquilles vides
#define nom_factice           \
	(nom_t)                   \
	{                         \
		.nom = { [0] = '\0' } \
	}

// Macro pour tester les coquilles vides
#define nom_estfactice(pn) ((pn)->nom[0] == '\0')

/******************************************************************************
 * definition des structures composant ma structure de memoire partagée
 */

struct vaccinodrome
{
	size_t n;		   // Constante fixant le nombre de sièges
	size_t m;		   // Constante fixant le nombre de box
	struct timespec t; // Constante fixant le temps d’une vaccination
	asem_t sglibres;   // Quantité de sièges libres
	asem_t sgoccupes;  // Quantité de sièges occupés
	asem_t attente;	   // Verrou d’accès à l’entrée de la salle d’attente
	bool ouvert;	   // Indique si le vaccinodrome est ouvert
	size_t sgsuiv;	   // Indice du premier siège libre
	size_t bxsuiv;	   // Indice du premier box libre
	asem_t service;	   // Verrou d’accès à la sortie de la salle d’attente
	size_t sgprem;	   // Indice du premier siège occupé
};

struct siege
{
	nom_t patient;	  // Nom du patient assis s’il existe, sinon nom vide
	asem_t mp_entrez; // Message (du médecin) pour passage dans un box
	size_t box;		  // Indice du box, valide à réception du message
};

struct box
{
	asem_t pm_piquez; // Message (du patient) quand il est prêt dans le box
	asem_t mp_partez; // Message (du médecin) quand le patient peut partir
};

/*
 * Fin de la gestion des structures de contenu dans ma structure de vaccination
 *****************************************************************************/
void *attacher(void);
void supprimer(void);
void detacher(void *ma, size_t tailleSegment);
void clean(void *addr);
bool isMaShmOpen(void) ;
#endif