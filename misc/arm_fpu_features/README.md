# test_arm_features
Small Linux tool to check for FPU features on ARM CPUs.

The tool is linked to not depend on a C library (`nostdlib`), so it can be compiled with any GCC (or clang?) toolchain and the produced binary should be portable on multiple, if not all, kernel versions \
(the only syscalls used are `read`, `write` and `exit`).

Implemented tests:
- neon (vmov)
- vldr d15 (vfp-d16)
- vldr d16 (vfp-d32)
- fp16 (vcvtt.f16.f32)
- fp16-vector (vadd.f16)

Usage: `echo <test_name> | ./test_arm_features`\
If the program produces an output and the exit code is 0, then the test passed.\
If the program crashes, the feature is not supported by the CPU
