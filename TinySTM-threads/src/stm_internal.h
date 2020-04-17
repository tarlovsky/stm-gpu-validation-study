/*
 * File:
 *   stm_internal.h
 * Author(s):
 *   Pascal Felber <pascal.felber@unine.ch>
 *   Patrick Marlier <patrick.marlier@unine.ch>
 * Description:
 *   STM internal functions.
 *
 * Copyright (c) 2007-2012.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, version 2
 * of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * This program has a dual license and can also be distributed
 * under the terms of the MIT license.
 */



#ifndef _STM_INTERNAL_H_
#define _STM_INTERNAL_H_
#include <pthread.h>
#include <stdatomic.h>
#include <string.h>
#include "tls.h"
#include <stm.h>
#include "utils.h"
#include "atomic.h"
#include "gc.h"
#include "inttypes.h"



/*tarlovskyy*/
#include "timer.h"

/* ################################################################### *
 * DEFINES
 * ################################################################### */

/* Designs */
#define WRITE_BACK_ETL                  0
#define WRITE_BACK_CTL                  1
#define WRITE_THROUGH                   2
#define MODULAR                         3

#ifndef DESIGN
# define DESIGN                         WRITE_BACK_ETL
#endif /* ! DESIGN */

/* Contention managers */
#define CM_SUICIDE                      0
#define CM_DELAY                        1
#define CM_BACKOFF                      2
#define CM_MODULAR                      3

#ifndef CM
# define CM                             CM_SUICIDE
#endif /* ! CM */

#if DESIGN != WRITE_BACK_ETL && CM == CM_MODULAR
# error "MODULAR contention manager can only be used with WB-ETL design"
#endif /* DESIGN != WRITE_BACK_ETL && CM == CM_MODULAR */

#if defined(CONFLICT_TRACKING) && ! defined(EPOCH_GC)
# error "CONFLICT_TRACKING requires EPOCH_GC"
#endif /* defined(CONFLICT_TRACKING) && ! defined(EPOCH_GC) */

#if CM == CM_MODULAR && ! defined(EPOCH_GC)
# error "MODULAR contention manager requires EPOCH_GC"
#endif /* CM == CM_MODULAR && ! defined(EPOCH_GC) */

#if defined(READ_LOCKED_DATA) && CM != CM_MODULAR
# error "READ_LOCKED_DATA can only be used with MODULAR contention manager"
#endif /* defined(READ_LOCKED_DATA) && CM != CM_MODULAR */

#if defined(EPOCH_GC) && defined(SIGNAL_HANDLER)
# error "SIGNAL_HANDLER can only be used without EPOCH_GC"
#endif /* defined(EPOCH_GC) && defined(SIGNAL_HANDLER) */

#define TX_GET                          stm_tx_t *tx = tls_get_tx()

#ifndef RW_SET_SIZE
# define RW_SET_SIZE                    4096                /* Initial size of read/write sets */
#endif /* ! RW_SET_SIZE */

/*#define VALTHREADS                      2*/

#ifndef LOCK_ARRAY_LOG_SIZE
# define LOCK_ARRAY_LOG_SIZE            26                  /* Size of lock array: 2^20 = 1M */
#endif /* LOCK_ARRAY_LOG_SIZE */

#ifndef LOCK_SHIFT_EXTRA
# define LOCK_SHIFT_EXTRA               2                   /* 2 extra shift */
#endif /* LOCK_SHIFT_EXTRA */

#if CM == CM_BACKOFF
# ifndef MIN_BACKOFF
#  define MIN_BACKOFF                   (1UL << 2)
# endif /* MIN_BACKOFF */
# ifndef MAX_BACKOFF
#  define MAX_BACKOFF                   (1UL << 31)
# endif /* MAX_BACKOFF */
#endif /* CM == CM_BACKOFF */

#if CM == CM_MODULAR
# define VR_THRESHOLD                   "VR_THRESHOLD"
# ifndef VR_THRESHOLD_DEFAULT
#  define VR_THRESHOLD_DEFAULT          3                   /* -1 means no visible reads. 0 means always use visible reads. */
# endif /* VR_THRESHOLD_DEFAULT */
#endif /* CM == CM_MODULAR */

#define NO_SIGNAL_HANDLER               "NO_SIGNAL_HANDLER"


#if defined(CTX_LONGJMP)
# define JMP_BUF                        jmp_buf
# define LONGJMP(ctx, value)            longjmp(ctx, value)
#elif defined(CTX_ITM)
/* TODO adjust size to real size. */
# define JMP_BUF                        jmp_buf
# define LONGJMP(ctx, value)            CTX_ITM(value, ctx)
#else /* !CTX_LONGJMP && !CTX_ITM */
# define JMP_BUF                        sigjmp_buf
# define LONGJMP(ctx, value)            siglongjmp(ctx, value)
#endif /* !CTX_LONGJMP && !CTX_ITM */


/* ################################################################### *
 * TYPES
 * ################################################################### */

enum {                                  /* Transaction status */
  TX_IDLE = 0,
  TX_ACTIVE = 1,                        /* Lowest bit indicates activity */
  TX_COMMITTED = (1 << 1),
  TX_ABORTED = (2 << 1),
  TX_COMMITTING = (1 << 1) | TX_ACTIVE,
  TX_ABORTING = (2 << 1) | TX_ACTIVE,
  TX_KILLED = (3 << 1) | TX_ACTIVE,
  TX_IRREVOCABLE = 0x08 | TX_ACTIVE     /* Fourth bit indicates irrevocability */
};
#define STATUS_BITS                     4
#define STATUS_MASK                     ((1 << STATUS_BITS) - 1)

#if CM == CM_MODULAR
# define SET_STATUS(s, v)               ATOMIC_STORE_REL(&(s), ((s) & ~(stm_word_t)STATUS_MASK) | (v))
# define INC_STATUS_COUNTER(s)          ((((s) >> STATUS_BITS) + 1) << STATUS_BITS)
# define UPDATE_STATUS(s, v)            ATOMIC_STORE_REL(&(s), INC_STATUS_COUNTER(s) | (v))
# define GET_STATUS(s)                  ((s) & STATUS_MASK)
# define GET_STATUS_COUNTER(s)          ((s) >> STATUS_BITS)
#else /* CM != CM_MODULAR */
# define SET_STATUS(s, v)               ((s) = (v))
# define UPDATE_STATUS(s, v)            ((s) = (v))
# define GET_STATUS(s)                  ((s))
#endif /* CM != CM_MODULAR */
#define IS_ACTIVE(s)                    ((GET_STATUS(s) & 0x01) == TX_ACTIVE)

/* ################################################################### *
 * LOCKS
 * ################################################################### */

/*
 * A lock is a unsigned integer of the size of a pointer.
 * The LSB is the lock bit. If it is set, this means:
 * - At least some covered memory addresses is being written.
 * - All bits of the lock apart from the lock bit form
 *   a pointer that points to the write log entry holding the new
 *   value. Multiple values covered by the same log entry and orginized
 *   in a linked list in the write log.
 * If the lock bit is not set, then:
 * - All covered memory addresses contain consistent values.
 * - All bits of the lock besides the lock bit contain a version number
 *   (timestamp).
 *   - The high order bits contain the commit time.
 *   - The low order bits contain an incarnation number (incremented
 *     upon abort while writing the covered memory addresses).
 * When visible reads are enabled, two bits are used as read and write
 * locks. A read-locked address can be read by an invisible reader.
 */

#if CM == CM_MODULAR
# define OWNED_BITS                     2                   /* 2 bits */
# define WRITE_MASK                     0x01                /* 1 bit */
# define READ_MASK                      0x02                /* 1 bit */
# define OWNED_MASK                     (WRITE_MASK | READ_MASK)
#else /* CM != CM_MODULAR */
# define OWNED_BITS                     1                   /* 1 bit */
# define WRITE_MASK                     0x01                /* 1 bit */
# define OWNED_MASK                     (WRITE_MASK)
#endif /* CM != CM_MODULAR */
#define INCARNATION_BITS                3                   /* 3 bits */
#define INCARNATION_MAX                 ((1 << INCARNATION_BITS) - 1)
#define INCARNATION_MASK                (INCARNATION_MAX << 1)
#define LOCK_BITS                       (OWNED_BITS + INCARNATION_BITS)
#define MAX_THREADS                     8192                /* Upper bound (large enough) */
#define VERSION_MAX                     ((~(stm_word_t)0 >> LOCK_BITS) - MAX_THREADS)

#define LOCK_GET_OWNED(l)               (l & OWNED_MASK)
#define LOCK_GET_WRITE(l)               (l & WRITE_MASK)
#define LOCK_SET_ADDR_WRITE(a)          (a | WRITE_MASK)    /* WRITE bit set */
#define LOCK_GET_ADDR(l)                (l & ~(stm_word_t)OWNED_MASK)
#if CM == CM_MODULAR
# define LOCK_GET_READ(l)               (l & READ_MASK)
# define LOCK_SET_ADDR_READ(a)          (a | READ_MASK)     /* READ bit set */
# define LOCK_UPGRADE(l)                (l | WRITE_MASK)
#endif /* CM == CM_MODULAR */
#define LOCK_GET_TIMESTAMP(l)           (l >> (LOCK_BITS))
#define LOCK_SET_TIMESTAMP(t)           (t << (LOCK_BITS))
#define LOCK_GET_INCARNATION(l)         ((l & INCARNATION_MASK) >> OWNED_BITS)
#define LOCK_SET_INCARNATION(i)         (i << OWNED_BITS)   /* OWNED bit not set */
#define LOCK_UPD_INCARNATION(l, i)      ((l & ~(stm_word_t)(INCARNATION_MASK | OWNED_MASK)) | LOCK_SET_INCARNATION(i))
#ifdef UNIT_TX
# define LOCK_UNIT                       (~(stm_word_t)0)
#endif /* UNIT_TX */

