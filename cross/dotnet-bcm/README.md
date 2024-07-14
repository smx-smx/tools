# dotnet-bcm
Scripts to cross compile Dotnet Core for the bcm63138 Modem/Router.

Note: the target has no usable FPU (see [Trivia](#trivia)), so only Mono can be built

Keep in mind that, in order to make use of these scripts, you need to be on [my fork of dotnet/runtime](https://github.com/smx-smx/runtime/commits/armel-fixes).\
My modifications implement some build fixes for Linux 3.4 and support for generic ARM targets (other than Samsung Tizen)


## Trivia
The BCM63138 is a dual Core Arm Cortex-A7 CPU.

This kind of CPU normally has a FPU (vfpv3) and the BCM is no different.\
However, for some unknown reasons (die size constraints?) only the primary core has an FPU.\
The other ARM core has no FPU, creating an unbalance in features between the 2 cores (we can't really call this configuration "SMP", synce it's not symmetrical).

Linux does not support CPU-based affinity based on CPU features, and so this creates a problem.\
When building the kernel for a BCM63138, one must choose if he wants to enjoy the VFPv3 FPU at the expense of SMP multitasking,\
or if SMP is to be preferred at the expense of the FPU.

All modem/router configurations I've seen so far use SMP by turning the FPU off (thus making the configuration symmetrical), so the modem is essentially acting as if it was FPU-less.
the BCM63138 has a MIPS coprocessor for offloading network and routing tasks from the main core, so perhaps the impact is mitigated.
