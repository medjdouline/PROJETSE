#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int main() {
    pid_t pid = getpid();
    pid_t ppid = getppid();
    uid_t uid = getuid();
    gid_t gid = getgid();
    
    printf("PID: %d\n", pid);
    printf("PPID: %d\n", ppid);
    printf("UID: %d\n", uid);
    printf("GID: %d\n", gid);
    
    sleep(600);
    
    return 0;
}
