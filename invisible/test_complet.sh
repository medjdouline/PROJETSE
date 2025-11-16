#!/bin/bash
#
# test_complet.sh - Script de validation de l'invisibilité de processus
# Teste la solution user-space (LD_PRELOAD) et optionnellement kernel
#

# === Configuration des couleurs ===
ROUGE='\033[0;31m'
VERT='\033[0;32m'
JAUNE='\033[1;33m'
BLEU='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Variables globales ===
NOM_PROCESSUS="affichage"
BIBLIO_USER="./libhook.so"
MODULE_KERNEL="rootkit.ko"
PID_CIBLE=0
MODE_TEST="user"

#==============================================================================
# Fonctions d'affichage
#==============================================================================

afficher_titre() {
    echo -e "\n${BLEU}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLEU}║  $1${RESET}"
    echo -e "${BLEU}╚══════════════════════════════════════════════════╝${RESET}\n"
}

afficher_section() {
    echo -e "\n${CYAN}═══ $1 ═══${RESET}\n"
}

afficher_ok() {
    echo -e "${VERT}✓ $1${RESET}"
}

afficher_erreur() {
    echo -e "${ROUGE}✗ $1${RESET}"
}

afficher_attention() {
    echo -e "${JAUNE}⚠ $1${RESET}"
}

afficher_info() {
    echo -e "${BLEU}ℹ $1${RESET}"
}

#==============================================================================
# Vérifications préalables
#==============================================================================

verifier_prerequisites() {
    afficher_section "Vérifications préalables"
    
    # Vérifier l'exécutable affichage
    if [ ! -f "../proc/affichage" ]; then
        afficher_erreur "Exécutable affichage introuvable dans ../proc/"
        echo "   Compiler d'abord: cd ../proc && make"
        exit 1
    fi
    afficher_ok "Exécutable affichage trouvé"
    
    # Vérifier la bibliothèque user-space
    if [ "$MODE_TEST" = "user" ] || [ "$MODE_TEST" = "complet" ]; then
        if [ ! -f "$BIBLIO_USER" ]; then
            afficher_erreur "Bibliothèque user-space introuvable: $BIBLIO_USER"
            echo "   Compiler: make user"
            exit 1
        fi
        afficher_ok "Bibliothèque user-space trouvée"
    fi
    
    # Vérifier le module kernel
    if [ "$MODE_TEST" = "kernel" ] || [ "$MODE_TEST" = "complet" ]; then
        if [ ! -f "$MODULE_KERNEL" ]; then
            afficher_erreur "Module kernel introuvable: $MODULE_KERNEL"
            echo "   Compiler: make kernel"
            exit 1
        fi
        afficher_ok "Module kernel trouvé"
        
        if [ "$EUID" -ne 0 ]; then
            afficher_erreur "Droits root requis pour le test kernel"
            echo "   Exécuter: sudo $0 $MODE_TEST"
            exit 1
        fi
    fi
    
    echo ""
}

#==============================================================================
# Gestion du processus
#==============================================================================

demarrer_processus() {
    afficher_section "Démarrage du processus cible"
    
    cd ../proc || exit 1
    ./affichage &
    PID_CIBLE=$!
    cd - > /dev/null || exit 1
    
    sleep 1
    
    if kill -0 $PID_CIBLE 2>/dev/null; then
        afficher_ok "Processus démarré (PID: $PID_CIBLE)"
    else
        afficher_erreur "Échec du démarrage"
        exit 1
    fi
    
    echo ""
}

arreter_processus() {
    if [ $PID_CIBLE -ne 0 ] && kill -0 $PID_CIBLE 2>/dev/null; then
        afficher_info "Arrêt du processus $PID_CIBLE..."
        kill $PID_CIBLE 2>/dev/null
        sleep 1
    fi
}

#==============================================================================
# Tests de visibilité
#==============================================================================

