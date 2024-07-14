#include <stdint.h>
#include <unistd.h>
#include <sys/syscall.h>

typedef uintptr_t uptr;

#define UPTR(x) (uptr)x

#define __asm_syscall(...) do { \
    __asm__ __volatile__ ( "svc 0" \
    : "=r"(r0) : __VA_ARGS__ : "memory"); \
    return r0; \
    } while (0)

static inline long syscall1(uptr n, uptr a1){
	register long r7 __asm__("r7") = n;
	register long r0 __asm__("r0") = a1;
	__asm_syscall("r"(r0));
	return r0;
}

static inline long syscall3(uptr n, uptr a1, uptr a2, uptr a3){
	register long r7 __asm__("r7") = n;
	register long r0 __asm__("r0") = a1;
	register long r1 __asm__("r1") = a2;
	register long r2 __asm__("r2") = a3;
	__asm_syscall("r"(r0), "r"(r1), "r"(r2));
	return r0;
}

int memcmp(const void *vl, const void *vr, size_t n){
	const unsigned char *l=vl, *r=vr;
	for (; n && *l == *r; n--, l++, r++);
	return n ? *l-*r : 0;
}

/** needed by the = {0} construct */
void* memset(void *dest, register int val, register size_t len){
	register unsigned char *ptr = (unsigned char*)dest;
	while (len-- > 0){
		*ptr++ = val;
	}
	return dest;
}

int strlen(const char *s){
	int l;
    for (l = 0; s[l]; s++);
	return l;
}

static char msg_help[] =
	"neon\n"
	"vfp-d16\n"
	"vfp-d32\n"
	"fp16\n"
	"fp16-vector\n"
;

static char msg_begin[]    = "Beginning features test\n";
static char msg_neon[]     = "You have NEON if you can read this\n";
static char msg_vfpv3d16[] = "You have VFPv3 D16 if you can read this\n";
static char msg_vfpv3d32[] = "You have VFPv3 D32 if you can read this\n";
static char msg_vfpv3fp16[] = "You have VFPv3 FP16 if you can read this\n";
static char msg_vfpv3fp16_vector_math[] = "You have VFPv3 FP16 with vector math if you can read this\n";

#define READ(x) syscall3(__NR_read, STDIN_FILENO, UPTR(&x[0]), sizeof(x))
#define PRINT(x) syscall3(__NR_write, STDOUT_FILENO, UPTR(&x[0]), sizeof(x))

void _start(){
	char test[128] = {0};
	int length = READ(test);
	if(length < 1) goto usage;

	int result = 0;

	#define IS_TEST(name) !memcmp(test, name, sizeof(name))

	PRINT(msg_begin);
	if(IS_TEST("neon")){
		asm volatile("vmov s0, r0");
		PRINT(msg_neon);
	} else if(IS_TEST("vfp-d16")){
		asm volatile(
			"mov r0, %[ptr]\n"
			"vldr d15, [r0, #0]\n"
			:: [ptr]"r"(&_start)
			: "r0"
		);
		PRINT(msg_vfpv3d16);
	} else if(IS_TEST("vfp-d32")){
		asm volatile(
			"mov r0, %[ptr]\n"
			"vldr d16, [r0, #0]\n"
			:: [ptr]"r"(&_start)
			: "r0"
		);
		PRINT(msg_vfpv3d32);
	} else if(IS_TEST("fp16")){
		asm volatile(
			"vcvtt.f16.f32 s1,s0\n"
		);
		PRINT(msg_vfpv3fp16);
	} else if(IS_TEST("fp16-vector")){
		asm volatile(
			"vadd.f16 q0, q0, q0\n"
		);
		PRINT(msg_vfpv3fp16_vector_math);
	} else {
	usage:
		PRINT(msg_help);
		result = 1;
	}

	syscall1(__NR_exit, result);
}
