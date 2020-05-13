
#include <pthread.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdatomic.h>
#include <CL/cl.h>
#include <assert.h>
/* #include "atomic.h" /* these are HP atomics: atomic_ops.h dont need them here. For debugging */
#include <sys/time.h>
#include "timer.h"
#include "debug_validation.h"

#define SUCCESS 0
#define FAIL -1

#define STATES 5
#define PHASE 0
#define SPIN 1
#define COMPLETE 2
#define FINISH 3
#define STM_SUBSCRIBER_THREAD 4

//#define SVMN 4
//#define SVMNPERWI 5
//#define VALID 6

#define MAX_WORK_GROUPS 42

//#define ATOMIC_LOAD(a)               (*((volatile size_t *)(a)))

/* TinySTM vars */
#ifndef RW_SET_SIZE
/* CL_DEVICE_MAX_MEM_ALLOC_SIZE is 128*1024*1024 = 134217728 */
/* opt: sed it with read-set being used, only in synthetic will it work */
# define RW_SET_SIZE            134217728 /* Initial size of read/write sets */
#endif /* ! RW_SET_SIZE */

#define LOCK_ARRAY_LOG_SIZE     26    /* Size of lock array: 2^20 = 1M (million)*/
#define LOCK_ARRAY_SIZE         (1 << LOCK_ARRAY_LOG_SIZE) /* Size in bits. ex.: 2^20=1048576*/

/* Validation OCL kernel specific defines */
#define HW_THREADS_PER_EU 7
#define BIN_KERNEL_INSTANT "/home/oleksiy/Desktop/stm-validation-study/TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded/src/validation_tool/instant_kernel.bin"
#define CL_KERNEL_INSTANT "/home/oleksiy/Desktop/stm-validation-study/TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded/src/validation_tool/instant_kernel.cl"
#define CL_KERNEL_INSTANT_DEBUG "instant_kernel_debug.cl"
#define CL_KERNEL_INSTANT_NAME "InstantKernel"

#define BIN_KERNEL_REGULAR "/home/oleksiy/Desktop/stm-validation-study/TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded/src/validation_tool/regular_kernel.bin"
#define CL_KERNEL_REGULAR "/home/oleksiy/Desktop/stm-validation-study/TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded/src/validation_tool/regular_kernel.cl"
#define CL_KERNEL_REGULAR_NAME "RegularKernel"

/* vtune */
//#define CL_KERNEL_PROGRAM_OPTIONS "-I/home/oleksiy/Desktop/stm-validation-study/TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded/src/validation_tool -g -s " CL_KERNEL_INSTANT " -cl-std=CL2.0" //added I flag to share debug_validation header and define.
/* normal exec */
#define CL_KERNEL_PROGRAM_OPTIONS "-I/home/oleksiy/Desktop/stm-validation-study/TinySTM-igpu-cpu-persistent-dynamic-split-multithreaded/src/validation_tool -cl-std=CL2.0" //added I flag to share debug_validation header and define.

#define PERF_TEST_ZERO_COPY 1 //don't forget to also decide if you want aligned or unaligned malloc
#define ALIGNED_ALLOCATION 1

#define CL_DEVICE_CPU_OR_GPU CL_DEVICE_TYPE_GPU
//#define CL_DEVICE_CPU_OR_GPU CL_DEVICE_TYPE_CPU

// DEBUG need this to print debug and work with locks. Repeat inside kernel.
#define OWNED_BITS                     1                   /* 1 bit */
#define INCARNATION_BITS               3                   /* 3 bits */
#define WRITE_MASK                     0x01                /* 1 bit */
#define OWNED_MASK                     (WRITE_MASK)
#define LOCK_GET_OWNED(l)               (l & OWNED_MASK)
#define LOCK_GET_ADDR(l)                (l & ~(stm_word_t)OWNED_MASK)
#define LOCK_BITS                       (OWNED_BITS + INCARNATION_BITS)
#define LOCK_GET_TIMESTAMP(l)           (l >> (LOCK_BITS))
#ifndef CACHELINE_SIZE
/* It ensures efficient usage of cache and avoids false sharing.
 * It could be defined in an architecture specific file. */
# define CACHELINE_SIZE                 64
#endif


#ifndef STMINTERNAL_H
#define STMINTERNAL_H
typedef uintptr_t stm_word_t;

typedef struct r_entry {                /* Read set entry */
    stm_word_t version;                   /* Version read */
    volatile stm_word_t *lock;            /* Pointer to lock (for fast access) */
} r_entry_t;

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
#endif /*STMINTERNAL_H*/

extern TIMER_T T1C;
extern TIMER_T T2C;
extern TIMER_T T1G;
extern TIMER_T T2G;

//in order to communicate with utils.h
extern unsigned int found_cl_hardware;//0 no 1 yes (HD530 or other)

