CC = gcc
CFLAGS = -Wall -O2
TARGET = resistant
SOURCE = resistant.c

all: $(TARGET)
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  ✓ Compilation réussie !"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "Pour lancer:"
	@echo "  ./$(TARGET)"
	@echo ""
	@echo "Pour tester:"
	@echo "  make test"
	@echo ""

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE)

test: $(TARGET)
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  TEST DE RÉSISTANCE"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "[1] Lancement du processus résistant..."
	@./$(TARGET) &
	@sleep 3
	@echo ""
	@echo "[2] Vérification du processus..."
	@ps aux | grep resistant | grep -v grep || echo "❌ Processus non trouvé"
	@echo ""
	@echo "[3] Tentative de kill normal..."
	@PID=$$(pgrep -f resistant | head -2 | tail -1); \
	if [ -n "$$PID" ]; then \
		echo "Killing PID $$PID..."; \
		kill $$PID; \
		sleep 3; \
		echo "Vérification si relancé..."; \
		ps aux | grep resistant | grep -v grep && echo "✓ Processus RELANCÉ !" || echo "❌ Processus mort"; \
	fi
	@echo ""
	@echo "[4] Pour voir les logs:"
	@echo "  tail -f /tmp/.resistant_log.txt"
	@echo ""
	@echo "[5] Pour arrêter proprement:"
	@echo "  make stop"
	@echo ""

stop:
	@echo "Arrêt du processus résistant..."
	@rm -f /tmp/.resistant_ctrl
	@sleep 2
	@pkill -9 -f resistant 2>/dev/null || true
	@echo "✓ Arrêté"

clean:
	@echo "Nettoyage..."
	rm -f $(TARGET)
	rm -f /tmp/.resistant_log.txt
	rm -f /tmp/.resistant_ctrl
	@echo "✓ Nettoyé"

logs:
	@echo "═══════════════════════════════════════"
	@echo "  LOGS DU PROCESSUS RÉSISTANT"
	@echo "═══════════════════════════════════════"
	@if [ -f /tmp/.resistant_log.txt ]; then \
		tail -30 /tmp/.resistant_log.txt; \
	else \
		echo "Aucun log trouvé."; \
	fi

help:
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  COMMANDES DISPONIBLES"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "  make          Compiler le programme"
	@echo "  make test     Tester la résistance"
	@echo "  make stop     Arrêter le processus"
	@echo "  make logs     Voir les logs"
	@echo "  make clean    Nettoyer tout"
	@echo "  make help     Afficher cette aide"
	@echo ""

.PHONY: all test stop clean logs help