/*
 * We use the very same hash functions as TL2 for degenerate Bloom
 * filters on 32 bits.
 */
#ifdef USE_BLOOM_FILTER
# define FILTER_HASH(a)                 (((stm_word_t)a >> 2) ^ ((stm_word_t)a >> 5))
# define FILTER_BITS(a)                 (1 << (FILTER_HASH(a) & 0x1F))
#endif /* USE_BLOOM_FILTER */

/*
 * We use an array of locks and hash the address to find the location of the lock.
 * We try to avoid collisions as much as possible (two addresses covered by the same lock).
 */
#define LOCK_ARRAY_SIZE                 (1 << LOCK_ARRAY_LOG_SIZE)
#define LOCK_MASK                       (LOCK_ARRAY_SIZE - 1)
#define LOCK_SHIFT                      (((sizeof(stm_word_t) == 4) ? 2 : 3) + LOCK_SHIFT_EXTRA)
#define LOCK_IDX(a)                     (((stm_word_t)(a) >> LOCK_SHIFT) & LOCK_MASK)
#ifdef LOCK_IDX_SWAP
# if LOCK_ARRAY_LOG_SIZE < 16
#  error "LOCK_IDX_SWAP requires LOCK_ARRAY_LOG_SIZE to be at least 16"
# endif /* LOCK_ARRAY_LOG_SIZE < 16 */
# define GET_LOCK(a)                    (_tinystm.locks + lock_idx_swap(LOCK_IDX(a)))
#else /* ! LOCK_IDX_SWAP */
# define GET_LOCK(a)                    (_tinystm.locks + LOCK_IDX(a))
#endif /* ! LOCK_IDX_SWAP */

/* ################################################################### *
 * CLOCK
 * ################################################################### */

/* At least twice a cache line (not required if properly aligned and padded) */
#define CLOCK                           (_tinystm.gclock[(CACHELINE_SIZE * 2) / sizeof(stm_word_t)])

#define GET_CLOCK                       (ATOMIC_LOAD_ACQ(&CLOCK))
#define FETCH_INC_CLOCK                 (ATOMIC_FETCH_INC_FULL(&CLOCK))

/* ################################################################### *
 * CALLBACKS
 * ################################################################### */

/* The number of 7 is chosen to make fit the number and the array in a
 * same cacheline (assuming 64bytes cacheline and 64bits CPU). */
#define MAX_CB                          7

/* Declare as static arrays (vs. lists) to improve cache locality */
/* The number transaction local specific for modules. */
#ifndef MAX_SPECIFIC
# define MAX_SPECIFIC                   7
#endif /* MAX_SPECIFIC */

typedef struct r_entry {                /* Read set entry */
  stm_word_t version;                   /* Version read */
  volatile stm_word_t *lock;            /* Pointer to lock (for fast access) */
} r_entry_t;

typedef struct r_set {                  /* Read set */
  r_entry_t *entries;                   /* Array of entries */
  unsigned int nb_entries;              /* Number of entries */
  unsigned int size;                    /* Size of array */
} r_set_t;

typedef struct w_entry {                /* Write set entry */
  union {                               /* For padding... */
    struct {
      volatile stm_word_t *addr;        /* Address written */
      stm_word_t value;                 /* New (write-back) or old (write-through) value */
      stm_word_t mask;                  /* Write mask */
      stm_word_t version;               /* Version overwritten */
      volatile stm_word_t *lock;        /* Pointer to lock (for fast access) */
#if CM == CM_MODULAR || defined(CONFLICT_TRACKING)
      struct stm_tx *tx;                /* Transaction owning the write set */
#endif /* CM == CM_MODULAR || defined(CONFLICT_TRACKING) */
      union {
        struct w_entry *next;           /* WRITE_BACK_ETL || WRITE_THROUGH: Next address covered by same lock (if any) */
        stm_word_t no_drop;             /* WRITE_BACK_CTL: Should we drop lock upon abort? */
      };
    };
    char padding[CACHELINE_SIZE];       /* Padding (multiple of a cache line) */
    /* Note padding is not useful here as long as the address can be defined in the lock scheme. */
  };
} w_entry_t;

typedef struct w_set {                  /* Write set */
  w_entry_t *entries;                   /* Array of entries */
  unsigned int nb_entries;              /* Number of entries */
  unsigned int size;                    /* Size of array */
  union {
    unsigned int has_writes;            /* WRITE_BACK_ETL: Has the write set any real write (vs. visible reads) */
    unsigned int nb_acquired;           /* WRITE_BACK_CTL: Number of locks acquired */
  };
#ifdef USE_BLOOM_FILTER
  stm_word_t bloom;                     /* WRITE_BACK_CTL: Same Bloom filter as in TL2 */
#endif /* USE_BLOOM_FILTER */
} w_set_t;

typedef struct cb_entry {               /* Callback entry */
  void (*f)(void *);                    /* Function */
  void *arg;                            /* Argument to be passed to function */
} cb_entry_t;

typedef struct stm_tx {                 /* Transaction descriptor */
  JMP_BUF* env;                          /* Environment for setjmp/longjmp */
  stm_tx_attr_t attr;                   /* Transaction attributes (user-specified) */
  volatile stm_word_t status;           /* Transaction status */
  stm_word_t start;                     /* Start timestamp */
  stm_word_t end;                       /* End timestamp (validity range) */
  r_set_t r_set;                        /* Read set */
  w_set_t w_set;                        /* Write set */
#ifdef IRREVOCABLE_ENABLED
  unsigned int irrevocable:4;           /* Is this execution irrevocable? */
#endif /* IRREVOCABLE_ENABLED */
  unsigned int nesting;                 /* Nesting level */
#if CM == CM_MODULAR
  stm_word_t timestamp;                 /* Timestamp (not changed upon restart) */
#endif /* CM == CM_MODULAR */
  void *data[MAX_SPECIFIC];             /* Transaction-specific data (fixed-size array for better speed) */
  struct stm_tx *next;                  /* For keeping track of all transactional threads */
#ifdef CONFLICT_TRACKING
  pthread_t thread_id;                  /* Thread identifier (immutable) */
#endif /* CONFLICT_TRACKING */
#if CM == CM_DELAY || CM == CM_MODULAR
  volatile stm_word_t *c_lock;          /* Pointer to contented lock (cause of abort) */
#endif /* CM == CM_DELAY || CM == CM_MODULAR */
#if CM == CM_BACKOFF
  unsigned long backoff;                /* Maximum backoff duration */
  unsigned long seed;                   /* RNG seed */
#endif /* CM == CM_BACKOFF */
#if CM == CM_MODULAR
  int visible_reads;                    /* Should we use visible reads? */
#endif /* CM == CM_MODULAR */
#if CM == CM_MODULAR || defined(TM_STATISTICS)
  unsigned int stat_retries;            /* Number of consecutive aborts (retries) */
#endif /* CM == CM_MODULAR || defined(TM_STATISTICS) */
#ifdef TM_STATISTICS
  unsigned long long stat_commits;            /* Total number of commits (cumulative) */
  unsigned long long stat_aborts;             /* Total number of aborts (cumulative) */
  unsigned long long stat_retries_max;        /* Maximum number of consecutive aborts (retries) */
  /*tarlovsky*/
  unsigned long stat_val_fail;
  unsigned long stat_val_succ;
  double val_time;                      /* total validation time this thread did time to validate */
  atomic_ulong val_reads;         /* at least 64 bits */

#endif /* TM_STATISTICS */
#ifdef TM_STATISTICS2
  unsigned int stat_aborts_1;           /* Total number of transactions that abort once or more (cumulative) */
  unsigned int stat_aborts_2;           /* Total number of transactions that abort twice or more (cumulative) */
  unsigned int stat_aborts_r[16];       /* Total number of transactions that abort wrt. abort reason (cumulative) */
# ifdef READ_LOCKED_DATA
  unsigned int stat_locked_reads_ok;    /* Successful reads of previous value */
  unsigned int stat_locked_reads_failed;/* Failed reads of previous value */
# endif /* READ_LOCKED_DATA */
#endif /* TM_STATISTICS2 */
    atomic_int tid;

    pthread_t val_threads[VALTHREADS];
    pthread_attr_t val_attr;

    pthread_mutex_t validate_mutex;
    pthread_cond_t validate_cond;
    pthread_mutex_t finished_validating_mutex;
    pthread_cond_t finished_validating_cond;
    pthread_cond_t worker_done_cond;

    atomic_int currently_validating;
    atomic_int start_validate;
    atomic_int valid;
    atomic_int workers_valid;
    atomic_int val_finish;

    long val_chunk;
    long val_last_chunk_diff;
    struct val_thread_data *val_data;

} stm_tx_t;

struct val_thread_data {
    stm_tx_t* tx;
    unsigned int val_worker_id;
};

