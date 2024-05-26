/**
 * @file fermer.c
 * @author godwin AMEGAH (komlan.godwin.amegah@gmail.com)
 * @brief 
 * @version 0.1
 * @date 2022-01-23
 * 
 * @copyright Copyright (c) 2022
 * 
 */
#include "shm.h"

int main(int argc, char *argv[])
{
	int a;
	size_t siege, medecins, tailleSegment;

	(void)argv;

	a = ainit("debut du programme fermer");
	ASSERT(a != -1, "ainit failed/fermer");

	adebug(2, "démarrage programme");

	if (argc > 1)
	{
		fprintf(stderr, "usage: fermer : 1 arg\n");
		exit(EXIT_FAILURE);
	}

	/* Debut de fermeture du vaccinodrome */

	void *ma = attacher(); // appelle mmap ()
	ASSERT(ma != MAP_FAILED, "mmap failed/main");

	// Les processus qui attachent le segment de mémoire partagée utilisent trois pointeurs pour accéder à son contenu. Voici leur initialisation :
	// C’est le seul endroit où l’on utilise l’arithmétique des pointeurs.

	vaccinodrome_t *ctl = ma;
	siege_t *sgs = (siege_t *)(ctl + 1);
	tailleSegment = sizeof(vaccinodrome_t) + ctl->n * sizeof(siege_t) + ctl->m * sizeof(box_t);

	supprimer(); // appelle shm_unlink ()
	P(ctl->attente);
	ctl->ouvert = 0;
	medecins = ctl->bxsuiv;
	V(ctl->attente);

	if (medecins == 0)
	{
		P(ctl->service); // F1: <-
		while (!nom_estfactice(&sgs[ctl->sgprem].patient))
		{
			P(ctl->sgoccupes);
			siege = ctl->sgprem++;
			ctl->sgprem %= ctl->n;
			sgs[siege].box = ctl->m;
			V(sgs[siege].mp_entrez);
			sgs[siege].patient = nom_factice;
			V(ctl->sglibres);
		}
		V(ctl->service);
	}
	else
	{
		for (size_t i = 0; i < medecins; i++) // F2: <-
		{
			P(ctl->sglibres);
			P(ctl->attente);
			siege = ctl->sgsuiv++;
			ctl->sgsuiv %= ctl->n;
			sgs[siege].patient = nom_factice;
			V(ctl->attente);
			V(ctl->sgoccupes);
			P(sgs[siege].mp_entrez);
		}
	}
	detacher(ma, tailleSegment); // appelle munmap ()

	return EXIT_SUCCESS;
}
