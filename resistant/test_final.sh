#!/bin/bash

echo "========================================="
echo "TEST COMPLET DU PROJET"
echo "========================================="
echo ""

# ====================
# PARTIE 1: COMPILATION
# ====================
echo "[PARTIE 1] Compilation de tous les composants"
echo ""

# Compilation affichage
echo "1.1 - Compilation de affichage.c"
cd ~/PROJETSE/proc
gcc -o affichage affichage.c 2>&1
if [ -f "affichage" ]; then
    echo "    SUCCES: affichage compile"
else
    echo "    ECHEC: affichage non compile"
    exit 1
fi
echo ""

# Compilation resistant
echo "1.2 - Compilation de resistant.c"
cd ~/PROJETSE/resistant
make clean > /dev/null 2>&1
make > /dev/null 2>&1
if [ -f "resistant" ]; then
    echo "    SUCCES: resistant compile"
else
    echo "    ECHEC: resistant non compile"
    exit 1
fi
echo ""

# Compilation libhook
echo "1.3 - Compilation de libhook.so"
cd ~/PROJETSE/invisible
make clean > /dev/null 2>&1
make > /dev/null 2>&1
if [ -f "libhook.so" ]; then
    echo "    SUCCES: libhook.so compile"
else
    echo "    ECHEC: libhook.so non compile"
    exit 1
fi
echo ""

# ====================
# PARTIE 2: TEST AFFICHAGE PCB
# ====================
echo "[PARTIE 2] Test du processus affichage (PCB)"
echo ""

cd ~/PROJETSE/proc
./affichage &
AFFICHAGE_PID=$!
sleep 1

echo "2.1 - Verification du lancement"
if kill -0 $AFFICHAGE_PID 2>/dev/null; then
    echo "    SUCCES: Processus affichage lance (PID: $AFFICHAGE_PID)"
else
    echo "    ECHEC: Processus affichage non lance"
    exit 1
fi
echo ""

echo "2.2 - Verification des attributs PCB dans /proc"
if [ -f "/proc/$AFFICHAGE_PID/status" ]; then
    echo "    PID: $AFFICHAGE_PID"
    echo "    PPID: $(grep PPid /proc/$AFFICHAGE_PID/status | awk '{print $2}')"
    echo "    UID: $(grep Uid /proc/$AFFICHAGE_PID/status | awk '{print $2}')"
    echo "    GID: $(grep Gid /proc/$AFFICHAGE_PID/status | awk '{print $2}')"
    echo "    SUCCES: Attributs PCB accessibles"
else
    echo "    ECHEC: Impossible de lire /proc/$AFFICHAGE_PID/status"
fi
echo ""

# Nettoyage
kill $AFFICHAGE_PID 2>/dev/null
wait $AFFICHAGE_PID 2>/dev/null

# ====================
# PARTIE 3: TEST INVISIBILITE
# ====================
echo "[PARTIE 3] Test de l'invisibilite (LD_PRELOAD)"
echo ""

cd ~/PROJETSE/proc
./affichage &
AFFICHAGE_PID=$!
sleep 1

echo "3.1 - Test SANS LD_PRELOAD (doit etre VISIBLE)"
VISIBLE=$(ps aux | grep affichage | grep -v grep | wc -l)
if [ $VISIBLE -gt 0 ]; then
    echo "    SUCCES: Processus VISIBLE sans LD_PRELOAD ($VISIBLE occurence(s))"
    ps aux | grep affichage | grep -v grep | head -1 | awk '{print "    ", $0}'
else
    echo "    ECHEC: Processus INVISIBLE sans LD_PRELOAD"
fi
echo ""

echo "3.2 - Test AVEC LD_PRELOAD (doit etre INVISIBLE)"
cd ~/PROJETSE/invisible
HIDDEN=$(LD_PRELOAD=./libhook.so ps aux | grep affichage | grep -v grep | wc -l)
if [ $HIDDEN -eq 0 ]; then
    echo "    SUCCES: Processus INVISIBLE avec LD_PRELOAD"