/*typedef struct thread_control{
    atomic_int r_entry_idx; /* index within the rset_pool
    unsigned int n_per_wi;
    unsigned int nb_entries;
    uintptr_t w_set_base;
    uintptr_t w_set_end;
    //unsigned int wkgp_idx; /* read set validation splits into work groups of SimdSize*
    //_Atomic int wkgp_comp_count; /* work items will increment. When equal to LocalWKGP size - means work-group completed
    atomic_int valid;
    atomic_int Phase;
    atomic_int complete;
} thread_control_t;*/

typedef struct thread_control{
    uintptr_t w_set_base;
    uintptr_t w_set_end;
    atomic_int r_pool_idx;  /* index within the rset_pool */
    atomic_int reads_count; /* stats */
    atomic_int valid;
    atomic_int Phase;
    unsigned long submersions;
    atomic_int block_offset;
    atomic_int nb_entries;
    char padding[CACHELINE_SIZE]; /*avoid false sharing*/
} thread_control_t;

typedef struct r_entry_wrapper{
    r_entry_t* entries;
}r_entry_wrapper_t;

//basic components of any cl sample application
extern cl_context g_clContext;
extern cl_device_id *g_clDevices;
extern cl_command_queue g_clCommandQueue;
extern cl_program g_clProgram;
extern char *g_clProgramString;
extern unsigned int cachelineSize;
extern unsigned int max_work_group_size;
extern unsigned int NumberOfExecUnits;
extern unsigned int NumberOfHwThreads;
extern unsigned int SimdSize;

/*read-set cursor that tells where the gpu currently is */
/*set by delegation thread in increments of MAX_OCCUPANCY (5376 on hd530)*/
/*when cpu passes half of read-set it starts checking this variable every on read-set iteration*/
extern atomic_ulong GPU_POS;

/* tell the gpu to stop submersing into validation blocks.
 * can be set only by transaction currently owning the gpu*/
extern atomic_int halt_gpu;

/* transaction threads compete for gpu at start of validation. TODO implement a try_lock_for(time) */
/* at the moment it tries once and quits */
extern atomic_int gpu_employed;

//Create the NDRange
extern size_t global_dim[1];
extern size_t lws[1];
extern _Atomic unsigned int *pCommBuffer;
//extern _Atomic unsigned int *shared_i; /*replaced by non atomic GPU_POS*/
extern unsigned int cl_global_phase; /* global phase used to control igpu persistentkernel */
extern unsigned int initial_rs_svm_buffers_ocl_global;
extern r_entry_t **rset_pool;
extern r_entry_wrapper_t* rset_pool_cl_wrapper;
extern volatile stm_word_t **locks;

/* thread that waits on a condition to signal gpu validation */
extern pthread_t gpu_delegate_thread;

/*used in validation to signal delegation thread to start working*/
extern pthread_mutex_t validate_mutex;

extern pthread_cond_t validate_cond,/*gpu_delegate thread sleeps on this condition when there is no work*/
                      validate_complete_cond;/*cpu was sleeping on this condition while waiting for gpu to complete TODO unused */

extern atomic_int delegate_validate, /*transaction doing validation signals gpu_delegation_thread*/
                  validate_complete, /*unnecessary when gpu-cpu work dynamically in opposite directions of the readset TODO unused.*/
                  shutdown_gpu,
                  minus_one; /* set in --> cleanupCL() */

/* trick that helps cpu-gpu co-op. reduces sharing threadComm[idx].valid. if gpu invalidates,
 * after gpu completes it sets gpu_exit_validity to 0|1.*/
extern atomic_int gpu_exit_validity;

/*                     Debug Buffers                      */
extern long *debug_buffer_arg;
extern uintptr_t *debug_buffer_arg1;
extern uintptr_t *debug_buffer_arg2;

extern thread_control_t* threadComm;/* meta used to pass which validation set to validate between host and device */

extern cl_kernel cl_kernel_worker;
extern cl_kernel cl_kernel_worker_temp;
extern unsigned int kernel_init; /*instant kernel initialized*/

int initializeHost(void);
void testStatus(int status, char *errorMsg);
int initializeCL(volatile stm_word_t **lock_pointer);
int launchInstantKernel(void);
void* signal_gpu(void);

int cleanupCL(void);
int cleanupHost();
int xfree_svmalloc(void *mem);

// Check for fine-grained buffer SVM type with ATOMICS availability:
bool checkSVMAvailability(cl_device_id device);
//compile program and create kernels to be used on device side
int initializeDeviceCode(const char* kernel_src_path, const char* kernel_name, const char* bin_name);
int HandleCompileError(void);
//convert to string needs to take a string a file as input and write a char * to output
int convertToStringBuf(const char *fileName, long* length_out);
char* bin_to_str(const char* fileName, long* length_out); // difference is that it reads byte by byte from file.
//utility functions
//testStatus is intentionally extremely tiny to minimize extraneous code in a sample
unsigned int verifyZeroCopyPtr(void *ptr, unsigned int sizeOfContentsOfPtr);
