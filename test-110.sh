#!/bin/sh

#
# Test d'une session minimale : ouvrir et fermer, vérifier les
# segments de mémoire partagée (sur Linux uniquement).
#

. ./ftest.sh

ATT=1                   # nb de sièges dans la salle d'attente
MED=1                   # nb de médecins
TVAX=0                  # durée de vaccination

# Nettoyer pour éviter des suprises
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage préalable"

# Prendre une photo des segments de mémoire partagée avant
if islinux
then
    ls /dev/shm > $TMP.m1
    (echo "État initial des shm" ; cat $TMP.m1) >&2
else
    echo "Attention : test partiel. Utilisez Linux pour le test complet"
fi

# Ouvrir le vaccinodrome
./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1  || fail "Erreur à l'ouverture"

msleep $MARGE

# Normalement, on nse devrait pas retrouver les mêmes segments
if islinux
then
    ls /dev/shm > $TMP.m2
    (echo "État des shm après ouverture" ; cat $TMP.m2) >&2
    cmp -s $TMP.m1 $TMP.m2 && fail "ouvrir : 'ls /dev/shm' identique"
fi

# Une nouvelle ouverture devrait échouer
./ouvrir 10 10 $TVAX > $TMP.o2 2>&1     && fail "Ouverture 2e fois"

# Fermer le vaccinodrome. Pas vu grand-monde aujourd'hui...
./fermer > $TMP.f 2>&1 &
PID_F=$!

msleep $MARGE
ps_termine $PID_F "fermer aurait dû se terminer"
wait $PID_F                             || fail "Erreur à la fermeture"

# On devrait retrouver les mêmes segments de mémoire partagée qu'au début
if islinux
then
    ls /dev/shm > $TMP.m3
    (echo "État final des shm" ; cat $TMP.m3) >&2
    cmp -s $TMP.m1 $TMP.m3 || fail "fermer : /dev/shm pas dans l'état initial"
fi


# On laisse tout bien propre à la fin
./nettoyer > $TMP 2>&1                  || fail "Erreur au nettoyage final"

logs_aux
echo "ok"
exit 0
