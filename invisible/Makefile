# Makefile - Solution d'invisibilité de processus
# Combine approche user-space (LD_PRELOAD) et kernel-space (module)

# === Configuration User-Space ===
USERLIB = libhook.so
USERSRC = hook_userspace.c
USERFLAGS = -Wall -fPIC -shared -O2
USERLINKS = -ldl

# === Configuration Kernel-Space ===
KERNELMOD = rootkit.ko
KERNELSRC = rootkit.c
KVERSION := /lib/modules/$(shell uname -r)/build

# === Chemins d'installation ===
LIBDIR = /usr/local/lib

.PHONY: all help clean user kernel install-user test-user

# Cible par défaut
all: user
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  Compilation terminée avec succès"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "Prochaines étapes:"
	@echo "  1. Test: make test-user"
	@echo "  2. Installation: sudo make install-user"
	@echo ""

# Compilation user-space (recommandé)
user: $(USERLIB)

$(USERLIB): $(USERSRC)
	@echo "Compilation de la bibliothèque user-space..."
	gcc $(USERFLAGS) -o $(USERLIB) $(USERSRC) $(USERLINKS)
	@echo "✓ Bibliothèque créée: $(USERLIB)"

# Compilation kernel-space (optionnel)
kernel:
	@echo "Compilation du module kernel..."
	$(MAKE) -C $(KVERSION) M=$(PWD) modules
	@echo "✓ Module kernel créé: $(KERNELMOD)"

# Installation de la solution user-space
install-user: user
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  Installation de la solution"
	@echo "═══════════════════════════════════════"
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "❌ Erreur: droits root nécessaires"; \
		echo "   Utiliser: sudo make install-user"; \
		exit 1; \
	fi
	@echo "[1/2] Installation de la bibliothèque..."
	install -m 755 $(USERLIB) $(LIBDIR)/$(USERLIB)
	@echo "      ✓ Installé: $(LIBDIR)/$(USERLIB)"
	@echo ""
	@echo "[2/2] Mise à jour du cache des bibliothèques..."
	ldconfig
	@echo "      ✓ Cache actualisé"
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  Installation réussie!"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "Usage:"
	@echo "  LD_PRELOAD=$(LIBDIR)/$(USERLIB) ps aux"
	@echo ""

# Test rapide de la solution user-space
test-user: user
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  Test de la solution user-space"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "[Étape 1] Lancement du processus cible..."
	@cd ../proc && ./affichage & echo "  → PID: $$!"
	@sleep 2
	@echo ""
	@echo "[Étape 2] Vérification sans interception:"
	@ps aux | grep affichage | grep -v grep | head -1 || echo "  ⚠ Processus non trouvé"
	@echo ""
	@echo "[Étape 3] Test avec interception LD_PRELOAD:"
	@if LD_PRELOAD=./$(USERLIB) ps aux | grep affichage | grep -v grep; then \
		echo "  ❌ Processus encore visible"; \
	else \
		echo "  ✓ Processus invisible - succès!"; \
	fi
	@echo ""
	@echo "[Étape 4] Nettoyage..."
	@pkill -f affichage 2>/dev/null || true
	@echo ""
	@echo "═══════════════════════════════════════"

# Charger le module kernel
load-kernel: kernel
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "❌ Root requis: sudo make load-kernel"; \
		exit 1; \
	fi
	@echo "Chargement du module kernel..."
	@lsmod | grep -q rootkit && rmmod rootkit 2>/dev/null || true
	insmod $(KERNELMOD) target_name="affichage"
	@echo "✓ Module chargé avec succès"
	@echo ""
	@echo "Messages kernel (5 dernières lignes):"
	@dmesg | grep rootkit | tail -5

# Décharger le module kernel
unload-kernel:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "❌ Root requis: sudo make unload-kernel"; \
		exit 1; \
	fi
	@echo "Déchargement du module kernel..."
	@rmmod rootkit 2>/dev/null || echo "⚠ Module introuvable ou auto-masqué"
	@echo ""
	@echo "Derniers messages kernel:"
	@dmesg | grep rootkit | tail -3

# Nettoyage
clean:
	@echo "Nettoyage des fichiers compilés..."
	rm -f $(USERLIB)
	rm -f *.o *.ko *.mod* .*.cmd Module.symvers modules.order
	rm -rf .tmp_versions
	@echo "✓ Nettoyage terminé"

# Désinstallation
uninstall-user:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "❌ Root requis: sudo make uninstall-user"; \
		exit 1; \
	fi
	@echo "Désinstallation de la bibliothèque..."
	rm -f $(LIBDIR)/$(USERLIB)
	rm -f /etc/ld.so.preload 2>/dev/null || true
	ldconfig
	@echo "✓ Désinstallation terminée"

# Aide
help:
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  Makefile - Invisibilité de processus"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "COMPILATION:"
	@echo "  make             Compile la solution user-space"
	@echo "  make user        Idem"
	@echo "  make kernel      Compile le module kernel"
	@echo ""
	@echo "TESTS:"
	@echo "  make test-user   Test rapide user-space"
	@echo ""
	@echo "INSTALLATION (sudo requis):"
	@echo "  make install-user     Installe la bibliothèque"
	@echo "  make load-kernel      Charge le module kernel"
	@echo "  make unload-kernel    Décharge le module"
	@echo ""
	@echo "MAINTENANCE:"
	@echo "  make clean            Supprime les fichiers compilés"
	@echo "  make uninstall-user   Désinstalle la bibliothèque"
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "RECOMMANDATION:"
	@echo "  Pour kernel 6.x, utilisez user-space"
	@echo "  (plus stable et compatible)"
	@echo "═══════════════════════════════════════"
	@echo ""

# Configuration pour la compilation kernel
obj-m += rootkit.o
