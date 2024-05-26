/**
 * @file medecin.c
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
	int a, fd;
	struct stat sst;
	size_t tailleSegment, siege, box;
	nom_t patient;

	(void)argv; // pas d'argument requis

	a = ainit("debut du programme medecin");
	ASSERT(a != -1, "ainit failed/medecin");

	// tests du nombre d'argument
	if (argc > 1)
	{
		fprintf(stderr, "usage: medecin : 1 arg\n");
		fflush(stdout);
		return EXIT_FAILURE;
	}

	adebug(2, "démarrage programme");

	fd = shm_open(VAX_NAME, O_EXCL | O_RDWR, 0600);
	ASSERT(fd != -1, "medecin devrait signaler une erreur");
	CHECK(fstat(fd, &sst));

	tailleSegment = sst.st_size;

	void *ma = mmap(NULL, tailleSegment, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	ASSERT(ma != MAP_FAILED, "mmap failed/main");

	// Les processus qui attachent le segment de mémoire partagée utilisent trois pointeurs pour accéder à son contenu. Voici leur initialisation :
	// C’est le seul endroit où l’on utilise l’arithmétique des pointeurs.
	vaccinodrome_t *ctl = ma;
	siege_t *sgs = (siege_t *)(ctl + 1);
	box_t *bxs = (box_t *)(sgs + ctl->n);

	// Arrivée d’un médecin
	P(ctl->attente); // M1: <-
	if (!ctl->ouvert || ctl->bxsuiv == ctl->m)
	{
		V(ctl->attente);
		return EXIT_FAILURE;
	}

	else
	{
		box = ctl->bxsuiv++;
		V(ctl->attente);
	}

	// debut de l' interactions entre patients et médecins
	while (true) // M2: <-
	{
		P(ctl->sgoccupes); // M3: <-
		P(ctl->service);
		siege = ctl->sgprem++;
		ctl->sgprem %= ctl->n;
		patient = sgs[siege].patient;
		sgs[siege].box = box;
		sgs[siege].patient = nom_factice;

		if (nom_estfactice(&patient) /* patient factice */) // M4: <-
		{
			V(ctl->service);
			V(ctl->sglibres);
			V(sgs[siege].mp_entrez);
			break;
		}

		else
		{
			V(sgs[siege].mp_entrez);
			P(bxs[box].pm_piquez);
			V(ctl->service);
			V(ctl->sglibres);
			// medecin box vaccine patient
			fprintf(stdout, "medecin %zu vaccine %s\n", box, patient.nom);
			fflush(stdout);
			nanosleep(&ctl->t, NULL);
			V(bxs[box].mp_partez);
		}
	}

	// Le médecin est parti.. On peut quitter ce programme !
	adebug(2, "arrêt programme");

	return EXIT_SUCCESS;
}
