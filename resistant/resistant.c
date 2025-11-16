#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <time.h>

#define FICHIER_CONTROLE "/tmp/.resistant_ctrl"
#define FICHIER_LOG "/tmp/.resistant_log.txt"
#define INTERVALLE_TRAVAIL 5
#define INTERVALLE_CHECK 1

static volatile int continuer_execution = 1;

void obtenir_horodatage(char* buffer, size_t taille) {
    time_t maintenant = time(NULL);
    struct tm* info = localtime(&maintenant);
    strftime(buffer, taille, "%Y-%m-%d %H:%M:%S", info);
}

void ecrire_log(const char* message) {
    FILE* fichier = fopen(FICHIER_LOG, "a");
    if (fichier) {
        char horodatage[64];
        obtenir_horodatage(horodatage, sizeof(horodatage));
        fprintf(fichier, "[%s] [PID:%d] %s\n", horodatage, getpid(), message);
        fclose(fichier);
    }
}

void creer_fichier_controle() {
    FILE* fichier = fopen(FICHIER_CONTROLE, "w");
    if (fichier) {
        fprintf(fichier, "%d\n", getpid());
        fclose(fichier);
    }
}

int fichier_controle_existe() {
    return (access(FICHIER_CONTROLE, F_OK) == 0);
}

int processus_existe(pid_t pid) {
    return (kill(pid, 0) == 0);
}

void gestionnaire_signaux_enfant(int signal) {
    char message[256];
    
    switch(signal) {
        case SIGTERM:
            snprintf(message, sizeof(message), "ENFANT: SIGTERM recu mais IGNORE");
            ecrire_log(message);
            break;
            
        case SIGINT:
            snprintf(message, sizeof(message), "ENFANT: SIGINT recu mais IGNORE");
            ecrire_log(message);
            break;
            
        case SIGHUP:
            snprintf(message, sizeof(message), "ENFANT: SIGHUP recu mais IGNORE");
            ecrire_log(message);
            break;
            
        case SIGUSR1:
            snprintf(message, sizeof(message), "ENFANT: SIGUSR1 recu - Arret propre");
            ecrire_log(message);
            continuer_execution = 0;
            break;
    }
}

void gestionnaire_signaux_parent(int signal) {
    char message[256];
    
    switch(signal) {
        case SIGCHLD:
            snprintf(message, sizeof(message), "PARENT: SIGCHLD recu - Enfant termine");
            ecrire_log(message);
            break;
            
        case SIGTERM:
        case SIGINT:
            snprintf(message, sizeof(message), "PARENT: Signal d'arret recu - Arret propre");
            ecrire_log(message);
            continuer_execution = 0;
            break;
    }
}

void installer_gestionnaires_enfant() {
    signal(SIGTERM, gestionnaire_signaux_enfant);
    signal(SIGINT, gestionnaire_signaux_enfant);
    signal(SIGHUP, gestionnaire_signaux_enfant);
    signal(SIGQUIT, SIG_IGN);
    signal(SIGUSR1, gestionnaire_signaux_enfant);
    
    ecrire_log("ENFANT: Gestionnaires de signaux installes");
}

void installer_gestionnaires_parent() {
    signal(SIGCHLD, gestionnaire_signaux_parent);
    signal(SIGTERM, gestionnaire_signaux_parent);
    signal(SIGINT, gestionnaire_signaux_parent);
    
    ecrire_log("PARENT: Gestionnaires de signaux installes");
}

void executer_processus_enfant() {
    char message[256];
    int compteur = 0;
    
    ecrire_log("ENFANT: Demarrage du processus enfant");
    
    installer_gestionnaires_enfant();
    
    while (continuer_execution && fichier_controle_existe()) {
        compteur++;
        
        snprintf(message, sizeof(message), 
                "ENFANT: Cycle #%d - PID=%d, PPID=%d, UID=%d, GID=%d",
                compteur, getpid(), getppid(), getuid(), getgid());
        ecrire_log(message);
        
        printf("[ENFANT PID %d] Cycle %d\n", getpid(), compteur);
        fflush(stdout);
        
        sleep(INTERVALLE_TRAVAIL);
    }
    
    ecrire_log("ENFANT: Fin du processus enfant");
    exit(0);
}

pid_t lancer_enfant() {
    pid_t pid = fork();
    
    if (pid < 0) {
        ecrire_log("PARENT: ERREUR - Impossible de creer l'enfant");
        return -1;
    }
    else if (pid == 0) {
        executer_processus_enfant();
        exit(0);
    }
    else {
        char message[256];
        snprintf(message, sizeof(message), "PARENT: Nouvel enfant cree avec PID=%d", pid);
        ecrire_log(message);
        printf("[PARENT] Enfant lance : PID %d\n", pid);
        return pid;
    }
}

void executer_processus_parent() {
    char message[256];
    pid_t pid_enfant = 0;
    int compteur_relance = 0;
    
    ecrire_log("PARENT: Demarrage du processus parent");
    
    installer_gestionnaires_parent();
    creer_fichier_controle();
    
    pid_enfant = lancer_enfant();
    if (pid_enfant < 0) {
        ecrire_log("PARENT: ERREUR critique - Impossible de demarrer");
        return;
    }
    
    while (continuer_execution && fichier_controle_existe()) {
        sleep(INTERVALLE_CHECK);
        
        int status;
        pid_t result = waitpid(pid_enfant, &status, WNOHANG);
        
        if (result > 0) {
            compteur_relance++;
            
            snprintf(message, sizeof(message), 
                    "PARENT: Enfant %d MORT detecte - Relance #%d",
                    pid_enfant, compteur_relance);
            ecrire_log(message);
            printf("\n%s\n\n", message);
            
            sleep(1);
            pid_enfant = lancer_enfant();
            
            if (pid_enfant < 0) {
                ecrire_log("PARENT: ERREUR - Impossible de relancer");
                break;
            }
        }
    }
    
    ecrire_log("PARENT: Arret demande - Nettoyage");
    
    if (processus_existe(pid_enfant)) {
        snprintf(message, sizeof(message), "PARENT: Envoi SIGKILL a l'enfant %d", pid_enfant);
        ecrire_log(message);
        kill(pid_enfant, SIGKILL);
        waitpid(pid_enfant, NULL, 0);
    }
    
    snprintf(message, sizeof(message), "PARENT: Termine - %d relances effectuees", compteur_relance);
    ecrire_log(message);
}

int main() {
    printf("PROCESSUS RESISTANT\n");
    printf("PID Principal : %d\n", getpid());
    printf("Fichier log   : %s\n", FICHIER_LOG);
    printf("Fichier ctrl  : %s\n", FICHIER_CONTROLE);
    printf("\nPour arreter : rm %s\n", FICHIER_CONTROLE);
    printf("Pour voir logs : tail -f %s\n\n", FICHIER_LOG);
    
    FILE* f = fopen(FICHIER_LOG, "w");
    if (f) fclose(f);
    
    executer_processus_parent();
    
    remove(FICHIER_CONTROLE);
    
    printf("\nProcessus resistant termine\n");
    
    return 0;
}
