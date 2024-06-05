#!/bin/sh

#
# Détection d'un test trop long (interblocage ou autre blocage)
#

TIMEOUT=20              # en sec : aucun test ne devrait durer autant

if [ $# != 1 ]
then
    echo "usage: $0 <script-de-test>" >&2
    exit 1
fi
TEST="$1"

# Se noter un rappel pour dans $TIMEOUT secondes
(
    sleep $TIMEOUT &            # lancer sleep en arrière-plan
    PID_SLEEP=$!
    # Si le sous-shell est terminé prématurément, cela signifie
    # que le script de test s'est terminé avant le timeout.
    # Dans ce cas, nettoyer le "sleep" en attente
    trap "kill $PID_SLEEP 2> /dev/null ; exit 0" HUP
    wait                        # attendre la fin du sleep
    # Si on arrive là, c'est que sleep s'est terminé, donc que
    # le timeout est expiré. Envoyer le signal SIGALRM au
    # shell père (celui qui a lancé ce sous-shell).
    kill -ALRM $$               # papa, c'est l'heure !
) &
PID_SUBSH=$!

sh "$TEST" &
PID_TEST=$!

MSG="Timeout dépassé. Attention, il peut rester des processus bloqués."
# Si on reçoit le signal de rappel envoyé par le sous-shell sleep,
# on le transmet au script de test
trap "echo '$MSG' >&2 ; ps -t t$(tty) >&2 ; kill -ALRM $PID_TEST ; exit 1" ALRM

# Attendre le script de test, à moins qu'on soit réveillé par SIGALRM
wait $PID_TEST
EXITCODE=$?

# On laisse l'endroit bien propre en sortant : on nettoie le "sleep"
# dont on n'a plus besoin d'attendre la fin.
kill -HUP $PID_SUBSH 2> /dev/null
wait $PID_SUBSH

exit $EXITCODE
