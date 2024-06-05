#!/bin/sh

#
# Vérifier que les médecins prennent bien les patients en parallèle
# Deux tests en un :
# - le premier en lançant les médecins en premier
# - le premier en lançant les patients en premier
#

. ./ftest.sh

ATT=8                   # nb de sièges dans la salle d'attente
MED=4                   # nb de médecins
TVAX=200                # durée de vaccination : 200 ms, c'est du rapide
PAT=$ATT                # nb de patients (pas plus que le nb de sièges)

# Lancer les médecins en parallèle
lancer_medecins ()
{
    local i

    # Lancer les médecins
    PID_M=""
    for i in $(seq $MED)
    do
        ./medecin > $TMP.m$i 2>&1 &
        PID_M="$PID_M $!"
    done

    # Attendre que les médecins aient démarré
    msleep $MARGE
}

# Lancer les patients en parallèle
lancer_patients ()
{
    local i

    # Lancer les patients
    PID_P=""
    for i in $(seq $PAT)
    do
        ./patient P$i > $TMP.p$i 2>&1 &
        PID_P="$PID_P $!"
    done

    # Attendre que les patients aient démarré
    msleep $MARGE
}

# Lancer le test complet, avec l'argument "medecins" ou "patients"
run ()
{
    local premier="$1"

    # Nettoyer pour éviter des suprises
    ./nettoyer > $TMP.n 2>&1            || fail "Erreur au nettoyage préalable"

    # Ouvrir le vaccinodrome
    ./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1 || fail "Erreur à l'ouverture"

    if [ $premier = "medecins" ]
    then
        lancer_medecins
        lancer_patients
    else
        lancer_patients
        lancer_medecins
    fi

    # Tout le monde doit toujours être là
    N=$(ps_teste_liste $PID_P $PID_M)
    O=$((MED + PAT))
    [ $N = $O ]                         || fail "Il manque du monde ($N/$O)"

    # Calculer le temps théorique
    OT=$(( (PAT + MED-1) / MED ))
    msleep $((OT * TVAX))

    # Tous les patients doivent être sortis
    N=$(ps_teste_liste $PID_P)
    [ $N = 0 ]                          || fail "Il reste des patients !"

    # Vérifier qu'ils se sont bien terminés
    for pid in $PID_P
    do
        wait $pid                       || fail "Patient $pid mal terminé"
    done

    # Les médecins devraient toujours être là
    N=$(ps_teste_liste $PID_M)
    [ $N = $MED ]                       || fail "Il manque des médecins"

    # On ferme ! Quelle journée !
    ./fermer > $TMP.f 2>&1 &
    PID_F=$!

    # Laisser le temps de terminer
    msleep $MARGE

    # Vérifier la fermeture
    for pid in $PID_M
    do
        ps_termine $pid "Médecin $pid ne devrait plus être là"
        wait $pid                       || fail "Médecin $pid terminé en erreur"
    done

    ps_termine $PID_F "fermer aurait dû se terminer"
    wait $PID_F                         || fail "Erreur à la fermeture"

    # On laisse tout bien propre à la fin
    ./nettoyer > $TMP.n 2>&1            || fail "Erreur au nettoyage final"
}

# Premier test : lancer les médecins en premier
run medecins

# Deuxième test : lancer les patients en premier
run patients

logs_aux
echo "ok"
exit 0
