#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <time.h>
#include <string.h>

#define INTERVALLE_TRAVAIL 5

static volatile int continuer_execution = 1;

void obtenir_horodatage(char* buffer, size_t taille) {
    time_t maintenant = time(NULL);
    struct tm* info = localtime(&maintenant);
    strftime(buffer, taille, "%Y-%m-%d %H:%M:%S", info);
}

void ecrire_log(const char* message) {
    char horodatage[64];
    obtenir_horodatage(horodatage, sizeof(horodatage));
    printf("[%s] [PID:%d] %s\n", horodatage, getpid(), message);
    fflush(stdout);
}

void gestionnaire_signaux(int signal) {
    char message[256];
    
    switch(signal) {
        case SIGTERM:
            snprintf(message, sizeof(message), "SIGTERM recu mais IGNORE");
            ecrire_log(message);
            break;
            
        case SIGINT:
            snprintf(message, sizeof(message), "SIGINT recu mais IGNORE");
            ecrire_log(message);
            break;
            
        case SIGHUP:
            snprintf(message, sizeof(message), "SIGHUP recu mais IGNORE");
            ecrire_log(message);
            break;
            
        case SIGUSR1:
            snprintf(message, sizeof(message), "SIGUSR1 recu - Arret propre");
            ecrire_log(message);
            continuer_execution = 0;
            break;
    }
}

void installer_gestionnaires() {
    signal(SIGTERM, gestionnaire_signaux);
    signal(SIGINT, gestionnaire_signaux);
    signal(SIGHUP, gestionnaire_signaux);
    signal(SIGQUIT, SIG_IGN);
    signal(SIGUSR1, gestionnaire_signaux);
    
    ecrire_log("Gestionnaires de signaux installes");
}

int main() {
    char message[256];
    int compteur = 0;
    
    ecrire_log("Demarrage du daemon resistant");
    
    snprintf(message, sizeof(message), "PID=%d, PPID=%d, UID=%d, GID=%d",
            getpid(), getppid(), getuid(), getgid());
    ecrire_log(message);
    
    installer_gestionnaires();
    
    while (continuer_execution) {
        compteur++;
        
        snprintf(message, sizeof(message), 
                "Cycle #%d - PID=%d, PPID=%d, UID=%d, GID=%d",
                compteur, getpid(), getppid(), getuid(), getgid());
        ecrire_log(message);
        
        sleep(INTERVALLE_TRAVAIL);
    }
    
    ecrire_log("Arret du daemon resistant");
    
    return 0;
}