tester_visibilite() {
    local nom_test=$1
    local attendu_visible=$2
    local commande=$3
    
    echo -e "${JAUNE}Test: $nom_test${RESET}"
    
    local resultat
    resultat=$(eval "$commande" 2>/dev/null | grep "$NOM_PROCESSUS" | grep -v grep)
    
    if [ -n "$resultat" ]; then
        # Processus détecté
        if [ $attendu_visible -eq 1 ]; then
            afficher_ok "VISIBLE (comportement attendu)"
            echo "   $(echo "$resultat" | head -1)"
        else
            afficher_erreur "VISIBLE (devrait être masqué)"
            echo "   $(echo "$resultat" | head -1)"
            return 1
        fi
    else
        # Processus non détecté
        if [ $attendu_visible -eq 0 ]; then
            afficher_ok "INVISIBLE (comportement attendu)"
        else
            afficher_erreur "INVISIBLE (devrait être visible)"
            return 1
        fi
    fi
    echo ""
    return 0
}

executer_serie_tests() {
    local phase=$1
    local attendu=$2
    
    afficher_section "$phase - Batterie de tests"
    
    local echecs=0
    
    # Test 1: ps aux
    tester_visibilite "ps aux" $attendu "ps aux" || ((echecs++))
    
    # Test 2: ps avec PID spécifique
    tester_visibilite "ps -p $PID_CIBLE" $attendu "ps -p $PID_CIBLE" || ((echecs++))
    
    # Test 3: Présence dans /proc
    echo -e "${JAUNE}Test: /proc/$PID_CIBLE${RESET}"
    if ls /proc/$PID_CIBLE > /dev/null 2>&1; then
        if [ $attendu -eq 1 ]; then
            afficher_ok "Présent dans /proc"
        else
            afficher_erreur "Toujours dans /proc"
            ((echecs++))
        fi
    else
        if [ $attendu -eq 0 ]; then
            afficher_ok "Absent de /proc"
        else
            afficher_erreur "Absent de /proc"
            ((echecs++))
        fi
    fi
    echo ""
    
    # Test 4: pgrep
    tester_visibilite "pgrep $NOM_PROCESSUS" $attendu "pgrep $NOM_PROCESSUS" || ((echecs++))
    
    # Test 5: top
    tester_visibilite "top (instantané)" $attendu "top -b -n 1" || ((echecs++))
    
    return $echecs
}

#==============================================================================
# Test user-space
#==============================================================================

tester_userspace() {
    afficher_titre "TEST USER-SPACE (LD_PRELOAD)"
    
    # Phase 1: Sans interception
    executer_serie_tests "SANS LD_PRELOAD" 1
    
    # Application de LD_PRELOAD
    afficher_section "Activation de l'interception"
    export LD_PRELOAD="$(pwd)/$BIBLIO_USER"
    afficher_info "LD_PRELOAD=$LD_PRELOAD"
    echo ""
    
    # Phase 2: Avec interception
    executer_serie_tests "AVEC LD_PRELOAD" 0
    local resultat=$?
    
    # Désactivation
    unset LD_PRELOAD
    
    # Bilan
    afficher_section "BILAN USER-SPACE"
    if [ $resultat -eq 0 ]; then
        afficher_ok "Tous les tests ont réussi!"
    else
        afficher_attention "$resultat test(s) en échec"
    fi
    echo ""
    
    return $resultat
}

#==============================================================================
# Test kernel
#==============================================================================

