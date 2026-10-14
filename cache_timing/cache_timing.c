// cache_timing.c — CPU cache timing side-channel (teaching demo), native macOS.
//
// Shows two things, using ONLY memory-access timing (no secret memory is read):
//   1) Calibration: a cache HIT is ~tens of times faster than a DRAM MISS.
//   2) Flush+Reload-style recovery: a "victim" touches one secret index; the
//      "attacker" recovers that index purely by timing which region is cached.
//
// Apple Silicon notes: the userspace timer is coarse (~41.67 ns/tick) and there
// is no unprivileged cycle counter, so each measurement times a batch of
// DEPENDENT pointer-chasing loads (each load's address comes from the previous
// load) — this amortises the timer granularity and defeats prefetching/MLP.
//
// Build: cc -O1 -o cache_timing cache_timing.c
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <mach/mach_time.h>

#define LINE     64
#define R        8                    // regions = possible secret values (0..7)
#define L        1024                 // lines per region (64 KB, fits L1/L2)
#define STEPS    L
#define EVICT    ((size_t)128*1024*1024)
#define BIGWS    ((size_t)128*1024*1024)  // working set for the DRAM-miss baseline
#define BIGSTEPS 4000
#define TRIALS   60

static uint8_t  mem[R*L*LINE];
static uint8_t *evbuf, *bigring;
static size_t   entry[R], bigentry;
static volatile uint64_t sink;
static double ns_per_tick;

static void shuffle(int *a,int n){ for(int i=n-1;i>0;i--){int j=rand()%(i+1);int t=a[i];a[i]=a[j];a[j]=t;} }

// Build a random dependent pointer-chase cycle over `nl` lines starting at byte
// offset `base` in `buf`. Stored offsets are ABSOLUTE into `buf`, so chasing
// works regardless of where the region sits.
static size_t build_ring(uint8_t *buf,size_t base,size_t nl){
    int *perm=malloc(nl*sizeof(int));
    for(size_t i=0;i<nl;i++) perm[i]=(int)i;
    shuffle(perm,(int)nl);
    for(size_t k=0;k<nl;k++){
        size_t cur=base+(size_t)perm[k]*LINE, nxt=base+(size_t)perm[(k+1)%nl]*LINE;
        *(uint64_t*)&buf[cur]=(uint64_t)nxt;
    }
    size_t e=base+(size_t)perm[0]*LINE; free(perm); return e;
}

static void evict_all(void){
    uint64_t s=0;
    for(size_t i=0;i<EVICT;i+=LINE) s+=evbuf[i];
    sink+=s;
}

// Time `steps` dependent loads starting at byte offset `start` in `buf`.
static uint64_t chase(uint8_t *buf,size_t start,int steps){
    size_t cur=start;
    __asm__ volatile("dsb sy; isb" ::: "memory");
    uint64_t a=mach_absolute_time();
    __asm__ volatile("isb" ::: "memory");
    for(int i=0;i<steps;i++) cur=*(volatile uint64_t*)&buf[cur];
    __asm__ volatile("dsb sy; isb" ::: "memory");
    uint64_t b=mach_absolute_time();
    sink+=cur;
    return b-a;
}

int main(void){
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    ns_per_tick=(double)tb.numer/(double)tb.denom;
    srand(1234);

    // allocate + TOUCH every page (BSS/malloc is COW zero-pages otherwise, so
    // reads would hit one shared physical page and evict nothing).
    evbuf=malloc(EVICT);   for(size_t i=0;i<EVICT;i++) evbuf[i]=(uint8_t)(i*2654435761u);
    bigring=malloc(BIGWS); for(size_t i=0;i<BIGWS;i++) bigring[i]=1;
    bigentry=build_ring(bigring,0,BIGWS/LINE);
    for(int r=0;r<R;r++) entry[r]=build_ring(mem,(size_t)r*L*LINE,L);

    // ---- 1) calibration: HIT (warm small ring) vs MISS (cold 128MB ring) ----
    (void)chase(mem,entry[0],STEPS);                       // warm region 0
    double hit=(double)chase(mem,entry[0],STEPS)/STEPS*ns_per_tick;
    double miss=(double)chase(bigring,bigentry,BIGSTEPS)/BIGSTEPS*ns_per_tick;
    printf("timebase            : %.2f ns/tick\n", ns_per_tick);
    printf("HIT  (L1/L2 cache)  : %6.1f ns / access\n", hit);
    printf("MISS (DRAM)         : %6.1f ns / access\n", miss);
    printf("=> DRAM is %.0fx slower than cache\n", miss/(hit>0?hit:1));
    printf("threshold ~= %.1f ns\n\n", (hit+miss)/2.0);

    // ---- 2) recover a secret index purely from access timing ----
    int secret = rand()%R;
    double total[R]={0};
    for(int t=0;t<TRIALS;t++){
        evict_all();
        (void)chase(mem,entry[secret],STEPS);              // "victim" touches secret region
        for(int j=0;j<R;j++){
            int r=(j*3+t)%R;                               // randomized probe order
            total[r]+=chase(mem,entry[r],STEPS);           // attacker times each region
        }
    }
    int guess=0; for(int r=1;r<R;r++) if(total[r]<total[guess]) guess=r;
    printf("per-region avg probe time (ns): ");
    for(int r=0;r<R;r++) printf("%5.1f ",(total[r]/TRIALS/STEPS)*ns_per_tick);
    printf("\n\n");
    printf("secret value (hidden from attacker) : %d\n", secret);
    printf("ATTACKER'S GUESS (from timing only) : %d\n", guess);
    printf(guess==secret? ">>> RECOVERED the secret via cache timing. No secret memory was read.\n"
                        : ">>> guess missed (timing noise) - rerun.\n");
    free(evbuf); free(bigring);
    return 0;
}
