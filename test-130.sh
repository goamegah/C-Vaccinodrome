#!/bin/sh

#
# Test d'une session basique : un médecin et un patient
#

. ./ftest.sh

ATT=1                   # nb de sièges dans la salle d'attente
MED=1                   # nb de médecins
TVAX=200                # durée de vaccination : 200 ms, c'est du rapide

# Nettoyer pour éviter des suprises
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage préalable"

# Ouvrir le vaccinodrome
./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1  || fail "Erreur à l'ouverture"

# Lancer un médecin
./medecin > $TMP.m 2>&1 &
PID_M=$!

# Un patient arrive
./patient toto > $TMP.p 2>&1 &
PID_P=$!

msleep $MARGE

ps_existe $PID_P "patient devrait toujours être là"

msleep $TVAX

ps_termine $PID_P "patient ne devrait plus être là"
ps_existe $PID_M "médecin devrait toujours être là"

# Fermer le vaccinodrome. Pas vu grand-monde aujourd'hui...
./fermer > $TMP.f 2>&1 &
PID_F=$!

# Laisser le temps de terminer
msleep $MARGE

ps_termine $PID_M "medecin aurait dû se terminer"
wait $PID_M                             || fail "Erreur du médecin"

ps_termine $PID_F "fermer aurait dû se terminer"
wait $PID_F                             || fail "Erreur à la fermeture"

# On laisse tout bien propre à la fin
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage final"

logs_aux
echo "ok"
exit 0