/* This structure should be ordered by hot and cold variables */
typedef struct {
  volatile stm_word_t locks[LOCK_ARRAY_SIZE] ALIGNED;
  volatile stm_word_t gclock[512 / sizeof(stm_word_t)] ALIGNED;
  unsigned int nb_specific;             /* Number of specific slots used (<= MAX_SPECIFIC) */
  unsigned int nb_init_cb;
  cb_entry_t init_cb[MAX_CB];           /* Init thread callbacks */
  unsigned int nb_exit_cb;
  cb_entry_t exit_cb[MAX_CB];           /* Exit thread callbacks */
  unsigned int nb_start_cb;
  cb_entry_t start_cb[MAX_CB];          /* Start callbacks */
  unsigned int nb_precommit_cb;
  cb_entry_t precommit_cb[MAX_CB];      /* Commit callbacks */
  unsigned int nb_commit_cb;
  cb_entry_t commit_cb[MAX_CB];         /* Commit callbacks */
  unsigned int nb_abort_cb;
  cb_entry_t abort_cb[MAX_CB];          /* Abort callbacks */
  unsigned int initialized;             /* Has the library been initialized? */
#ifdef IRREVOCABLE_ENABLED
  volatile stm_word_t irrevocable;      /* Irrevocability status */
#endif /* IRREVOCABLE_ENABLED */
  volatile stm_word_t quiesce;          /* Prevent threads from entering transactions upon quiescence */
  volatile stm_word_t threads_nb;       /* Number of active threads */
  stm_tx_t *threads;                    /* Head of linked list of threads */
  pthread_mutex_t quiesce_mutex;        /* Mutex to support quiescence */
  pthread_cond_t quiesce_cond;          /* Condition variable to support quiescence */
#if CM == CM_MODULAR
  int vr_threshold;                     /* Number of retries before to switch to visible reads. */
#endif /* CM == CM_MODULAR */
#ifdef CONFLICT_TRACKING
  void (*conflict_cb)(stm_tx_t *, stm_tx_t *);
#endif /* CONFLICT_TRACKING */
#if CM == CM_MODULAR
  int (*contention_manager)(stm_tx_t *, stm_tx_t *, int);
#endif /* CM == CM_MODULAR */
  atomic_int global_tid;
  /* At least twice a cache line (256 bytes to be on the safe side) */
  char padding[CACHELINE_SIZE];
} ALIGNED global_t;

extern global_t _tinystm;



#if CM == CM_MODULAR
# define KILL_SELF                      0x00
# define KILL_OTHER                     0x01
# define DELAY_RESTART                  0x04

# define RR_CONFLICT                    0x00
# define RW_CONFLICT                    0x01
# define WR_CONFLICT                    0x02
# define WW_CONFLICT                    0x03
#endif /* CM == CM_MODULAR */

/* ################################################################### *
 * FUNCTIONS DECLARATIONS
 * ################################################################### */

static NOINLINE void
stm_rollback(stm_tx_t *tx, unsigned int reason);


/* ################################################################### *
 * INLINE FUNCTIONS
 * ################################################################### */

#ifdef LOCK_IDX_SWAP
/*
 * Compute index in lock table (swap bytes to avoid consecutive addresses to have neighboring locks).
 */
static INLINE unsigned int
lock_idx_swap(unsigned int idx)
{
  return (idx & ~(unsigned int)0xFFFF) | ((idx & 0x00FF) << 8) | ((idx & 0xFF00) >> 8);
}
#endif /* LOCK_IDX_SWAP */

/*
 * Bind Thread
 * */
static int stm1[8]={1,5,2,6,3,7,0,4};
static int stm2_2[2][2]={{4,6},{5,7}};
static int stm2_4_8[2][4]={{0,2,4,6},{1,3,5,7}};

static void bindWorkerThread(int worker_id) {
    /* we know that SKL is 4c-8th */
    /* try not set in your own thread IF: THREADS_TOT < 2*/
    /* cannot place on my own core:
     *
     *
     */
    cpu_set_t cpuset;
    pthread_getaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
    int tx_core = -1;
    for(int i = 0; i < 8; i++){ /*only way of getting current cpu*/
        if(CPU_ISSET(i, &cpuset)){
            tx_core=i;
            break;
        }
    }
    //int cs = (worker_id * _tinystm.global_tid + VALTHREADS + tx_core) % 8;

    int cs;
    if(_tinystm.global_tid == 1){
        /*if 1 stm thread*/
        cs = stm1[worker_id];
    }else if(_tinystm.global_tid == 2){
        /*if 2 stm threads*/
        if(VALTHREADS == 2){
            cs = stm2_2[tx_core][worker_id];
        }else{
            cs = stm2_4_8[tx_core][worker_id % 4];
        }
    }else if(VALTHREADS == 8 && _tinystm.global_tid == 8){
        /* map them to the same logical core because you want some degree of parallelism between transactions,
         * because you want them to discover they must abort as soon as possible. */
        cs = tx_core;
    }else{
        /* if 4,8 stm threads */
        /*Even workers -> core 0,1,2,4; odd workers -> core 4,5,6,7*/
        /*lay out worker_id's on the same core when processor
         * going to be full of stm threads and worker threads anyway.*/
        /* cpu full with 4,2 4,4 4,8; 8,2 8,4 8,8; (stm threads, workers) respectively*/
        /* cpu has 8 hyper-threaded cores*/
        /* might as well not interleave/mix them, and keep them on the same core for L1/L2 cache locality*/
        cs = ((4*(worker_id % 2)+tx_core)%8);
        //printf("%d\n", cs);
    }

    //printf("%d %d ASSIGNMENT:%d\n", tx_core, worker_id, cs);
    CPU_ZERO(&cpuset);
    CPU_SET(cs, &cpuset);
    sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
}

/*
 * Initialize quiescence support.
 */
static INLINE void
stm_quiesce_init(void)
{
  PRINT_DEBUG("==> stm_quiesce_init()\n");

  if (pthread_mutex_init(&_tinystm.quiesce_mutex, NULL) != 0) {
    fprintf(stderr, "Error creating mutex\n");
    exit(1);
  }
  if (pthread_cond_init(&_tinystm.quiesce_cond, NULL) != 0) {
    fprintf(stderr, "Error creating condition variable\n");
    exit(1);
  }
  _tinystm.quiesce = 0;
  _tinystm.threads_nb = 0;
  _tinystm.threads = NULL;
}

/*
 * Clean up quiescence support.
 */
static INLINE void
stm_quiesce_exit(void)
{
  PRINT_DEBUG("==> stm_quiesce_exit()\n");

  pthread_cond_destroy(&_tinystm.quiesce_cond);
  pthread_mutex_destroy(&_tinystm.quiesce_mutex);
}

/*
 * Called by each thread upon initialization for quiescence support.
 */
static INLINE void
stm_quiesce_enter_thread(stm_tx_t *tx)
{
  PRINT_DEBUG("==> stm_quiesce_enter_thread(%p)\n", tx);

  pthread_mutex_lock(&_tinystm.quiesce_mutex);
  /* Add new descriptor at head of list */
  tx->next = _tinystm.threads;
  _tinystm.threads = tx;
  _tinystm.threads_nb++;
  pthread_mutex_unlock(&_tinystm.quiesce_mutex);
}

/*
 * Called by each thread upon exit for quiescence support.
 */
static INLINE void
stm_quiesce_exit_thread(stm_tx_t *tx)
{
  stm_tx_t *t, *p;

  PRINT_DEBUG("==> stm_quiesce_exit_thread(%p)\n", tx);

  /* Can only be called if non-active */
  assert(!IS_ACTIVE(tx->status));

  pthread_mutex_lock(&_tinystm.quiesce_mutex);
  /* Remove descriptor from list */
  p = NULL;
  t = _tinystm.threads;
  while (t != tx) {
    assert(t != NULL);
    p = t;
    t = t->next;
  }
  if (p == NULL)
    _tinystm.threads = t->next;
  else
    p->next = t->next;
  _tinystm.threads_nb--;
  if (_tinystm.quiesce) {
    /* Wake up someone in case other threads are waiting for us */
    pthread_cond_signal(&_tinystm.quiesce_cond);
  }
  pthread_mutex_unlock(&_tinystm.quiesce_mutex);
}

/*
 * Wait for all transactions to be block on a barrier.
 */
static NOINLINE void
stm_quiesce_barrier(stm_tx_t *tx, void (*f)(void *), void *arg)
{
  PRINT_DEBUG("==> stm_quiesce_barrier()\n");

  /* Can only be called if non-active */
  assert(tx == NULL || !IS_ACTIVE(tx->status));

  pthread_mutex_lock(&_tinystm.quiesce_mutex);
  /* Wait for all other transactions to block on barrier */
  _tinystm.threads_nb--;
  if (_tinystm.quiesce == 0) {
    /* We are first on the barrier */
    _tinystm.quiesce = 1;
  }
  while (_tinystm.quiesce) {
    if (_tinystm.threads_nb == 0) {
      /* Everybody is blocked */
      if (f != NULL)
        f(arg);
      /* Release transactional threads */
      _tinystm.quiesce = 0;
      pthread_cond_broadcast(&_tinystm.quiesce_cond);
    } else {
      /* Wait for other transactions to stop */
      pthread_cond_wait(&_tinystm.quiesce_cond, &_tinystm.quiesce_mutex);
    }
  }
  _tinystm.threads_nb++;
  pthread_mutex_unlock(&_tinystm.quiesce_mutex);
}

