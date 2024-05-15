/**
 * @file shm.c
 * @author godwin AMEGAH (komlan.godwin.amegah@gmail.com)
 * @brief 
 * @version 0.1
 * @date 2022-01-23
 * 
 * @copyright Copyright (c) 2022
 * 
 */
#include "shm.h"

/**
 * @brief 
 * 
 * @param ma 
 * @return ** void 
 */
void clean(void *ma)
{
	adebug(2, "### début fonction clean");

	vaccinodrome_t *ctl = ma;
	siege_t *sgs = (siege_t *)(ctl + 1);
	box_t *bxs = (box_t *)(sgs + ctl->n);

	CHECK(asem_destroy(&ctl->sglibres));
	CHECK(asem_destroy(&ctl->sgoccupes));
	CHECK(asem_destroy(&ctl->attente));
	CHECK(asem_destroy(&ctl->service));

	for (size_t s = 0; s < ctl->n; s++)
	{
		CHECK(asem_destroy(&sgs[s].mp_entrez));
	}

	for (size_t b = 0; b < ctl->m; b++)
	{
		CHECK(asem_destroy(&bxs[b].pm_piquez));
		CHECK(asem_destroy(&bxs[b].mp_partez));
	}

	adebug(2, "### fin fonction clean");
}

/**
 * @brief 
 * 
 * @return ** void* 
 */
void *attacher(void)
{
	int fd;
	size_t tailleSegment;
	struct stat sst;

	fd = shm_open(VAX_NAME, O_EXCL | O_RDWR, 0600);
	ASSERT(fd != -1, "Erreur! mémoire inexistant!");
	CHECK(fstat(fd, &sst));

	tailleSegment = sst.st_size;

	void *ma = mmap(NULL, tailleSegment, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

	return ma;
}

/**
 * @brief 
 * 
 * @return ** void 
 */
void supprimer(void)
{
	CHECK(shm_unlink(VAX_NAME));
}

/**
 * @brief 
 * 
 * @param ma 
 * @param tailleSegment 
 * @return ** void 
 */
void detacher(void *ma, size_t tailleSegment)
{
	CHECK(munmap(ma, tailleSegment));
}

/**
 * @brief 
 * 
 * @return true 
 * @return false 
 */
bool isMaShmOpen(void)
{
	int fd;
	fd = shm_open(VAX_NAME, O_EXCL | O_RDWR, 0600);

	return (fd != -1) ? true : false;
}