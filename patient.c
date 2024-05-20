/**
 * @file patient.c
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
	nom_t nom;

	// TODO: init du programme débug
	a = ainit("debut du programme ouvrir");
	ASSERT(a != -1, "ainit failed/ouvrir");

	adebug(2, "démarrage programme");

	// tests du nombre d'argument
	if (argc == 1)
	{
		fprintf(stderr, "usage: patient : 0 arg");
		exit(1);
	}

	if (argc == 3)
	{
		fprintf(stderr, "usage: patient : 2 arg");
		exit(1);
	}

	if (strlen(argv[1]) == 0)
	{
		fprintf(stderr, "usage: patient : nom vide");
		exit(1);
	}

	if (strlen(argv[1]) >= MAX_NOM + 1)
	{
		fprintf(stderr, "usage: patient : nom = 11 octets");
		exit(1);
	}

	strcpy(nom.nom, argv[1]);

	fd = shm_open(VAX_NAME, O_EXCL | O_RDWR, 0600);
	ASSERT(fd != -1, "patient devrait signaler une erreur");
	CHECK(fstat(fd, &sst));

	tailleSegment = sst.st_size;

	void *ma = mmap(NULL, tailleSegment, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	ASSERT(ma != MAP_FAILED, "mmap failed/main");

	// Les processus qui attachent le segment de mémoire partagée utilisent trois pointeurs pour accéder à son contenu. Voici leur initialisation :
	// C’est le seul endroit où l’on utilise l’arithmétique des pointeurs.
	vaccinodrome_t *ctl = ma;
	siege_t *sgs = (siege_t *)(ctl + 1);
	box_t *bxs = (box_t *)(sgs + ctl->n);

	// Arrivée d'un patient
	P(ctl->sglibres); // P1: <-
	P(ctl->attente);
	if (!ctl->ouvert)
	{
		V(ctl->attente);
		V(ctl->sglibres);
		return EXIT_FAILURE;
	}

	else
	{
		siege = ctl->sgsuiv++;
		ctl->sgsuiv %= ctl->n;
		sgs[siege].patient = nom; // P2: <-
		V(ctl->attente);
		// patient nom siege siege
		fprintf(stdout, "patient %s siege %zu\n", nom.nom, siege);
		fflush(stdout);
		V(ctl->sgoccupes); // P3: <-
	}

	// debut de l' interactions entre patients et médecins
	P(sgs[siege].mp_entrez); // P4: <-
	box = sgs[siege].box;

	if (box == ctl->m /* expulsion */)
	{
		return EXIT_FAILURE;
	}
	else
	{
		// patient nom medecin box
		fprintf(stdout, "patient %s medecin %zu\n", nom.nom, box);
		fflush(stdout);
		V(bxs[box].pm_piquez);
		P(bxs[box].mp_partez);
		return EXIT_SUCCESS;
	}

	// Le patient est vaccinée, on peut quitter ce programme !
	adebug(2, "arrêt programme");
	return EXIT_SUCCESS;
}
