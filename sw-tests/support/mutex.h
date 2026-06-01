#ifndef MUTEX_H
#define MUTEX_H

// A simple mutex with a nonatomic lock and blocking lock/unlock methods. Make sure to zero
// initialize!
typedef struct {
    int lock;
} mutex_t;

// Atomically locks the mutex. Will spin until the lock is acquired.
void __attribute__((noinline)) mutex_lock(volatile mutex_t *m);
// Nonatomically unlocks the mutex. Should only be called if the mutex is held.
void __attribute__((noinline)) mutex_unlock(volatile mutex_t *m);

#endif