tester_kernel() {
    afficher_titre "TEST KERNEL (Module)"
    
    if [ "$EUID" -ne 0 ]; then
        afficher_erreur "Droits root requis"
        return 1
    fi
    
    # Phase 1: Sans module
    executer_serie_tests "SANS MODULE" 1
    
    # Chargement du module
    afficher_section "Chargement du module kernel"
    
    if lsmod | grep -q rootkit; then
        afficher_attention "Module déjà chargé, rechargement..."
        rmmod rootkit 2>/dev/null || true
        sleep 1
    fi
    
    insmod "$MODULE_KERNEL" target_name="$NOM_PROCESSUS"
    if [ $? -ne 0 ]; then
        afficher_erreur "Échec du chargement"
        dmesg | grep rootkit | tail -5
        return 1
    fi
    afficher_ok "Module chargé"
    
    echo ""
    afficher_info "Logs kernel:"
    dmesg | grep rootkit | tail -5
    echo ""
    
    sleep 2
    
    # Phase 2: Avec module
    executer_serie_tests "AVEC MODULE" 0
    local resultat=$?
    
    # Vérification du module
    afficher_section "État du module"
    if lsmod | grep -q rootkit; then
        afficher_attention "Module visible (lsmod)"
    else
        afficher_ok "Module auto-masqué"
    fi
    echo ""
    
    # Déchargement
    afficher_info "Tentative de déchargement..."
    rmmod rootkit 2>/dev/null
    if [ $? -eq 0 ]; then
        afficher_ok "Module déchargé"
    else
        afficher_attention "Déchargement impossible (auto-masquage)"
        afficher_info "Redémarrage de la VM nécessaire pour nettoyage"
    fi
    echo ""
    
    # Bilan
    afficher_section "BILAN KERNEL"
    if [ $resultat -eq 0 ]; then
        afficher_ok "Tous les tests ont réussi!"
    else
        afficher_attention "$resultat test(s) en échec"
    fi
    echo ""
    
    return $resultat
}

#==============================================================================
# Programme principal
#==============================================================================

afficher_usage() {
    echo "Usage: $0 [user|kernel|complet]"
    echo ""
    echo "Modes disponibles:"
    echo "  user     - Test user-space uniquement (défaut)"
    echo "  kernel   - Test kernel uniquement (root requis)"
    echo "  complet  - Test des deux approches (root requis)"
    echo ""
    echo "Exemples:"
    echo "  $0               # Test user-space"
    echo "  $0 user          # Test user-space"
    echo "  sudo $0 kernel   # Test kernel"
    echo "  sudo $0 complet  # Test complet"
}

main() {
    # Analyse des arguments
    if [ $# -gt 1 ]; then
        afficher_usage
        exit 1
    fi
    
    if [ $# -eq 1 ]; then
        MODE_TEST=$1
        case "$MODE_TEST" in
            user|kernel|complet)
                ;;
            *)
                echo "Mode invalide: $MODE_TEST"
                afficher_usage
                exit 1
                ;;
        esac
    fi
    
    # En-tête
    clear
    echo -e "${BLEU}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║                                                    ║"
    echo "║   VALIDATION INVISIBILITÉ DE PROCESSUS            ║"
    echo "║   Solution Hybride User/Kernel Space              ║"
    echo "║                                                    ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    afficher_info "Mode: $MODE_TEST"
    afficher_info "Kernel: $(uname -r)"
    afficher_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Vérifications
    verifier_prerequisites
    
    # Démarrage du processus
    demarrer_processus
    
    # Cleanup automatique
    trap 'arreter_processus' EXIT
    
    # Exécution des tests
    local code_retour=0
    
    case "$MODE_TEST" in
        user)
            tester_userspace
            code_retour=$?
            ;;
        kernel)
            tester_kernel
            code_retour=$?
            ;;
        complet)
            tester_userspace
            local res_user=$?
            
            tester_kernel
            local res_kernel=$?
            
            [ $res_user -eq 0 ] && [ $res_kernel -eq 0 ] && code_retour=0 || code_retour=1
            ;;
    esac
    
    # Bilan final
    afficher_titre "BILAN GÉNÉRAL"
    
    echo -e "PID du processus: ${CYAN}$PID_CIBLE${RESET}"
    echo -e "Nom: ${CYAN}$NOM_PROCESSUS${RESET}"
    echo ""
    
    if [ $code_retour -eq 0 ]; then
        afficher_ok "VALIDATION COMPLÈTE RÉUSSIE! 🎉"
    else
        afficher_attention "CERTAINS TESTS ONT ÉCHOUÉ"
    fi
    
    echo ""
    afficher_info "Pour nettoyer:"
    echo "  - Processus: kill $PID_CIBLE"
    if lsmod | grep -q rootkit 2>/dev/null; then
        echo "  - Module: sudo rmmod rootkit (ou redémarrage)"
    fi
    echo ""
    
    return $code_retour
}

# Exécution
main "$@"
exit $?