/*
 * Wait for all transactions to be out of their current transaction.
 */
static INLINE int
stm_quiesce(stm_tx_t *tx, int block)
{
  stm_tx_t *t;
#if CM == CM_MODULAR
  stm_word_t s, c;
#endif /* CM == CM_MODULAR */

  PRINT_DEBUG("==> stm_quiesce(%p,%d)\n", tx, block);

  if (IS_ACTIVE(tx->status)) {
    /* Only one active transaction can quiesce at a time, others must abort */
    if (pthread_mutex_trylock(&_tinystm.quiesce_mutex) != 0)
      return 1;
  } else {
    /* We can safely block because we are inactive */
    pthread_mutex_lock(&_tinystm.quiesce_mutex);
  }
  /* We own the lock at this point */
  if (block)
    ATOMIC_STORE_REL(&_tinystm.quiesce, 2);
  /* Make sure we read latest status data */
  ATOMIC_MB_FULL;
  /* Not optimal as we check transaction sequentially and might miss some inactivity states */
  for (t = _tinystm.threads; t != NULL; t = t->next) {
    if (t == tx)
      continue;
    /* Wait for all other transactions to become inactive */
#if CM == CM_MODULAR
    s = t->status;
    if (IS_ACTIVE(s)) {
      c = GET_STATUS_COUNTER(s);
      do {
        s = t->status;
      } while (IS_ACTIVE(s) && c == GET_STATUS_COUNTER(s));
    }
#else /* CM != CM_MODULAR */
    while (IS_ACTIVE(t->status))
      ;
#endif /* CM != CM_MODULAR */
  }
  if (!block)
    pthread_mutex_unlock(&_tinystm.quiesce_mutex);
  return 0;
}

/*
 * Check if transaction must block.
 */
static INLINE int
stm_check_quiesce(stm_tx_t *tx)
{
  stm_word_t s;

  /* Must be called upon start (while already active but before acquiring any lock) */
  assert(IS_ACTIVE(tx->status));

  /* ATOMIC_MB_FULL;  The full memory barrier is not required here since quiesce
   * is atomic. Only a compiler barrier is needed to avoid reordering. */
  ATOMIC_CB;

  if (unlikely(ATOMIC_LOAD_ACQ(&_tinystm.quiesce) == 2)) {
#ifdef IRREVOCABLE_ENABLED
    /* Only test it when quiesce == 2, it avoids one comparison for fast-path. */
    /* TODO check if it is correct. */
    if (unlikely((tx->irrevocable & 0x08) != 0)) {
      /* Serial irrevocable mode: we are executing alone */
      return 0;
    }
#endif /* IRREVOCABLE_ENABLED */
    s = ATOMIC_LOAD(&tx->status);
    SET_STATUS(tx->status, TX_IDLE);
    while (ATOMIC_LOAD_ACQ(&_tinystm.quiesce) == 2) {
#ifdef WAIT_YIELD
      sched_yield();
#endif /* WAIT_YIELD */
    }
    SET_STATUS(tx->status, GET_STATUS(s));
    return 1;
  }
  return 0;
}

/*
 * Release threads blocked after quiescence.
 */
static INLINE void
stm_quiesce_release(stm_tx_t *tx)
{
  ATOMIC_STORE_REL(&_tinystm.quiesce, 0);
  pthread_mutex_unlock(&_tinystm.quiesce_mutex);
}

/*
 * Reset clock and timestamps
 */
static INLINE void
rollover_clock(void *arg)
{
  PRINT_DEBUG("==> rollover_clock()\n");

  /* Reset clock */
  CLOCK = 0;
  /* Reset timestamps */
  memset((void *)_tinystm.locks, 0, LOCK_ARRAY_SIZE * sizeof(stm_word_t));
# ifdef EPOCH_GC
  /* Reset GC */
  gc_reset();
# endif /* EPOCH_GC */
}

/*
 * Check if stripe has been read previously.
 */
static INLINE r_entry_t *
stm_has_read(stm_tx_t *tx, volatile stm_word_t *lock)
{
  r_entry_t *r;
  int i;

  PRINT_DEBUG("==> stm_has_read(%p[%lu-%lu],%p)\n", tx, (unsigned long)tx->start, (unsigned long)tx->end, lock);

#if CM == CM_MODULAR
  /* TODO case of visible read is not handled */
#endif /* CM == CM_MODULAR */

  /* Look for read */
  r = tx->r_set.entries;
  for (i = tx->r_set.nb_entries; i > 0; i--, r++) {
    if (r->lock == lock) {
      /* Return first match*/
      return r;
    }
  }
  return NULL;
}

/*
 * Check if address has been written previously.
 */
static INLINE w_entry_t *
stm_has_written(stm_tx_t *tx, volatile stm_word_t *addr)
{
  w_entry_t *w;
  int i;
# ifdef USE_BLOOM_FILTER
  stm_word_t mask;
# endif /* USE_BLOOM_FILTER */

  PRINT_DEBUG("==> stm_has_written(%p[%lu-%lu],%p)\n", tx, (unsigned long)tx->start, (unsigned long)tx->end, addr);

# ifdef USE_BLOOM_FILTER
  mask = FILTER_BITS(addr);
  if ((tx->w_set.bloom & mask) != mask)
    return NULL;
# endif /* USE_BLOOM_FILTER */

  /* Look for write */
  w = tx->w_set.entries;
  for (i = tx->w_set.nb_entries; i > 0; i--, w++) {
    if (w->addr == addr) {
      return w;
    }
  }
  return NULL;
}

/*
 * (Re)allocate read set entries.
 */
static NOINLINE void
stm_allocate_rs_entries(stm_tx_t *tx, int extend)
{
  PRINT_DEBUG("==> stm_allocate_rs_entries(%p[%lu-%lu],%d)\n", tx, (unsigned long)tx->start, (unsigned long)tx->end, extend);

  if (extend) {
    /* Extend read set */
    tx->r_set.size *= 2;
    if ((tx->r_set.entries = (r_entry_t *)realloc(tx->r_set.entries, tx->r_set.size * sizeof(r_entry_t))) == NULL) {
      perror("realloc read set");
      exit(1);
    }
  } else {
    /* Allocate read set */
    if ((tx->r_set.entries = (r_entry_t *)xmalloc(tx->r_set.size * sizeof(r_entry_t))) == NULL) {
      perror("malloc read set");
      exit(1);
    }
  }
}

/*
 * (Re)allocate write set entries.
 */
static NOINLINE void
stm_allocate_ws_entries(stm_tx_t *tx, int extend)
{
#if CM == CM_MODULAR || defined(CONFLICT_TRACKING)
  int i, first = (extend ? tx->w_set.size : 0);
#endif /* CM == CM_MODULAR || defined(CONFLICT_TRACKING) */

  PRINT_DEBUG("==> stm_allocate_ws_entries(%p[%lu-%lu],%d)\n", tx, (unsigned long)tx->start, (unsigned long)tx->end, extend);

  if (extend) {
    /* Extend write set */
    /* Transaction must be inactive for WRITE_THROUGH or WRITE_BACK_ETL */
    tx->w_set.size *= 2;
    if (unlikely((tx->w_set.entries = (w_entry_t *)realloc(tx->w_set.entries, tx->w_set.size * sizeof(w_entry_t))) == NULL)) {
      perror("realloc write set");
      exit(1);
    }
  } else {
    /* Allocate write set */
    if (unlikely((tx->w_set.entries = (w_entry_t *)xmalloc(tx->w_set.size * sizeof(w_entry_t))) == NULL)) {
      perror("malloc write set");
      exit(1);
    }
  }
  /* Ensure that memory is aligned. */
  assert((((stm_word_t)tx->w_set.entries) & OWNED_MASK) == 0);

#if CM == CM_MODULAR || defined(CONFLICT_TRACKING)
  /* Initialize fields */
  for (i = first; i < tx->w_set.size; i++)
    tx->w_set.entries[i].tx = tx;
#endif /* CM == CM_MODULAR || defined(CONFLICT_TRACKING) */
}


#if DESIGN == WRITE_BACK_ETL
# include "stm_wbetl.h"
#elif DESIGN == WRITE_BACK_CTL
# include "stm_wbctl.h"
#elif DESIGN == WRITE_THROUGH
# include "stm_wt.h"
#elif DESIGN == MODULAR
# include "stm_wbetl.h"
# include "stm_wbctl.h"
# include "stm_wt.h"
#endif /* DESIGN == MODULAR */

#if CM == CM_MODULAR
/*
 * Kill other transaction.
 */
