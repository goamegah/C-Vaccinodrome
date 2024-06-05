#!/bin/sh

#
# Test de saturation du nombre de médecins
#

. ./ftest.sh

ATT=1           # nb de sièges dans la salle d'attente
MED=40          # un nombre arbitrairement grand de médecins
TVAX=0          # durée de vaccination

# Nettoyer pour éviter des suprises
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage préalable"

# Ouvrir le vaccinodrome
./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1  || fail "Erreur à l'ouverture"

# Lancer les médecins
PID_M=""
for i in $(seq $MED)
do
    ./medecin > $TMP.m$i 2>&1 &
    PID_M="$PID_M $!"
done
PID_M=$!

# Laisser aux premiers médecins le temps de démarrer
msleep $MARGE

# Vérifier que tous les médecins sont toujours là
for pid in $PID_M
do
    ps_existe $pid "Médecin $i devrait toujours être là"
done

# On lance un patient pour vérifier que tout continue à fonctionner
./patient X > $TMP.p1 2>&1 &
PID_P=$!

msleep $MARGE
ps_termine $PID_P "Patient X non terminé"
wait $PID_P                     || fail "Patient X terminé en erreur"

# Vérifier qu'on ne peut pas dépasser le nombre de médecins prévu
./medecin > $TMP.msupp 2>&1 &
PID_MS=$!

msleep $MARGE
ps_termine $PID_MS "Médecin supplémentaire devrait être terminé"
wait $PID_MS                    && fail "Médecin suppl n'a pas détecté d'erreur"

# On lance un autre patient pour vérifier que tout continue à fonctionner
./patient Y > $TMP.p1 2>&1 &
PID_P=$!

msleep $MARGE
ps_termine $PID_P "Patient Y non terminé"
wait $PID_P                     || fail "Patient Y terminé en erreur"

# Fermer le vaccinodrome. Pas vu grand-monde aujourd'hui...
./fermer > $TMP.f 2>&1 &
PID_F=$!

msleep $MARGE
ps_termine $PID_F "fermer aurait dû se terminer"
wait $PID_F                     || fail "Erreur à la fermeture"

# Vérifier que tous les médecins sont terminés
for pid in $PID_M
do
    ps_termine $pid "Médecin $i devrait être terminé"
    wait $pid                   || fail "Erreur medecin $pid"
done

# On laisse tout bien propre à la fin
./nettoyer > $TMP.n 2>&1        || fail "Erreur au nettoyage final"

logs_aux
echo "ok"
exit 0
