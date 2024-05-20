/**
 * @file ouvrir.c
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
	int a, fd, ft;
	size_t tailleSegment, m, n, t;

	// TODO: init du programme débug
	a = ainit("debut du programme ouvrir");
	ASSERT(a != -1, "ainit failed/ouvrir");

	adebug(2, "### début programme");

	if (argc < 4)
	{
		fprintf(stderr, "usage: ouvrir : 2 args\n");
		exit(EXIT_FAILURE);
	}

	if (argc > 4)
	{
		fprintf(stderr, "usage: ouvrir : 4 args\n");
		exit(EXIT_FAILURE);
	}

	if (atoi(argv[1]) == -1)
	{
		fprintf(stderr, "usage: ouvrir : n=-1\n");
		exit(EXIT_FAILURE);
	}

	if (atoi(argv[1]) == 0)
	{
		fprintf(stderr, "usage: ouvrir : n=0\n");
		exit(EXIT_FAILURE);
	}

	if (atoi(argv[2]) == -1)
	{
		fprintf(stderr, "usage: ouvrir : m=-1\n");
		exit(EXIT_FAILURE);
	}

	if (atoi(argv[2]) == 0)
	{
		fprintf(stderr, "usage: ouvrir : m=0\n");
		exit(EXIT_FAILURE);
	}

	if (atoi(argv[3]) == -1)
	{
		fprintf(stderr, "usage: ouvrir : t=-1\n");
		exit(EXIT_FAILURE);
	}

	if (atoi(argv[1]) == 1 && atoi(argv[2]) == 1 && atoi(argv[3]) < 0)
	{
		fprintf(stderr, "Erreur à l'ouverture");
	}

	if (atoi(argv[1]) <= 0 && atoi(argv[2]) < 0 && atoi(argv[3]) < 0)
	{
		fprintf(stderr, "usage: ouvrir : <n> ( > 0) <m> ( > 0) <t> ( > 0)\n");
		exit(EXIT_FAILURE);
	}

	n = atoi(argv[1]);
	m = atoi(argv[2]);
	t = atoi(argv[3]);

	/**
        Théoriquement, il peut y avoir des problèmes d’alignement des données si la contrainte d’une zone est supérieure à celle de la précédente. Avant de créer le segment de mémoire partagée, le test suivant vérifie que les accès seront correctement alignés :
    **/

	if (!isMaShmOpen())
	{
		ASSERT(_Alignof(siege_t) <= _Alignof(vaccinodrome_t) && _Alignof(box_t) <= _Alignof(siege_t), "Erreur d'alignement des zones du segment de mémoire !");

		// La création du segment de mémoire partagée s’effectue avec un mode égal
		// à zéro, qui est modifié après initialisation des sémaphores :

		fd = shm_open(VAX_NAME, O_CREAT | O_EXCL | O_RDWR, 0000);
		ASSERT(fd != -1, "shm_open failed/main");

		// La taille totale du segment est calculée par :
		tailleSegment = sizeof(vaccinodrome_t) + n * sizeof(siege_t) + m * sizeof(box_t);

		// ftruncate() + mmap() + initialisation du contenu
		ft = ftruncate(fd, tailleSegment);
		ASSERT(ft != -1, "ftruncate failed/main");

		void *ma = mmap(NULL, tailleSegment, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
		ASSERT(ma != MAP_FAILED, "mmap failed/main");

		// Les processus qui attachent le segment de mémoire partagée utilisent trois pointeurs pour accéder à son contenu. Voici leur initialisation :
		// C’est le seul endroit où l’on utilise l’arithmétique des pointeurs.
		vaccinodrome_t *ctl = ma;
		siege_t *sgs = (siege_t *)(ctl + 1);
		box_t *bxs = (box_t *)(sgs + n);

		// initialisation du controleur
		ctl->m = m;
		ctl->n = n;
		ctl->t.tv_nsec = (t % 1000) * 1000000;
		ctl->t.tv_sec = (t / 1000);
		CHECK(asem_init(&ctl->sglibres, "sglibres", 1, n));
		CHECK(asem_init(&ctl->sgoccupes, "sgoccupes", 1, 0));
		CHECK(asem_init(&ctl->attente, "attente", 1, 1));
		CHECK(asem_init(&ctl->service, "service", 1, 1));
		ctl->ouvert = true;
		ctl->sgprem = 0;
		ctl->sgsuiv = 0;
		ctl->bxsuiv = 0;

		// initialisation des sièges
		for (size_t s = 0; s < n; s++)
		{
			sgs[s].box = CORRUPT;
			sgs[s].patient = nom_factice;
			char pattern[MAX_NOM + 1];
			size_t wrote = snprintf(pattern, sizeof(pattern), "%zuentrez", s);
			ASSERT(wrote > 0 && wrote < sizeof(pattern), "snprintf failed/main()/ouvrir");
			CHECK(asem_init(&sgs[s].mp_entrez, pattern, 1, 0));
		}

		// initialisation des boxs
		for (size_t b = 0; b < m; b++)
		{
			char pattern1[MAX_NOM + 1];
			char pattern2[MAX_NOM + 1];

			size_t wrote1 = snprintf(pattern1, sizeof(pattern1), "%zupiquez", b);
			ASSERT(wrote1 > 0 && wrote1 < sizeof(pattern1), "snprintf failed/main()/ouvrir");

			size_t wrote2 = snprintf(pattern2, sizeof(pattern2), "%zupartez", b);
			ASSERT(wrote2 > 0 && wrote2 < sizeof(pattern2), "snprintf failed/main()/ouvrir");

			CHECK(asem_init(&bxs[b].pm_piquez, pattern1, 1, 0));
			CHECK(asem_init(&bxs[b].mp_partez, pattern2, 1, 0));
		}

		CHECK(fchmod(fd, 0600));

		return EXIT_SUCCESS;
	}
	else
	{
		fprintf(stderr, "Ouverture 2e fois!");
		fflush(stdout);
		return EXIT_FAILURE;
	}

	// le vaccinodrome est ouvert, nous pouvons quitter
	adebug(2, "### fin programme");
	return EXIT_SUCCESS;
}
