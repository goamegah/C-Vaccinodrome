#!/bin/sh

#
# Teste l'absence d'appels à sem_* dans le code source (qui doit être
# dans le répertoire courant)
# Vérifie également que le patient n'essaye pas d'attendre la durée
# demandée.
#

. ./ftest.sh

#
# Explorer les sources (qui doivent être dans le répertoire courant)
# pour détecter l'apparition des fonctions sem_*
#

SRCS="ouvrir.c fermer.c medecin.c patient.c nettoyer.c shm.h shm.c"
for src in $SRCS
do
    [ -f $src ]                         || fail "Fichier $src non trouvé"
    grep '[^a]sem_' $src >&2            && fail "$src : appel à sem_"
done

grep 'sleep' patient.c >&2              && fail "sleep dans patient.c"
grep 'time' patient.c >&2               && fail "time dans patient.c"

logs_aux
echo "ok"
exit 0


