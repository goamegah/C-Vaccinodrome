/**
 * @file nettoyer.c
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
	(void)argv;

	a = ainit("debut du programme nettoyer");
	ASSERT(a != -1, "ainit failed/nettoyer");

	adebug(2, "### début programme");

	if (argc >= 2)
	{
		fprintf(stderr, "usage: nettoyer : 1 arg\n");
		exit(EXIT_FAILURE);
	}

	if (isMaShmOpen())
	{
		void *ma = attacher(); // appelle mmap ()
		ASSERT(ma != MAP_FAILED, "mmap failed/main");

		vaccinodrome_t *ctl = ma;
		size_t tailleSegment = sizeof(vaccinodrome_t) + ctl->n * sizeof(siege_t) + ctl->m * sizeof(box_t);

		// nettoyer les restes (semaphores...) d'un précedent vaccinodrome.
		clean(ma);

		// 
		detacher(ma, tailleSegment);

		// supprimer la memoire partagée
		supprimer();

		// On a fini de nettoyer, on peut quitter ce programme !
		adebug(2, "### fin programme");
	}

	return EXIT_SUCCESS;
}
