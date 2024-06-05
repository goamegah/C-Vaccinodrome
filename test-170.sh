#!/bin/sh

#
# Vérifier que les médecins connaissent le nom de chaque patient,
# et que chaque patient affiche le numéro du siège en salle
# d'attente et le numéro du médecin qui l'a pris en charge.
#
# Pour cela, les médecins doivent générer des affichages (stricts) :
#       medecin X vaccine Y
# et les patients doivent générer des affichages (stricts eux aussi) :
#       patient Y siege Z
#       patient Y medecin X
# Ne pas oublier d'utiliser "fflush(stdout)" pour forcer l'écriture
# notamment si la sortie standard est redirigée.
#
# La base de ce test reprend le test précédent
#

. ./ftest.sh

MED=4                   # nb de médecins
ATT=$((MED*2))          # nb de sièges dans la salle d'attente (2 fois MED)
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

# Lancer le test (peu importe qui démarre en premier)
run patients

#
# Exploiter les résultats
#

# obtenir la liste de référence des patients
for i in $(seq $PAT)
do
    echo P$i
done | sort > $TMP.lpref
# obtenir la liste de référence des médecins
for i in $(seq $MED)
do
    echo $((i-1))               # numéro de médecin : 0 ... m-1
    echo $((i-1))               # chaque médecin doit vacciner 2 patients
done | sort > $TMP.lmref
# obtenir la liste de référence des sièges
for i in $(seq $ATT)
do
    echo $((i-1))               # numéro de siège : 0 ... n-1
done | sort > $TMP.lsref

# récupérer la liste des patients vaccinés par tous les médecins
cat $TMP.m* \
    | sed -n 's/^medecin \([0-9]*\) vaccine \(P[0-9]*\)/\2/p' \
    | sort \
    > $TMP.lp
# comparer avec la liste de référence des patients vaccinés
diff $TMP.lpref $TMP.lp >&2             || fail "Patients identifiés par des médecins"

# récupérer la liste des médecins ayant vacciné
cat $TMP.m* \
    | sed -n 's/^medecin \([0-9]*\) vaccine \(P[0-9]*\)/\1/p' \
    | sort \
    > $TMP.lm
# comparer avec la liste de référence des médecins
diff $TMP.lmref $TMP.lm >&2             || fail "Liste des médecins ayant vacciné"

# tous les sièges de la salle d'attente ont-ils bien été utilisés ?
cat $TMP.p* \
    | sed -n 's/^patient \(P[0-9]*\) siege \([0-9]*\)/\2/p' \
    | sort \
    > $TMP.ls
# comparer avec la liste de référence des sièges
diff $TMP.lsref $TMP.ls >&2             || fail "Liste des sièges occupés"

# récupérer la liste des médecins ayant vacciné tous les patients
cat $TMP.p* \
    | sed -n 's/^patient \(P[0-9]*\) medecin \([0-9]*\)/\2/p' \
    | sort \
    > $TMP.lm2
# comparer avec la liste de référence des médecins
diff $TMP.lmref $TMP.lm2 >&2            || fail "Médecins identifiés par les patients"

# récupérer la liste des patients s'étant présentés
cat $TMP.p* \
    | sed -n 's/^patient \(P[0-9]*\) medecin \([0-9]*\)/\1/p' \
    | sort \
    > $TMP.lp2
# comparer avec la liste de référence des patients
diff $TMP.lpref $TMP.lp2 >&2            || fail "Patients s'étant présentés"

logs_aux
echo "ok"
exit 0