static NOINLINE int
stm_kill(stm_tx_t *tx, stm_tx_t *other, stm_word_t status)
{
  stm_word_t c, t;

  PRINT_DEBUG("==> stm_kill(%p[%lu-%lu],%p,s=%d)\n", tx, (unsigned long)tx->start, (unsigned long)tx->end, other, status);

# ifdef CONFLICT_TRACKING
  if (_tinystm.conflict_cb != NULL)
    _tinystm.conflict_cb(tx, other);
# endif /* CONFLICT_TRACKING */

# ifdef IRREVOCABLE_ENABLED
  if (GET_STATUS(status) == TX_IRREVOCABLE)
    return 0;
# endif /* IRREVOCABLE_ENABLED */
  if (GET_STATUS(status) == TX_ABORTED || GET_STATUS(status) == TX_COMMITTED || GET_STATUS(status) == TX_KILLED || GET_STATUS(status) == TX_IDLE)
    return 0;
  if (GET_STATUS(status) == TX_ABORTING || GET_STATUS(status) == TX_COMMITTING) {
    /* Transaction is already aborting or committing: wait */
    while (other->status == status)
      ;
    return 0;
  }
  assert(IS_ACTIVE(status));
  /* Set status to KILLED */
  if (ATOMIC_CAS_FULL(&other->status, status, status + (TX_KILLED - TX_ACTIVE)) == 0) {
    /* Transaction is committing/aborting (or has committed/aborted) */
    c = GET_STATUS_COUNTER(status);
    do {
      t = other->status;
# ifdef IRREVOCABLE_ENABLED
      if (GET_STATUS(t) == TX_IRREVOCABLE)
        return 0;
# endif /* IRREVOCABLE_ENABLED */
    } while (GET_STATUS(t) != TX_ABORTED && GET_STATUS(t) != TX_COMMITTED && GET_STATUS(t) != TX_KILLED && GET_STATUS(t) != TX_IDLE && GET_STATUS_COUNTER(t) == c);
    return 0;
  }
  /* We have killed the transaction: we can steal the lock */
  return 1;
}

/*
 * Drop locks after having been killed.
 */
static NOINLINE void
stm_drop(stm_tx_t *tx)
{
  w_entry_t *w;
  stm_word_t l;
  int i;

  PRINT_DEBUG("==> stm_drop(%p[%lu-%lu])\n", tx, (unsigned long)tx->start, (unsigned long)tx->end);

  /* Drop locks */
  i = tx->w_set.nb_entries;
  if (i > 0) {
    w = tx->w_set.entries;
    for (; i > 0; i--, w++) {
      l = ATOMIC_LOAD_ACQ(w->lock);
      if (LOCK_GET_OWNED(l) && (w_entry_t *)LOCK_GET_ADDR(l) == w) {
        /* Drop using CAS */
        ATOMIC_CAS_FULL(w->lock, l, LOCK_SET_TIMESTAMP(w->version));
        /* If CAS fail, lock has been stolen or already released in case a lock covers multiple addresses */
      }
    }
    /* We need to reallocate the write set to avoid an ABA problem (the
     * transaction could reuse the same entry after having been killed
     * and restarted, and another slow transaction could steal the lock
     * using CAS without noticing the restart) */
    gc_free(tx->w_set.entries, tx->start);
    stm_allocate_ws_entries(tx, 0);
  }
}
#endif /* CM == CM_MODULAR */

/*
 * Initialize the transaction descriptor before start or restart.
 */
static INLINE void
int_stm_prepare(stm_tx_t *tx)
{
#if CM == CM_MODULAR
  if (tx->attr.visible_reads || (tx->visible_reads >= _tinystm.vr_threshold && _tinystm.vr_threshold >= 0)) {
    /* Use visible read */
    tx->attr.visible_reads = 1;
    tx->attr.read_only = 0;
  }
#endif /* CM == CM_MODULAR */

  /* Read/write set */
  /* has_writes / nb_acquired are the same field. */
  tx->w_set.has_writes = 0;
  /* tx->w_set.nb_acquired = 0; */
#ifdef USE_BLOOM_FILTER
  tx->w_set.bloom = 0;
#endif /* USE_BLOOM_FILTER */
  tx->w_set.nb_entries = 0;
  tx->r_set.nb_entries = 0;

 start:
  /* Start timestamp */
  tx->start = tx->end = GET_CLOCK; /* OPT: Could be delayed until first read/write */
  if (unlikely(tx->start >= VERSION_MAX)) {
    /* Block all transactions and reset clock */
    stm_quiesce_barrier(tx, rollover_clock, NULL);
    goto start;
  }
#if CM == CM_MODULAR
  if (tx->stat_retries == 0)
    tx->timestamp = tx->start;
#endif /* CM == CM_MODULAR */

#ifdef EPOCH_GC
  gc_set_epoch(tx->start);
#endif /* EPOCH_GC */

#ifdef IRREVOCABLE_ENABLED
  if (unlikely(tx->irrevocable != 0)) {
    assert(!IS_ACTIVE(tx->status));
    stm_set_irrevocable_tx(tx, -1);
    UPDATE_STATUS(tx->status, TX_IRREVOCABLE);
  } else
    UPDATE_STATUS(tx->status, TX_ACTIVE);
#else /* ! IRREVOCABLE_ENABLED */
  /* Set status */
  UPDATE_STATUS(tx->status, TX_ACTIVE);
#endif /* ! IRREVOCABLE_ENABLED */

  stm_check_quiesce(tx);
}

/*
 * Rollback transaction.
 */
static NOINLINE void
stm_rollback(stm_tx_t *tx, unsigned int reason)
{
#if CM == CM_BACKOFF
  unsigned long wait;
  volatile int j;
#endif /* CM == CM_BACKOFF */
#if CM == CM_MODULAR
  stm_word_t t;
#endif /* CM == CM_MODULAR */

  PRINT_DEBUG("==> stm_rollback(%p[%lu-%lu])\n", tx, (unsigned long)tx->start, (unsigned long)tx->end);

  assert(IS_ACTIVE(tx->status));

#ifdef IRREVOCABLE_ENABLED
  /* Irrevocable cannot abort */
  assert((tx->irrevocable & 0x07) != 3);
#endif /* IRREVOCABLE_ENABLED */

#if CM == CM_MODULAR
  /* Set status to ABORTING */
  t = tx->status;
  if (GET_STATUS(t) == TX_KILLED || (GET_STATUS(t) == TX_ACTIVE && ATOMIC_CAS_FULL(&tx->status, t, t + (TX_ABORTING - TX_ACTIVE)) == 0)) {
    /* We have been killed */
    assert(GET_STATUS(tx->status) == TX_KILLED);
    /* Release locks */
    stm_drop(tx);
    goto dropped;
  }
#endif /* CM == CM_MODULAR */

#if DESIGN == WRITE_BACK_ETL
  stm_wbetl_rollback(tx);
#elif DESIGN == WRITE_BACK_CTL
  stm_wbctl_rollback(tx);
#elif DESIGN == WRITE_THROUGH
  stm_wt_rollback(tx);
#elif DESIGN == MODULAR
  if (tx->attr.id == WRITE_BACK_CTL)
    stm_wbctl_rollback(tx);
  else if (tx->attr.id == WRITE_THROUGH)
    stm_wt_rollback(tx);
  else
    stm_wbetl_rollback(tx);
#endif /* DESIGN == MODULAR */

#if CM == CM_MODULAR
 dropped:
#endif /* CM == CM_MODULAR */

#if CM == CM_MODULAR || defined(TM_STATISTICS)
  tx->stat_retries++;
#endif /* CM == CM_MODULAR || defined(TM_STATISTICS) */
#ifdef TM_STATISTICS
  tx->stat_aborts++;
  if (tx->stat_retries_max < tx->stat_retries)
    tx->stat_retries_max = tx->stat_retries;
#endif /* TM_STATISTICS */
#ifdef TM_STATISTICS2
  /* Aborts stats wrt reason */
  tx->stat_aborts_r[(reason >> 8) & 0x0F]++;
  if (tx->stat_retries == 1)
    tx->stat_aborts_1++;
  else if (tx->stat_retries == 2)
    tx->stat_aborts_2++;
#endif /* TM_STATISTICS2 */

  /* Set status to ABORTED */
  SET_STATUS(tx->status, TX_ABORTED);

  /* Abort for extending the write set */
  if (unlikely(reason == STM_ABORT_EXTEND_WS)) {
    stm_allocate_ws_entries(tx, 1);
  }

  /* Reset nesting level */
  tx->nesting = 1;

  /* Callbacks */
  if (likely(_tinystm.nb_abort_cb != 0)) {
    unsigned int cb;
    for (cb = 0; cb < _tinystm.nb_abort_cb; cb++)
      _tinystm.abort_cb[cb].f(_tinystm.abort_cb[cb].arg);
  }

#if CM == CM_BACKOFF
  /* Simple RNG (good enough for backoff) */
  tx->seed ^= (tx->seed << 17);
  tx->seed ^= (tx->seed >> 13);
  tx->seed ^= (tx->seed << 5);
  wait = tx->seed % tx->backoff;
  for (j = 0; j < wait; j++) {
    /* Do nothing */
  }
  if (tx->backoff < MAX_BACKOFF)
    tx->backoff <<= 1;
#endif /* CM == CM_BACKOFF */

#if CM == CM_DELAY || CM == CM_MODULAR
  /* Wait until contented lock is free */
  if (tx->c_lock != NULL) {
    /* Busy waiting (yielding is expensive) */
    while (LOCK_GET_OWNED(ATOMIC_LOAD(tx->c_lock))) {
# ifdef WAIT_YIELD
      sched_yield();
# endif /* WAIT_YIELD */
    }
    tx->c_lock = NULL;
  }
#endif /* CM == CM_DELAY || CM == CM_MODULAR */

  /* Don't prepare a new transaction if no retry. */
  if (tx->attr.no_retry || (reason & STM_ABORT_NO_RETRY) == STM_ABORT_NO_RETRY) {
    tx->nesting = 0;
    return;
  }

  /* Reset field to restart transaction */
  int_stm_prepare(tx);

  /* Jump back to transaction start */
  /* Note: ABI usually requires 0x09 (runInstrumented+restoreLiveVariable) */
#ifdef IRREVOCABLE_ENABLED
  /* If the transaction is serial irrevocable, indicate that uninstrumented
   * code path must be executed (mixing instrumented and uninstrumented
   * accesses are not allowed) */
  reason |= (tx->irrevocable == 0x0B) ? STM_PATH_UNINSTRUMENTED : STM_PATH_INSTRUMENTED;
#else /* ! IRREVOCABLE_ENABLED */
  reason |= STM_PATH_INSTRUMENTED;
#endif /* ! IRREVOCABLE_ENABLED */
  LONGJMP(*tx->env, reason);
}

