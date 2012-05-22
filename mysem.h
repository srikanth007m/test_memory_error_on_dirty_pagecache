#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>

union semun {
	int              val;
	struct semid_ds *buf;
	unsigned short  *array;
	struct seminfo  *__buf;
};

int create_and_init_semaphore() {
	int sem;
	union semun arg;
	if ((sem = semget(IPC_PRIVATE, 1, 0666)) == -1)
		err("semget");
	arg.val = 1;
	if (semctl(sem, 0, SETVAL, arg) == -1)
		err("semctl");
	return sem;
}

int delete_semaphore(int sem_id) {
	return semctl(sem_id, 0, IPC_RMID, NULL);
}

int get_semaphore(int sem_id, struct sembuf *sembuffer)
{
        sembuffer->sem_num = 0;
        sembuffer->sem_op  = -1;
        sembuffer->sem_flg = SEM_UNDO;
        return semop(sem_id, sembuffer, 1);
}

int put_semaphore(int sem_id, struct sembuf *sembuffer)
{
        sembuffer->sem_num = 0;
        sembuffer->sem_op  = 1;
        sembuffer->sem_flg = SEM_UNDO;
        return semop(sem_id, sembuffer, 1);
}