else
    echo "    ECHEC: Processus toujours VISIBLE avec LD_PRELOAD ($HIDDEN occurence(s))"
    LD_PRELOAD=./libhook.so ps aux | grep affichage | grep -v grep | head -1 | awk '{print "    ", $0}'
fi
echo ""

echo "3.3 - Test avec pgrep"
PGREP_NORMAL=$(pgrep affichage | wc -l)
PGREP_HIDDEN=$(LD_PRELOAD=./libhook.so pgrep affichage | wc -l)
echo "    Sans LD_PRELOAD: $PGREP_NORMAL processus trouve(s)"
echo "    Avec LD_PRELOAD: $PGREP_HIDDEN processus trouve(s)"
if [ $PGREP_NORMAL -gt 0 ] && [ $PGREP_HIDDEN -eq 0 ]; then
    echo "    SUCCES: pgrep filtre correctement"
else
    echo "    ECHEC: pgrep ne filtre pas correctement"
fi
echo ""

echo "3.4 - Test /proc/[PID] (doit toujours exister physiquement)"
if [ -d "/proc/$AFFICHAGE_PID" ]; then
    echo "    SUCCES: /proc/$AFFICHAGE_PID existe toujours (comportement attendu)"
    echo "    Note: LD_PRELOAD cache seulement la lecture de /proc, pas le filesystem"
else
    echo "    ANOMALIE: /proc/$AFFICHAGE_PID n'existe pas"
fi
echo ""

# Nettoyage
kill $AFFICHAGE_PID 2>/dev/null
wait $AFFICHAGE_PID 2>/dev/null

# ====================
# PARTIE 4: TEST RESISTANCE
# ====================
echo "[PARTIE 4] Test de la resistance (auto-relance)"
echo ""

cd ~/PROJETSE/resistant
./resistant > /tmp/resistant_output.log 2>&1 &
RESISTANT_PARENT=$!
sleep 3

echo "4.1 - Verification du lancement"
RESISTANT_CHILD=$(pgrep -P $RESISTANT_PARENT)
if [ -n "$RESISTANT_CHILD" ]; then
    echo "    SUCCES: Processus parent lance (PID: $RESISTANT_PARENT)"
    echo "    SUCCES: Processus enfant lance (PID: $RESISTANT_CHILD)"
else
    echo "    ECHEC: Processus resistant non lance correctement"
    kill $RESISTANT_PARENT 2>/dev/null
    exit 1
fi
echo ""

echo "4.2 - Test de resistance aux signaux (SIGTERM ignore)"
echo "    Envoi SIGTERM a l'enfant (PID: $RESISTANT_CHILD)..."
kill -TERM $RESISTANT_CHILD 2>/dev/null
sleep 2

STILL_ALIVE=$(pgrep -P $RESISTANT_PARENT)
if [ -n "$STILL_ALIVE" ] && [ "$STILL_ALIVE" = "$RESISTANT_CHILD" ]; then
    echo "    SUCCES: Enfant ignore SIGTERM et reste vivant (PID: $STILL_ALIVE)"
else
    echo "    ECHEC: Enfant a ete tue par SIGTERM (devrait ignorer)"
fi
echo ""

echo "4.3 - Test de resistance (kill -9 enfant)"
CURRENT_CHILD=$(pgrep -P $RESISTANT_PARENT)
if [ -n "$CURRENT_CHILD" ]; then
    echo "    Envoi SIGKILL a l'enfant (PID: $CURRENT_CHILD)..."
    kill -9 $CURRENT_CHILD 2>/dev/null
    sleep 4
    
    RELAUNCHED_CHILD=$(pgrep -P $RESISTANT_PARENT)
    if [ -n "$RELAUNCHED_CHILD" ] && [ "$RELAUNCHED_CHILD" != "$CURRENT_CHILD" ]; then
        echo "    SUCCES: Enfant relance meme avec SIGKILL (nouveau PID: $RELAUNCHED_CHILD)"
    else
        echo "    ECHEC: Enfant non relance apres SIGKILL"
    fi