/*
 * Store a word-sized value (return write set entry or NULL).
 */
static INLINE w_entry_t *
stm_write(stm_tx_t *tx, volatile stm_word_t *addr, stm_word_t value, stm_word_t mask)
{
  w_entry_t *w;

  PRINT_DEBUG2("==> stm_write(t=%p[%lu-%lu],a=%p,d=%p-%lu,m=0x%lx)\n",
               tx, (unsigned long)tx->start, (unsigned long)tx->end, addr, (void *)value, (unsigned long)value, (unsigned long)mask);

#if CM == CM_MODULAR
  if (GET_STATUS(tx->status) == TX_KILLED) {
    stm_rollback(tx, STM_ABORT_KILLED);
    return NULL;
  }
#else /* CM != CM_MODULAR */
  assert(IS_ACTIVE(tx->status));
#endif /* CM != CM_MODULAR */

#ifdef DEBUG
  /* Check consistency with read_only attribute. */
  assert(!tx->attr.read_only);
#endif /* DEBUG */

#if DESIGN == WRITE_BACK_ETL
  w = stm_wbetl_write(tx, addr, value, mask);
#elif DESIGN == WRITE_BACK_CTL
  w = stm_wbctl_write(tx, addr, value, mask);
#elif DESIGN == WRITE_THROUGH
  w = stm_wt_write(tx, addr, value, mask);
#elif DESIGN == MODULAR
  if (tx->attr.id == WRITE_BACK_CTL)
    w = stm_wbctl_write(tx, addr, value, mask);
  else if (tx->attr.id == WRITE_THROUGH)
    w = stm_wt_write(tx, addr, value, mask);
  else
    w = stm_wbetl_write(tx, addr, value, mask);
#endif /* DESIGN == WRITE_THROUGH */

  return w;
}

static INLINE stm_word_t
int_stm_RaR(stm_tx_t *tx, volatile stm_word_t *addr)
{
  stm_word_t value;
#if DESIGN == WRITE_BACK_ETL
  value = stm_wbetl_RaR(tx, addr);
#elif DESIGN == WRITE_BACK_CTL
  value = stm_wbctl_RaR(tx, addr);
#elif DESIGN == WRITE_THROUGH
  value = stm_wt_RaR(tx, addr);
#endif /* DESIGN == WRITE_THROUGH */
  return value;
}

static INLINE stm_word_t
int_stm_RaW(stm_tx_t *tx, volatile stm_word_t *addr)
{
  stm_word_t value;
#if DESIGN == WRITE_BACK_ETL
  value = stm_wbetl_RaW(tx, addr);
#elif DESIGN == WRITE_BACK_CTL
  value = stm_wbctl_RaW(tx, addr);
#elif DESIGN == WRITE_THROUGH
  value = stm_wt_RaW(tx, addr);
#endif /* DESIGN == WRITE_THROUGH */
  return value;
}

static INLINE stm_word_t
int_stm_RfW(stm_tx_t *tx, volatile stm_word_t *addr)
{
  stm_word_t value;
#if DESIGN == WRITE_BACK_ETL
  value = stm_wbetl_RfW(tx, addr);
#elif DESIGN == WRITE_BACK_CTL
  value = stm_wbctl_RfW(tx, addr);
#elif DESIGN == WRITE_THROUGH
  value = stm_wt_RfW(tx, addr);
#endif /* DESIGN == WRITE_THROUGH */
  return value;
}

static INLINE void
int_stm_WaR(stm_tx_t *tx, volatile stm_word_t *addr, stm_word_t value, stm_word_t mask)
{
#if DESIGN == WRITE_BACK_ETL
  stm_wbetl_WaR(tx, addr, value, mask);
#elif DESIGN == WRITE_BACK_CTL
  stm_wbctl_WaR(tx, addr, value, mask);
#elif DESIGN == WRITE_THROUGH
  stm_wt_WaR(tx, addr, value, mask);
#endif /* DESIGN == WRITE_THROUGH */
}

static INLINE void
int_stm_WaW(stm_tx_t *tx, volatile stm_word_t *addr, stm_word_t value, stm_word_t mask)
{
#if DESIGN == WRITE_BACK_ETL
  stm_wbetl_WaW(tx, addr, value, mask);
#elif DESIGN == WRITE_BACK_CTL
  stm_wbctl_WaW(tx, addr, value, mask);
#elif DESIGN == WRITE_THROUGH
  stm_wt_WaW(tx, addr, value, mask);
#endif /* DESIGN == WRITE_THROUGH */
}

static void* stm_wbetl_validate_parallel(void *txarg)
{

    struct val_thread_data* data = (struct val_thread_data*) txarg;
    int my_rset_start;
    r_entry_t *r;
    int i, n;
    stm_word_t l;
    w_set_t *ws;
    w_set_t *we;
    int val_reads;
    int Phase = 0;
    stm_tx_t* tx = data->tx;
    int id = data->val_worker_id; /*worker id, not tx id*/

    pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);

    //bindWorkerThread(id);

    //printf("WORKER THREAD %d BELONGING TO %d LAUNCHED\n", id, tx->tid);
    //printf("Thread %d ==> stm_wbetl_validate(%p[%lu-%lu])...tx->n: %d\n", id, data, (unsigned long)data->start, (unsigned long)data->start + n, data->n);

    for(;;){

        pthread_mutex_lock(&tx->validate_mutex);
            /*while phases are equal we sleep*/
            //printf("%d Phase %d, ReqPhase %d\n", id, Phase, tx->start_validate);

            while(Phase == atomic_load_explicit(&tx->start_validate, memory_order_acquire)){
                //printf("%d WAITING, my phase %d\n", id, Phase);

                //printf("Worker %d val_finish:0\n", id);
                //if(tx->val_finish == 1){
                    //printf("%d exiting finishing\n", id);
                    //break;
                    //return "EXITING";
                //}

                pthread_cond_wait(&tx->validate_cond, &tx->validate_mutex);
            }

        pthread_mutex_unlock(&tx->validate_mutex);
        //printf("--Worker %d WOKE UP to work.\n", id);


        val_reads=0;
        n = tx->val_chunk;
        my_rset_start = n * id;
        if(id == VALTHREADS - 1){
            n += tx->val_last_chunk_diff;
        }
        r = (r_entry_t*) (tx->r_set.entries + my_rset_start); /*wind to where your chunk is*/
        ws = tx->w_set.entries;
        we = tx->w_set.entries + tx->w_set.nb_entries;

        //printf("%2d R[%016" PRIXPTR ",  %016" PRIXPTR "] \n", id, r, r+n);

        //printf("%d, %d Phase - validating %lu elements, R[%d,%d]\n", id, Phase, n, my_rset_start, my_rset_start + n);

        for (i = n; i > 0; i--, r++) {
            //printf("worker %d validating\n", id);
            if(&tx->workers_valid < VALTHREADS){
                goto ret;
            }

#ifdef TM_STATISTICS
            val_reads++;
#endif

            l = ATOMIC_LOAD(r->lock);

            if (LOCK_GET_OWNED(l)) {

                w_entry_t *w = (w_entry_t *)LOCK_GET_ADDR(l);

                if (!(ws <= w && w < we)){
#ifdef CONFLICT_TRACKING
                    if (_tinystm.conflict_cb != NULL) {
    # ifdef UNIT_TX
              if (l != LOCK_UNIT) {
    # endif /* UNIT_TX */
                /* Call conflict callback */
                stm_tx_t *other = ((w_entry_t *)LOCK_GET_ADDR(l))->tx;
                _tinystm.conflict_cb(tx, other);
    # ifdef UNIT_TX
              }
    # endif /* UNIT_TX */
            }
#endif /* CONFLICT_TRACKING */
                    /*notify all that read-set is invalid*/
                    atomic_fetch_sub_explicit(&tx->workers_valid, 1, memory_order_relaxed);/*tx invalid*/
                    goto ret;
                }
            } else {
                if (LOCK_GET_TIMESTAMP(l) != r->version) {
                    /*notify all that read-set is invalid*/
                    atomic_fetch_sub_explicit(&tx->workers_valid, 1, memory_order_relaxed);/*tx invalid*/
                    goto ret;
                }
                /* Same version: OK */
            }
        }
        /* if we got here the normal way, then valid. invalid jumps to RET */
        //atomic_fetch_add_explicit(&val_stat_succ, val_reads, memory_order_relaxed);
ret:
        Phase++;
        /*  gather all counters  */
        /*  atomically increment */
        atomic_fetch_add_explicit(&tx->val_reads, val_reads, memory_order_release);
        atomic_fetch_sub_explicit(&tx->currently_validating, 1, memory_order_release);
        //printf("TX %d WORKER THREAD %d VALIDATED: %d\n", tx->tid, id, val_reads);
        /* signal main thread you are finished */
        pthread_mutex_lock(&tx->finished_validating_mutex);

            //printf("%d currently validating %d\n", id, currently_validating);

            pthread_cond_signal(&tx->worker_done_cond);

        pthread_mutex_unlock(&tx->finished_validating_mutex);

    }

    return "VALIDATION_RESULT_IS_GLOBAL";
}

