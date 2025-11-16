#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "ERREUR: Ce script necessite les droits root"
    echo "Utiliser: sudo ./install_systemd.sh"
    exit 1
fi

echo "Installation du service resistant avec systemd"
echo ""

echo "[1/5] Compilation du daemon"
gcc -Wall -O2 -o resistant_daemon resistant_daemon.c
if [ $? -ne 0 ]; then
    echo "ERREUR: Compilation echouee"
    exit 1
fi
echo "OK: Daemon compile"
echo ""

echo "[2/5] Installation du binaire"
cp resistant_daemon /usr/local/bin/resistant_daemon
chmod +x /usr/local/bin/resistant_daemon
echo "OK: Binaire installe dans /usr/local/bin/"
echo ""

echo "[3/5] Installation du service systemd"
cp resistant.service /etc/systemd/system/resistant.service
chmod 644 /etc/systemd/system/resistant.service
echo "OK: Service installe dans /etc/systemd/system/"
echo ""

echo "[4/5] Rechargement de systemd"
systemctl daemon-reload
echo "OK: systemd recharge"
echo ""

echo "[5/5] Activation du service"
systemctl enable resistant.service
echo "OK: Service active au demarrage"
echo ""

echo "Installation terminee!"
echo ""
echo "Commandes utiles:"
echo "  sudo systemctl start resistant     # Demarrer"
echo "  sudo systemctl stop resistant      # Arreter"
echo "  sudo systemctl status resistant    # Statut"
echo "  sudo systemctl restart resistant   # Redemarrer"
echo "  sudo journalctl -u resistant -f    # Voir logs en temps reel"
echo "  tail -f /var/log/resistant.log     # Logs du daemon"
echo ""

