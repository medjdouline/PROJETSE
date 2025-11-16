#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test d'Invisibilité de Processus     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

# Étape 1: Lancer le processus
echo -e "${YELLOW}[1] Lancement du processus affichage...${NC}"
cd ../proc
./affichage &
PID=$!
echo -e "${GREEN}✓ Processus lancé avec PID: $PID${NC}\n"
sleep 2

# Étape 2: Tests AVANT rootkit
echo -e "${BLUE}═══ AVANT ROOTKIT (processus doit être VISIBLE) ═══${NC}\n"

echo -e "${YELLOW}Test 1: ps aux${NC}"
if ps aux | grep -v grep | grep "affichage" > /dev/null; then
    echo -e "${GREEN}✓ VISIBLE dans ps aux${NC}"
    ps aux | grep affichage | grep -v grep | head -1
else
    echo -e "${RED}✗ NON visible${NC}"
fi
echo ""

echo -e "${YELLOW}Test 2: ps -p $PID${NC}"
if ps -p $PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ VISIBLE avec ps -p${NC}"
    ps -p $PID
else
    echo -e "${RED}✗ NON visible${NC}"
fi
echo ""

echo -e "${YELLOW}Test 3: ls /proc/$PID${NC}"
if ls /proc/$PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ VISIBLE dans /proc${NC}"
    ls -la /proc/$PID | head -3
else
    echo -e "${RED}✗ NON visible${NC}"
fi
echo ""

echo -e "${YELLOW}Test 4: pgrep affichage${NC}"
if pgrep affichage > /dev/null; then
    echo -e "${GREEN}✓ VISIBLE pour pgrep${NC}"
    echo "PIDs trouvés: $(pgrep affichage)"
else
    echo -e "${RED}✗ NON visible${NC}"
fi
echo ""

echo -e "${YELLOW}Test 5: top (snapshot)${NC}"
if top -b -n 1 | grep affichage > /dev/null; then
    echo -e "${GREEN}✓ VISIBLE dans top${NC}"
    top -b -n 1 | grep affichage | head -1
else
    echo -e "${RED}✗ NON visible${NC}"
fi
echo -e "\n"

# Étape 3: Charger le rootkit
echo -e "${YELLOW}[2] Compilation et chargement du rootkit...${NC}"
cd ../invisible
make clean > /dev/null 2>&1
make
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Erreur de compilation!${NC}"
    kill $PID
    exit 1
fi
echo -e "${GREEN}✓ Compilation réussie${NC}"

sudo insmod rootkit.ko target_name="affichage"
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Erreur de chargement!${NC}"
    echo "Logs kernel:"
    sudo dmesg | tail -10
    kill $PID
    exit 1
fi
echo -e "${GREEN}✓ Rootkit chargé${NC}"
sleep 2
echo -e "\n${YELLOW}Messages kernel:${NC}"
sudo dmesg | grep rootkit | tail -5
echo -e "\n"

# Étape 4: Tests APRÈS rootkit
echo -e "${BLUE}═══ APRÈS ROOTKIT (processus doit être INVISIBLE) ═══${NC}\n"

echo -e "${YELLOW}Test 1: ps aux${NC}"
if ps aux | grep -v grep | grep "affichage" > /dev/null; then
    echo -e "${RED}✗ ENCORE VISIBLE dans ps aux${NC}"
    ps aux | grep affichage | grep -v grep | head -1
else
    echo -e "${GREEN}✓ INVISIBLE dans ps aux${NC}"
fi
echo ""

echo -e "${YELLOW}Test 2: ps -p $PID${NC}"
if ps -p $PID > /dev/null 2>&1; then
    echo -e "${RED}✗ ENCORE VISIBLE avec ps -p${NC}"
    ps -p $PID
else
    echo -e "${GREEN}✓ INVISIBLE pour ps -p${NC}"
fi
echo ""

echo -e "${YELLOW}Test 3: ls /proc/$PID${NC}"
if ls /proc/$PID > /dev/null 2>&1; then
    echo -e "${RED}✗ ENCORE VISIBLE dans /proc${NC}"
else
    echo -e "${GREEN}✓ INVISIBLE dans /proc${NC}"
fi
echo ""

echo -e "${YELLOW}Test 4: pgrep affichage${NC}"
if pgrep affichage > /dev/null; then
    echo -e "${RED}✗ ENCORE trouvé par pgrep${NC}"
    echo "PIDs trouvés: $(pgrep affichage)"
else
    echo -e "${GREEN}✓ INVISIBLE pour pgrep${NC}"
fi
echo ""

echo -e "${YELLOW}Test 5: top (snapshot)${NC}"
if top -b -n 1 | grep affichage > /dev/null; then
    echo -e "${RED}✗ ENCORE VISIBLE dans top${NC}"
    top -b -n 1 | grep affichage | head -1
else
    echo -e "${GREEN}✓ INVISIBLE dans top${NC}"
fi
echo ""

echo -e "${YELLOW}Test 6: htop (si installé)${NC}"
if command -v htop &> /dev/null; then
    echo "htop nécessite une interface, teste manuellement"
else
    echo "htop non installé"
fi
echo -e "\n"

# Vérification finale
echo -e "${BLUE}═══ VÉRIFICATION FINALE ═══${NC}\n"
echo -e "${YELLOW}Le processus tourne-t-il toujours?${NC}"
if kill -0 $PID 2>/dev/null; then
    echo -e "${GREEN}✓ OUI, le processus est actif${NC}"
    echo "  (même s'il est invisible, il fonctionne)"
else
    echo -e "${RED}✗ Le processus s'est arrêté${NC}"
fi
echo ""

echo -e "${YELLOW}Module visible dans lsmod?${NC}"
if lsmod | grep rootkit > /dev/null; then
    echo -e "${RED}✗ Module VISIBLE dans lsmod${NC}"
    lsmod | grep rootkit
else
    echo -e "${GREEN}✓ Module INVISIBLE (auto-masqué)${NC}"
fi
echo -e "\n"

# Informations finales
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           INFORMATIONS                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo "PID du processus : $PID"
echo "Nom du processus : affichage"
echo ""
echo -e "${YELLOW}Pour nettoyer:${NC}"
echo "  kill $PID"
echo "  sudo rmmod rootkit    # (peut ne pas marcher si auto-masqué)"
echo "  # Si rmmod ne marche pas: redémarre la VM"
echo ""
echo -e "${YELLOW}Pour voir les logs détaillés:${NC}"
echo "  sudo dmesg | grep rootkit"