static INLINE stm_tx_t *
int_stm_init_thread(void)
{
  stm_tx_t *tx;

  PRINT_DEBUG("==> stm_init_thread()\n");

  /* Avoid initializing more than once */
  if ((tx = tls_get_tx()) != NULL)
    return tx;

#ifdef EPOCH_GC
  gc_init_thread();
#endif /* EPOCH_GC */

  /* Allocate descriptor */
  if ((tx = (stm_tx_t *)xmalloc(sizeof(stm_tx_t))) == NULL) {
    perror("malloc tx");
    exit(1);
  }

  tx->tid = atomic_fetch_add(&_tinystm.global_tid, 1);

  pthread_attr_init(&tx->val_attr);
  pthread_attr_setdetachstate(&tx->val_attr, PTHREAD_CREATE_JOINABLE);

    /*init all validation global vars to 0*/
  tx->currently_validating = 0;
  tx->start_validate = 0;
  tx->valid = 0;
  tx->workers_valid = 0;
  tx->val_finish = 0;

  pthread_mutex_init(&tx->validate_mutex, NULL);
  pthread_mutex_init(&tx->finished_validating_mutex, NULL);

  pthread_cond_init(&tx->validate_cond, NULL);
  pthread_cond_init(&tx->finished_validating_cond, NULL);
  pthread_cond_init(&tx->worker_done_cond, NULL);

 /* start all VALTHREADS */
  int err=0;
  /*for each validating thread that belongs to this stm_tx_t*/
  tx->val_data = malloc(sizeof(struct val_thread_data) * VALTHREADS);

  //printf("LAUNCHED\n");

  for (int i = 0; i < VALTHREADS; i++){
      tx->val_data[i].tx = tx;
      tx->val_data[i].val_worker_id = i;
      if((err = pthread_create(&tx->val_threads[i], NULL, stm_wbetl_validate_parallel, (void*) &tx->val_data[i])) != 0){
          printf("VALDIATION WORKER PTHREADS ERROR %d\n",err);
      }
      //printf("LAUNCHED\n");
  }

  /* Set attribute */
  tx->attr = (stm_tx_attr_t)0;
  /* Set status (no need for CAS or atomic op) */
  tx->status = TX_IDLE;
  /* Read set */
  tx->r_set.nb_entries = 0;
  tx->r_set.size = RW_SET_SIZE;
  stm_allocate_rs_entries(tx, 0);
  /* Write set */
  tx->w_set.nb_entries = 0;
  tx->w_set.size = RW_SET_SIZE;
  /* has_writes / nb_acquired are the same field. */
  tx->w_set.has_writes = 0;
  /* tx->w_set.nb_acquired = 0; */
#ifdef USE_BLOOM_FILTER
  tx->w_set.bloom = 0;
#endif /* USE_BLOOM_FILTER */
  stm_allocate_ws_entries(tx, 0);
  /* Nesting level */
  tx->nesting = 0;
  /* Transaction-specific data */
  memset(tx->data, 0, MAX_SPECIFIC * sizeof(void *));
#ifdef CONFLICT_TRACKING
  /* Thread identifier */
  tx->thread_id = pthread_self();
#endif /* CONFLICT_TRACKING */
#if CM == CM_DELAY || CM == CM_MODULAR
  /* Contented lock */
  tx->c_lock = NULL;
#endif /* CM == CM_DELAY || CM == CM_MODULAR */
#if CM == CM_BACKOFF
  /* Backoff */
  tx->backoff = MIN_BACKOFF;
  tx->seed = 123456789UL;
#endif /* CM == CM_BACKOFF */
#if CM == CM_MODULAR
  tx->visible_reads = 0;
  tx->timestamp = 0;
#endif /* CM == CM_MODULAR */
#if CM == CM_MODULAR || defined(TM_STATISTICS)
  tx->stat_retries = 0;
#endif /* CM == CM_MODULAR || defined(TM_STATISTICS) */
#ifdef TM_STATISTICS
  /* Statistics */
  tx->stat_commits = 0;
  tx->stat_aborts = 0;

  /*tarlovskyy*/
  tx->val_reads = 0;
  tx->stat_val_succ = 0;
  tx->stat_val_fail = 0;
  tx->val_time = 0.0;

  tx->stat_retries_max = 0;
#endif /* TM_STATISTICS */
#ifdef TM_STATISTICS2
  tx->stat_aborts_1 = 0;
  tx->stat_aborts_2 = 0;
  memset(tx->stat_aborts_r, 0, sizeof(unsigned int) * 16);
# ifdef READ_LOCKED_DATA
  tx->stat_locked_reads_ok = 0;
  tx->stat_locked_reads_failed = 0;
# endif /* READ_LOCKED_DATA */
#endif /* TM_STATISTICS2 */
#ifdef IRREVOCABLE_ENABLED
  tx->irrevocable = 0;
#endif /* IRREVOCABLE_ENABLED */
  /* Store as thread-local data */
  tls_set_tx(tx);
  stm_quiesce_enter_thread(tx);

  /* Callbacks */
  if (likely(_tinystm.nb_init_cb != 0)) {
    unsigned int cb;
    for (cb = 0; cb < _tinystm.nb_init_cb; cb++)
      _tinystm.init_cb[cb].f(_tinystm.init_cb[cb].arg);
  }
  //printf("thread %d created\n", tx->tid);
  return tx;
}

static INLINE void
int_stm_exit_thread(stm_tx_t *tx)
{

#ifdef EPOCH_GC
  stm_word_t t;
#endif /* EPOCH_GC */


  pthread_mutex_lock(&tx->validate_mutex);
        tx->val_finish = 1;
        tx->start_validate = 0;
        //printf("Captured validate_mutex..\n");
        //pthread_cond_broadcast(&tx->validate_cond);
  pthread_mutex_unlock(&tx->validate_mutex);

    /* Wait for thread completion */
  int err;
  for (int i = 0; i < VALTHREADS; i++) {
    //if (pthread_join(tx->val_threads[i], NULL) != 0) {
    if ((err = pthread_cancel(tx->val_threads[i])) != 0) {
      //fprintf(stderr, "Error waiting for thread completion %d\n", err);
      //exit(1);
    }
  }

  free(tx->val_data);

  PRINT_DEBUG("==> stm_exit_thread(%p[%lu-%lu])\n", tx, (unsigned long)tx->start, (unsigned long)tx->end);

  /* Avoid finalizing again a thread */
  if (tx == NULL)
    return;


  /* Callbacks */
  if (likely(_tinystm.nb_exit_cb != 0)) {
    unsigned int cb;
    for (cb = 0; cb < _tinystm.nb_exit_cb; cb++)
      _tinystm.exit_cb[cb].f(_tinystm.exit_cb[cb].arg);
  }

#ifdef TM_STATISTICS
  /* Display statistics before to lose it */
  if (getenv("TM_STATISTICS") != NULL) { /*tarlovskyy commented*/
    double avg_aborts = .0;
    if (tx->stat_commits)
      avg_aborts = (double)tx->stat_aborts / tx->stat_commits;
    //printf("Thread %p | commits:%12u avg_aborts:%12.2f max_retries:%12u validation_time: %12.12f\n", (void *)pthread_self(), tx->stat_commits, avg_aborts, tx->stat_retries_max, tx->val_time);
  }
#endif /* TM_STATISTICS */

  stm_quiesce_exit_thread(tx);

#ifdef EPOCH_GC
  t = GET_CLOCK;
  gc_free(tx->r_set.entries, t);
  gc_free(tx->w_set.entries, t);
  gc_free(tx, t);
  gc_exit_thread();
#else /* ! EPOCH_GC */
  xfree(tx->r_set.entries);
  xfree(tx->w_set.entries);
  xfree(tx);
#endif /* ! EPOCH_GC */

  tls_set_tx(NULL);
}

//static INLINE sigjmp_buf *
//int_stm_start(stm_tx_t *tx, stm_tx_attr_t attr)
/*shady gsd-tm*/
static INLINE int
int_stm_start(stm_tx_t *tx, sigjmp_buf *buf, stm_tx_attr_t attr)
{
  PRINT_DEBUG("==> stm_start(%p)\n", tx);

  /* TODO Nested transaction attributes are not checked if they are coherent
   * with parent ones.  */

  /* Increment nesting level */
  if (tx->nesting++ > 0)
    return NULL;

  /* Attributes */
  tx->attr = attr;

  /*shady gsd-tm*/
  tx->env = buf;

  /* Initialize transaction descriptor */
  int_stm_prepare(tx);

  /* Callbacks */
  if (likely(_tinystm.nb_start_cb != 0)) {
    unsigned int cb;
    for (cb = 0; cb < _tinystm.nb_start_cb; cb++)
      _tinystm.start_cb[cb].f(_tinystm.start_cb[cb].arg);
  }

  return &tx->env;
}

