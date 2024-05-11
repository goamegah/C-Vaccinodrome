#
# Fonctions et variables auxiliaires utilisées pour les différents
# tests.
#
# Conseil : si vous voulez exécuter "à la main" les différentes
# commandes contenues dans les fichiers test-*.sh, faites :
#       . ./ftest.sh
# pour inclure les fonctions ci-après, puis exécutez les commandes
# de test-*.sh au clavier.
#
# Si vous avez des problèmes de durée d'exécution dûs à une machine
# lente, changez la valeur de la variable d'environnement MARGE
# dans votre shell. Par exemple :
#       MARGE=60 make test
# ou :
#       export MARGE=60
#       make test
# Ne modifiez rien ici. Ce script sera exécuté sur turing.
#

MARGE=${MARGE:-30}      # en ms : devrait suffire pour des machines rapides

TEST=$(basename $0 .sh)

TMP=/tmp/$TEST-$$
LOG=$TEST.log

DEBUG_ASE=${DEBUG_ASE:-1}     # récupérer DEBUG_ASE si la variable existe
export DEBUG_ASE

# Rediriger stderr vers le log pour récupérer les résultats des tests
# On conserve stdout inchangé, il faudra le rediriger à la demande
exec 2> $LOG            # à commenter si vous utilisez ". ./ftest.sh"

# pour le log
echo "============================================================" >&2
echo "==> commandes exécutées" >&2

set -u                  # erreur si utilisation d'une variable non définie

###############################################################################
# Ajouter les fichiers de log auxiliaires dans le fichier de log principal

logs_aux ()
{
    set +x
    (
        for f in $(ls -d /tmp/* | grep "^$TMP")
        do
            echo "============================================================"
            echo "==> Fichier de log auxiliaire $f"
            cat $f
        done
        rm -f $TMP $TMP.*
        if islinux
        then
            echo "============================================================"
            echo "==> /dev/shm"
            ls /dev/shm
        fi
    ) >&2
}

###############################################################################
# Une fonction qu'il vaudrait mieux ne pas avoir à appeler...

fail ()
{
    set +x
    echo "==> Échec du test '$TEST' sur '$1'."
    echo "==> Échec du test '$TEST' sur '$1'." >&2

    # Terminer tous les processus qu'on voit dans les variables "PID_*"
    listepid=$(set | grep '^PID_' | sed -e "s/.*='//" -e "s/'$//")
    kill -HUP $listepid 2>/dev/null # certains peuvent être absents

    echo "==> Voir détails dans le fichier $LOG"
    logs_aux
    echo "==> Exit"
    exit 1
}

###############################################################################
# Certains tests ne sont disponibles que sur Linux

islinux ()
{
    [ x"$(uname)" = xLinux ]
}

###############################################################################
# Conversion ms -> s
# Pratique pour tout gérer en ms dans les scripts de test

mstos ()
{
    [ $# != 1 ] && echo "ERREUR SYNTAXE mstos"
    local ms="$1"
    echo "scale=5;$ms/1000" | bc
}

###############################################################################
# Sleep en millisecondes. On suppose que la commande "sleep" accepte
# des nombres flottants, ce qui n'est pas POSIX (argh...) mais qui
# est vrai sur beaucoup de systèmes.

msleep ()
{
    [ $# != 1 ] && echo "ERREUR SYNTAXE msleep"
    local ms="$1"
    sleep $(mstos $ms)
}

###############################################################################
# Teste si le processus existe

ps_teste_un ()
{
    [ $# != 1 ] && echo "ERREUR SYNTAXE ps_test"
    local pid="$1"
    kill -0 $pid 2> /dev/null
}

###############################################################################
# Renvoie le nombre de processus toujours vivants dans la liste fournie

ps_teste_liste ()
{
    local n=0 pid
    for pid
    do
        if kill -0 $pid 2> /dev/null
        then n=$((n+1))
        fi
    done
    echo $n
}

###############################################################################
# Teste si le processus existe toujours, sinon signale l'erreur

ps_existe ()
{
    [ $# != 2 ] && echo "ERREUR SYNTAXE ps_existe"
    local pid="$1" msg="$2"
    kill -0 $pid 2> /dev/null || fail "$msg"
}

###############################################################################
# Teste si le processus est bien terminé, sinon signale l'erreur

ps_termine ()
{
    [ $# != 2 ] && echo "ERREUR SYNTAXE ps_termine"
    local pid="$1" msg="$2"
    kill -0 $pid 2> /dev/null && fail "$msg"
}

###############################################################################
# La commande "seq" pour les systèmes qui ne l'ont pas

myseq ()
{
    local max="$1"
    local i=1

    while [ $i -leq $max ]
    do
        echo $i 
        i=$((i+1))
    done
}

seq ()
{
    [ $# != 1 ] && echo "ERREUR SYNTAXE myseq"
    local max="$1"
    local i=1
    command seq $max 2> /dev/null || myseq $max
}

#
# Le script timeout.sh nous envoie le signal SIGALRM en cas de délai dépassé
# Attention : il peut rester des processus lancés en avant-plan et
# qui restent donc bloqués ("fail" ne peut les terminer car leur pid
# n'est pas mémorisé dans une variable PID_xxxx).
#
trap "date >&2 ; fail 'timeout dépassé'" ALRM

set -x                  # mode trace
