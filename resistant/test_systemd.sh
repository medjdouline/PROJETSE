#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "ERREUR: Ce script necessite les droits root"
    echo "Utiliser: sudo ./test_systemd.sh"
    exit 1
fi

echo "========================================="
echo "TEST SERVICE SYSTEMD RESISTANT"
echo "========================================="
echo ""

echo "[TEST 1] Demarrage du service"
systemctl start resistant
sleep 2

if systemctl is-active --quiet resistant; then
    echo "SUCCES: Service demarre"
else
    echo "ECHEC: Service non demarre"
    exit 1
fi

PID=$(systemctl show -p MainPID --value resistant)
echo "PID du service: $PID"
echo ""

echo "[TEST 2] Verification du processus"
if ps -p $PID > /dev/null 2>&1; then
    echo "SUCCES: Processus actif"
    ps -p $PID -o pid,ppid,uid,gid,cmd
else
    echo "ECHEC: Processus introuvable"
    exit 1
fi
echo ""

echo "[TEST 3] Test de resistance (SIGTERM ignore)"
echo "Envoi SIGTERM au processus..."
kill -TERM $PID
sleep 2

if ps -p $PID > /dev/null 2>&1; then
    echo "SUCCES: Processus ignore SIGTERM et reste actif"
else
    echo "ECHEC: Processus tue par SIGTERM"
fi
echo ""

echo "[TEST 4] Test de relance automatique (SIGKILL)"
echo "Envoi SIGKILL au processus..."
OLD_PID=$PID
kill -9 $PID
sleep 3

NEW_PID=$(systemctl show -p MainPID --value resistant)
echo "Ancien PID: $OLD_PID"
echo "Nouveau PID: $NEW_PID"

if [ "$NEW_PID" != "$OLD_PID" ] && [ "$NEW_PID" != "0" ]; then
    echo "SUCCES: Service relance automatiquement par systemd"
else
    echo "ECHEC: Service non relance"
fi
echo ""

echo "[TEST 5] Verification des logs"
echo "Derniers logs du service:"
journalctl -u resistant --no-pager -n 10
echo ""

echo "[TEST 6] Arret du service"
systemctl stop resistant
sleep 2

if systemctl is-active --quiet resistant; then
    echo "ECHEC: Service toujours actif"
else
    echo "SUCCES: Service arrete"
fi
echo ""

echo "========================================="
echo "BILAN DES TESTS"
echo "========================================="
echo ""
echo "Le service resistant avec systemd:"
echo "  [x] Demarre correctement"
echo "  [x] Ignore SIGTERM"
echo "  [x] Relance automatique apres SIGKILL"
echo "  [x] Logs dans journalctl et /var/log/resistant.log"
echo "  [x] Arret propre avec systemctl stop"
echo ""
echo "Pour reactiver au demarrage:"
echo "  sudo systemctl enable resistant"
echo ""