static INLINE int
int_stm_commit(stm_tx_t *tx)
{
#if CM == CM_MODULAR
  stm_word_t t;
#endif /* CM == CM_MODULAR */

  PRINT_DEBUG("==> stm_commit(%p[%lu-%lu])\n", tx, (unsigned long)tx->start, (unsigned long)tx->end);

  /* Decrement nesting level */
  if (unlikely(--tx->nesting > 0))
    return 1;

  /* Callbacks */
  if (unlikely(_tinystm.nb_precommit_cb != 0)) {
    unsigned int cb;
    for (cb = 0; cb < _tinystm.nb_precommit_cb; cb++)
      _tinystm.precommit_cb[cb].f(_tinystm.precommit_cb[cb].arg);
  }

  assert(IS_ACTIVE(tx->status));

#if CM == CM_MODULAR
  /* Set status to COMMITTING */
  t = tx->status;
  if (GET_STATUS(t) == TX_KILLED || ATOMIC_CAS_FULL(&tx->status, t, t + (TX_COMMITTING - GET_STATUS(t))) == 0) {
    /* We have been killed */
    assert(GET_STATUS(tx->status) == TX_KILLED);
    stm_rollback(tx, STM_ABORT_KILLED);
    return 0;
  }
#endif /* CM == CM_MODULAR */

  /* A read-only transaction can commit immediately */
  if (unlikely(tx->w_set.nb_entries == 0))
    goto end;

  /* Update transaction */
#if DESIGN == WRITE_BACK_ETL
  stm_wbetl_commit(tx);
#elif DESIGN == WRITE_BACK_CTL
  stm_wbctl_commit(tx);
#elif DESIGN == WRITE_THROUGH
  stm_wt_commit(tx);
#elif DESIGN == MODULAR
  if (tx->attr.id == WRITE_BACK_CTL)
    stm_wbctl_commit(tx);
  else if (tx->attr.id == WRITE_THROUGH)
    stm_wt_commit(tx);
  else
    stm_wbetl_commit(tx);
#endif /* DESIGN == MODULAR */

 end:
#ifdef TM_STATISTICS
  tx->stat_commits++;
#endif /* TM_STATISTICS */
#if CM == CM_MODULAR || defined(TM_STATISTICS)
  tx->stat_retries = 0;
#endif /* CM == CM_MODULAR || defined(TM_STATISTICS) */

#if CM == CM_BACKOFF
  /* Reset backoff */
  tx->backoff = MIN_BACKOFF;
#endif /* CM == CM_BACKOFF */

#if CM == CM_MODULAR
  tx->visible_reads = 0;
#endif /* CM == CM_MODULAR */

#ifdef IRREVOCABLE_ENABLED
  if (unlikely(tx->irrevocable)) {
    ATOMIC_STORE(&_tinystm.irrevocable, 0);
    if ((tx->irrevocable & 0x08) != 0)
      stm_quiesce_release(tx);
    tx->irrevocable = 0;
  }
#endif /* IRREVOCABLE_ENABLED */

  /* Set status to COMMITTED */
  SET_STATUS(tx->status, TX_COMMITTED);

  /* Callbacks */
  if (likely(_tinystm.nb_commit_cb != 0)) {
    unsigned int cb;
    for (cb = 0; cb < _tinystm.nb_commit_cb; cb++)
      _tinystm.commit_cb[cb].f(_tinystm.commit_cb[cb].arg);
  }

  return 1;
}

static INLINE stm_word_t
int_stm_load(stm_tx_t *tx, volatile stm_word_t *addr)
{
#if DESIGN == WRITE_BACK_ETL
  return stm_wbetl_read(tx, addr);
#elif DESIGN == WRITE_BACK_CTL
  return stm_wbctl_read(tx, addr);
#elif DESIGN == WRITE_THROUGH
  return stm_wt_read(tx, addr);
#elif DESIGN == MODULAR
  if (tx->attr.id == WRITE_BACK_CTL)
    return stm_wbctl_read(tx, addr);
  else if (tx->attr.id == WRITE_THROUGH)
    return stm_wt_read(tx, addr);
  else
    return stm_wbetl_read(tx, addr);
#endif /* DESIGN == MODULAR */
}

static INLINE void
int_stm_store(stm_tx_t *tx, volatile stm_word_t *addr, stm_word_t value)
{
  stm_write(tx, addr, value, ~(stm_word_t)0);
}

static INLINE void
int_stm_store2(stm_tx_t *tx, volatile stm_word_t *addr, stm_word_t value, stm_word_t mask)
{
  stm_write(tx, addr, value, mask);
}

static INLINE int
int_stm_active(stm_tx_t *tx)
{
  assert (tx != NULL);
  return IS_ACTIVE(tx->status);
}

static INLINE int
int_stm_aborted(stm_tx_t *tx)
{
  assert (tx != NULL);
  return (GET_STATUS(tx->status) == TX_ABORTED);
}

static INLINE int
int_stm_irrevocable(stm_tx_t *tx)
{
  assert (tx != NULL);
#ifdef IRREVOCABLE_ENABLED
  return ((tx->irrevocable & 0x07) == 3);
#else /* ! IRREVOCABLE_ENABLED */
  return 0;
#endif /* ! IRREVOCABLE_ENABLED */
}

static INLINE sigjmp_buf *
int_stm_get_env(stm_tx_t *tx)
{
  assert (tx != NULL);
  /* Only return environment for top-level transaction */
  return tx->nesting == 0 ? &tx->env : NULL;
}

static INLINE int
int_stm_get_stats(stm_tx_t *tx, const char *name, void *val)
{
  assert (tx != NULL);

  if (strcmp("read_set_size", name) == 0) {
    *(unsigned int *)val = tx->r_set.size;
    return 1;
  }
  if (strcmp("write_set_size", name) == 0) {
    *(unsigned int *)val = tx->w_set.size;
    return 1;
  }
  if (strcmp("read_set_nb_entries", name) == 0) {
    *(unsigned int *)val = tx->r_set.nb_entries;
    return 1;
  }
  if (strcmp("write_set_nb_entries", name) == 0) {
    *(unsigned int *)val = tx->w_set.nb_entries;
    return 1;
  }
  if (strcmp("read_only", name) == 0) {
    *(unsigned int *)val = tx->attr.read_only;
    return 1;
  }
#ifdef TM_STATISTICS
  if (strcmp("nb_commits", name) == 0) {
    *(unsigned long long *)val = tx->stat_commits;
    return 1;
  }
  if (strcmp("nb_aborts", name) == 0) {
    *(unsigned long long *)val = tx->stat_aborts;
    return 1;
  }
  if (strcmp("avg_aborts", name) == 0) {
    *(unsigned long long *)val = tx->stat_aborts / tx->stat_commits;
    return 1;
  }
  if (strcmp("max_retries", name) == 0) {
    *(unsigned int *)val = tx->stat_retries_max;
    return 1;
  }
  /*tarlovsky*/

  if (strcmp("nb_val_succ", name) == 0) {
    *(unsigned long long *)val = tx->stat_val_succ;
    return 1;
  }
  if (strcmp("nb_val_fail", name) == 0) {
    *(unsigned long long *)val = tx->stat_val_fail;
    return 1;
  }
  if (strcmp("val_time", name) == 0) {
    *(double *)val = tx->val_time;
    return 1;
  }
  if (strcmp("val_reads", name) == 0) {
    *(unsigned long long *)val = tx->val_reads;
    return 1;
  }

#endif /* TM_STATISTICS */
#ifdef TM_STATISTICS2
  if (strcmp("nb_aborts_1", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_1;
    return 1;
  }
  if (strcmp("nb_aborts_2", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_2;
    return 1;
  }
  if (strcmp("nb_aborts_locked_read", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_WR_CONFLICT >> 8];
    return 1;
  }
  if (strcmp("nb_aborts_locked_write", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_WW_CONFLICT >> 8];
    return 1;
  }
  if (strcmp("nb_aborts_validate_read", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_VAL_READ >> 8];
    return 1;
  }
  if (strcmp("nb_aborts_validate_write", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_VAL_WRITE >> 8];
    return 1;
  }
  if (strcmp("nb_aborts_validate_commit", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_VALIDATE >> 8];
    return 1;
  }
  if (strcmp("nb_aborts_killed", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_KILLED >> 8];
    return 1;
  }
  if (strcmp("nb_aborts_invalid_memory", name) == 0) {
    *(unsigned int *)val = tx->stat_aborts_r[STM_ABORT_SIGNAL >> 8];
    return 1;
  }
# ifdef READ_LOCKED_DATA
  if (strcmp("locked_reads_ok", name) == 0) {
    *(unsigned int *)val = tx->stat_locked_reads_ok;
    return 1;
  }
  if (strcmp("locked_reads_failed", name) == 0) {
    *(unsigned int *)val = tx->stat_locked_reads_failed;
    return 1;
  }
# endif /* READ_LOCKED_DATA */
#endif /* TM_STATISTICS2 */
  return 0;
}

static INLINE void
int_stm_set_specific(int key, void *data)
{
  TX_GET;
  assert (tx != NULL && key >= 0 && key < _tinystm.nb_specific);
  tx->data[key] = data;
}

static INLINE void *
int_stm_get_specific(int key)
{
  TX_GET;
  assert (tx != NULL && key >= 0 && key < _tinystm.nb_specific);
  return tx->data[key];
}

#endif /* _STM_INTERNAL_H_ */

