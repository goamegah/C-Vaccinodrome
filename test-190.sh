#!/bin/sh

#
# Test de saturation de la salle d'attente, tous les patients
# sont pris en charge. La fermeture intervient après que tous
# les patients aient été vaccinés.
#

. ./ftest.sh

ATT=6           # nb de sièges dans la salle d'attente
MED=2           # un nombre arbitrairement grand de médecins
TVAX=$((MARGE*20))      # durée de vaccination

EXT=10          # nb de patients qui vont attendre à l'extérieur

# Nettoyer pour éviter des suprises
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage préalable"

# Ouvrir le vaccinodrome
./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1  || fail "Erreur à l'ouverture"

# Les patients sont déjà là !
NPAT=$((ATT+EXT))               # nb de patients

PID_P=""
for i in $(seq $NPAT)
do
    ./patient $i > $TMP.p$i 2>&1 &
    PID_P="$PID_P $!"
done

# Le médecin arrive (il n'y en a qu'un)
./medecin > $TMP.m 2>&1 &
PID_M=$!

msleep $MARGE

# Vérifier que les patients se terminent un par un à la date fixée
T=$MARGE
while [ $NPAT -ge 0 ]
do
    N=$(ps_teste_liste $PID_P)
    if [ $N != $NPAT ]
    then fail "Reste $N patients non terminés sur $NPAT attendus à $T ms"
    fi
    NPAT=$((NPAT-1))
    T=$((T+TVAX))
    msleep $TVAX
done

# Vérifier que les différents patients se sont bien terminés
for pid in $PID_P
do
    wait $pid                   || fail "Patient $pid terminé avec erreur"
done

# Le médecin doit toujours être présent
ps_existe $PID_M "Médecin devrait toujours être là"

# Fermer le vaccinodrome. Pfiou, quelle journée !
./fermer > $TMP.f 2>&1 &
PID_F=$!

msleep $MARGE
ps_termine $PID_F "fermer aurait dû se terminer"
wait $PID_F                             || fail "Erreur à la fermeture"

ps_termine $PID_M "medecin devrait être terminé"
wait $PID_M                             || fail "Erreur medecin"

# On laisse tout bien propre à la fin
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage final"

logs_aux
echo "ok"
exit 0