fi
echo ""

echo "4.4 - Verification du fichier de controle"
if [ -f "/tmp/.resistant_ctrl" ]; then
    echo "    SUCCES: Fichier de controle existe (/tmp/.resistant_ctrl)"
    CTRL_PID=$(cat /tmp/.resistant_ctrl)
    echo "    PID dans fichier: $CTRL_PID"
else
    echo "    ECHEC: Fichier de controle absent"
fi
echo ""

echo "4.5 - Test d'arret propre"
echo "    Suppression du fichier de controle..."
rm -f /tmp/.resistant_ctrl
sleep 3

if ps -p $RESISTANT_PARENT > /dev/null 2>&1; then
    echo "    ECHEC: Parent toujours actif apres suppression du fichier"
    kill -9 $RESISTANT_PARENT 2>/dev/null
else
    echo "    SUCCES: Parent arrete proprement"
fi

if pgrep -f "resistant" > /dev/null 2>&1; then
    echo "    ECHEC: Des processus resistant sont toujours actifs"
    pkill -9 -f resistant
else
    echo "    SUCCES: Tous les processus resistant sont arretes"
fi
echo ""

# ====================
# PARTIE 5: TEST COMBINE
# ====================
echo "[PARTIE 5] Test combine (resistant + invisible)"
echo ""

echo "5.1 - Lancement du processus resistant"
cd ~/PROJETSE/resistant
./resistant > /tmp/resistant_output.log 2>&1 &
RESISTANT_PARENT=$!
sleep 3
RESISTANT_CHILD=$(pgrep -P $RESISTANT_PARENT)
echo "    Parent PID: $RESISTANT_PARENT"
echo "    Enfant PID: $RESISTANT_CHILD"
echo ""

echo "5.2 - Test d'invisibilite sur le processus resistant"
echo "    Sans LD_PRELOAD:"
VISIBLE_PARENT=$(ps aux | grep $RESISTANT_PARENT | grep -v grep | wc -l)
VISIBLE_CHILD=$(ps aux | grep $RESISTANT_CHILD | grep -v grep | wc -l)
echo "        Parent visible: $VISIBLE_PARENT"
echo "        Enfant visible: $VISIBLE_CHILD"

echo "    Avec LD_PRELOAD (note: resistant != affichage, donc visible):"
cd ~/PROJETSE/invisible
HIDDEN_PARENT=$(LD_PRELOAD=./libhook.so ps aux | grep $RESISTANT_PARENT | grep -v grep | wc -l)
HIDDEN_CHILD=$(LD_PRELOAD=./libhook.so ps aux | grep $RESISTANT_CHILD | grep -v grep | wc -l)
echo "        Parent visible: $HIDDEN_PARENT"
echo "        Enfant visible: $HIDDEN_CHILD"
echo "        Note: LD_PRELOAD filtre uniquement 'affichage', pas 'resistant'"
echo ""

echo "5.3 - Nettoyage"
rm -f /tmp/.resistant_ctrl
sleep 2
pkill -9 -f resistant 2>/dev/null
echo "    SUCCES: Nettoyage termine"
echo ""

# ====================
# BILAN FINAL
# ====================
echo "========================================="
echo "BILAN FINAL"
echo "========================================="
echo ""
echo "Tests effectues:"
echo "  [x] Compilation de tous les composants"
echo "  [x] Affichage des attributs PCB"
echo "  [x] Invisibilite avec LD_PRELOAD"
echo "  [x] Resistance avec relance automatique"
echo "  [x] Test combine"
echo ""
echo "Fichiers generes:"
echo "  - ~/PROJETSE/proc/affichage"
echo "  - ~/PROJETSE/resistant/resistant"
echo "  - ~/PROJETSE/invisible/libhook.so"
echo ""
echo "Pour nettoyer:"
echo "  cd ~/PROJETSE/resistant && make clean"
echo "  cd ~/PROJETSE/invisible && make clean"
echo "  rm -f /tmp/.resistant_* ~/PROJETSE/proc/affichage"
echo ""
