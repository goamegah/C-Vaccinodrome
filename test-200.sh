#!/bin/sh

#
# Test de saturation de la salle d'attente. La fermeture intervient alors
# qu'il reste des patients à l'extérieur : ils doivent être refoulés.
#

. ./ftest.sh

ATT=6           # nb de sièges dans la salle d'attente
MED=2           # un nombre arbitrairement grand de médecins
TVAX=$((MARGE*20))      # durée de vaccination

EXT=10          # nb de patients qui vont attendre à l'extérieur...
REFOULES=2      # ... dont certains qui seront refoulés

# Nettoyer pour éviter des suprises
./nettoyer > $TMP.n 2>&1                || fail "Erreur au nettoyage préalable"

# Ouvrir le vaccinodrome
./ouvrir $ATT $MED $TVAX > $TMP.o 2>&1  || fail "Erreur à l'ouverture"

# Les patients sont déjà là !
PAT=$((ATT+EXT))                # nb de patients

PID_P=""
for i in $(seq $PAT)
do
    ./patient $i > $TMP.p$i 2>&1 &
    PID_P="$PID_P $!"
done

# Le médecin arrive (il n'y en a qu'un)
./medecin > $TMP.m 2>&1 &
PID_M=$!

msleep $MARGE

# Vérifier que les patients se terminent un par un à la date fixée
#       à t0 + 30 ms : reste 16 patients (1 en vax, 6 en att, 9 à l'ext)
#       à t0 + 630 ms : reste 15 patients (1 en vax, 6 en att, 8 à l'ext)
#       à t0 + 1230 ms : reste 14 patients (1 en vax, 6 en att, 7 à l'ext)
#       ....
#       à t0 + 4230 ms : reste 9 patients (1 en vax, 6 en att, 2 à l'ext)
#       => fermeture
#       à t0 + 4830 ms : reste 6 patients (1 en vax, 5 en att, 0 à l'ext)
#       => un nouveau patient se présente => échec
#       
T=$MARGE
while [ $PAT -ge 0 ]
do
    N=$(ps_teste_liste $PID_P)
    if [ $N != $PAT ]
    then fail "Reste $N patients non terminés sur $PAT attendus à $T ms"
    fi

    # On ferme le vaccinodrome alors qu'il reste 2 patients à l'extérieur
    if [ $N = $((1+ATT+REFOULES)) ]
    then
        # Fermer le vaccinodrome. Pfiou, quelle journée !
        ./fermer > $TMP.f 2>&1 &
        PID_F=$!
        # Tenir compte des patients refoulés
        PAT=$((PAT-REFOULES))
    fi

    # Un nouveau patient se présente après la fermeture
    if [ $N = $((1+ATT-1)) ]            # explicitation du calcul
    then
        ./patient X > $TMP.pX 2>&1 &
        PID_PX=$!
    elif [ $N = $((1+ATT-1-1)) ]
    then
        ps_termine $PID_PX "Patient X arrivé après fermeture non terminé"
        # normalement, le patient refoulé doit détecter une erreur
        wait $PID_PX                    && fail "Patient X refoulé sans erreur"
    fi


    PAT=$((PAT-1))
    T=$((T+TVAX))
    msleep $TVAX
done

# Vérifier que les patients vaccinés se sont bien terminés
# mais que ceux qui ont été refoulés à l'extérieur ont déclaré
# une erreur (et ont bien maugréé)
NOK=0
for pid in $PID_P
do
    if wait $pid
    then NOK=$((NOK+1))
    fi
done
if [ $NOK != $((ATT+EXT-REFOULES)) ]
then
    fail "Les patients refoulés auraient dû se terminer en erreur (nok=$NOK)"
fi

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
