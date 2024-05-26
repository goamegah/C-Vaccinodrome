#!/bin/sh

#
# Tests basiques de vérification des arguments
#

. ./ftest.sh

# Teste la présence du traditionnel message : "usage: prog arg..." dans $TMP
# Renvoie vrai si trouvé, faux si pas trouvé
tu ()
{
    # Rappel: "! cmd" => inverse le code de retour de cmd
    ! grep -q "usage: " $TMP
}

###############################################################################
# Tests d'arguments invalides
# (on attend un message d'erreur du type "usage: ..." pour être sûr
# que le problème de syntaxe est bien détecté)
#
# Note : tu = "test usage", défini dans ftest.sh => teste si la chaîne
#       "usage: " est envoyée sur la sortie d'erreur standard

./ouvrir 1 2            2> $TMP >&2 || tu && fail "ouvrir : 2 args"
./ouvrir 1 2 3 4        2> $TMP >&2 || tu && fail "ouvrir : 4 args"
./ouvrir -1 1 1         2> $TMP >&2 || tu && fail "ouvrir : n=-1"
./ouvrir  0 1 1         2> $TMP >&2 || tu && fail "ouvrir : n=0"
./ouvrir 1 -1 1         2> $TMP >&2 || tu && fail "ouvrir : m=-1"
./ouvrir 1  0 1         2> $TMP >&2 || tu && fail "ouvrir : m=0"
./ouvrir 1 1 -1         2> $TMP >&2 || tu && fail "ouvrir : t=-1"

./fermer 1              2> $TMP >&2 || tu && fail "fermer : 1 arg"

./nettoyer 1            2> $TMP >&2 || tu && fail "nettoyer : 1 arg"

./medecin 1             2> $TMP >&2 || tu && fail "medecin : 1 arg"

./patient               2> $TMP >&2 || tu && fail "patient : 0 arg"
./patient 1 2           2> $TMP >&2 || tu && fail "patient : 2 arg"
./patient ""            2> $TMP >&2 || tu && fail "patient : nom vide"
./patient ABCDEFGHIJK   2> $TMP >&2 || tu && fail "patient : nom = 11 octets"

# nettoyer ne devrait pas générer d'erreur s'il n'y a rien à supprimer
./nettoyer                      || fail "échec nettoyer"

# Ces programmes nécessitent que le vaccinodrome soit ouvert et doivent
# donc générer une erreur
./fermer > $TMP 2>&1            && fail "fermer devrait signaler une erreur"
./medecin > $TMP 2>&1           && fail "medecin devrait signaler une erreur"
./patient toto > $TMP 2>&1      && fail "patient devrait signaler une erreur"

logs_aux
echo "ok"
exit 0
