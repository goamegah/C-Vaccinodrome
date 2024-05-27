#!/bin/sh

#
# Teste l'utilisation des fonctions de asem.c
#

. ./ftest.sh

ATT=1                   # nb de sièges dans la salle d'attente
MED=1                   # nb de médecins
TVAX=100                # 0,1 s pour une vaccination, c'est du rapide

# Lance un test simple mais complet, pour essayer avec DEBUG_ASE
run ()
{
    # Nettoyer pour éviter des suprises
    ./nettoyer > $TMP.n 2>&1            || fail "Erreur au nettoyage préalable"

    # Ouvrir le vaccinodrome
    ./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1 || fail "Erreur à l'ouverture"

    # Lancer un médecin
    ./medecin > $TMP.m 2>&1 &
    PID_M=$!

    # Laisser au médecin le temps de démarrer
    msleep $MARGE

    # Un patient arrive
    ./patient toto > $TMP.p 2>&1 &
    PID_P=$!

    msleep $MARGE

    ps_existe $PID_P "patient devrait toujours être là"

    msleep $TVAX

    ps_termine $PID_P "patient ne devrait plus être là"
    ps_existe $PID_M "médecin devrait toujours être là"

    # Fermer le vaccinodrome
    ./fermer > $TMP.f 2>&1 &
    PID_F=$!

    # Laisser le temps de terminer
    msleep $MARGE

    ps_termine $PID_M "medecin aurait dû se terminer"
    wait $PID_M                         || fail "Erreur du médecin"

    ps_termine $PID_F "fermer aurait dû se terminer"
    wait $PID_F                         || fail "Erreur à la fermeture"

    # On laisse tout bien propre à la fin
    ./nettoyer > $TMP.n 2>&1            || fail "Erreur au nettoyage final"

}

# renvoie "vrai" si on détecte le motif utilisé par asem
detecter_asem ()
{
    grep -q -E "(ouvrir|fermer|nettoyer|medecin|patient) [0-9][0-9]* \([0-9]*\.[0-9]*\): (init sem|P|V).*ok"
}

#
# Première tentative : on ne doit pas repérer l'utilisation de asem.c
#

DEBUG_ASE=
export DEBUG_ASE
run

cat $TMP.* | detecter_asem      && fail "asem.c utilisé avec DEBUG_ASE vide"

#
# Deuxième tentative : on doit repérer l'utilisation de asem.c
#

DEBUG_ASE=1
export DEBUG_ASE
run

detecter_asem < $TMP.o                  || fail "asem.c pas utilisé par ouvrir"
detecter_asem < $TMP.m                  || fail "asem.c pas utilisé par medecin"
detecter_asem < $TMP.p                  || fail "asem.c pas utilisé par patient"
detecter_asem < $TMP.f                  || fail "asem.c pas utilisé par fermer"

logs_aux
echo "ok"
exit 0


