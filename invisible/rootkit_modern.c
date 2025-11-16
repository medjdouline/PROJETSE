#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sched.h>
#include <linux/slab.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Student Project");

static char *target_name = "affichage";
module_param(target_name, charp, 0644);

static int pid_to_hide = 0;
module_param(pid_to_hide, int, 0644);

static struct proc_dir_entry *proc_entry = NULL;

// Hook pour /proc
static int proc_hook_show(struct seq_file *m, void *v)
{
    struct task_struct *task;
    char buffer[256];
    int len = 0;
    
    for_each_process(task) {
        // Vérifier si c'est le processus à masquer
        if (pid_to_hide && task->pid == pid_to_hide)
            continue;
            
        if (target_name[0] != '\0' && strcmp(task->comm, target_name) == 0)
            continue;
        
        // Afficher normalement les autres processus
        seq_printf(m, "%d %s\n", task->pid, task->comm);
    }
    
    return 0;
}

static int proc_hook_open(struct inode *inode, struct file *file)
{
    return single_open(file, proc_hook_show, NULL);
}

static const struct proc_ops proc_hook_fops = {
    .proc_open = proc_hook_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

static int __init modern_rootkit_init(void)
{
    printk(KERN_INFO "Modern Rootkit: Loading\n");
    
    // Créer un faux fichier /proc
    proc_entry = proc_create("processes_hidden", 0444, NULL, &proc_hook_fops);
    if (!proc_entry) {
        printk(KERN_ERR "Modern Rootkit: Failed to create proc entry\n");
        return -ENOMEM;
    }
    
    printk(KERN_INFO "Modern Rootkit: Hiding process '%s'\n", target_name);
    printk(KERN_INFO "Modern Rootkit: Use 'cat /proc/processes_hidden' to see filtered processes\n");
    
    return 0;
}

static void __exit modern_rootkit_exit(void)
{
    if (proc_entry)
        proc_remove(proc_entry);
        
    printk(KERN_INFO "Modern Rootkit: Unloaded\n");
}

module_init(modern_rootkit_init);
module_exit(modern_rootkit_exit);
