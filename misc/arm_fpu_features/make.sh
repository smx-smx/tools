arm-linux-gnueabi-gcc \
    test_arm_features.c -o test_arm_features \
    -march=armv8.5-a+fp16+bf16+i8mm \
    -mfpu=neon-fp-armv8 \
    -mfloat-abi=softfp -fomit-frame-pointer \
    -marm -nostdlib -ffreestanding
