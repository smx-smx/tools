TOOLCHAIN_DIR=/mnt/ExtData/cross/buildroot/output/host \
PATH=${TOOLCHAIN_DIR}/bin:$PATH \
ROOTFS_DIR=${TOOLCHAIN_DIR} \
TOOLCHAIN_FILE=$PWD/bcm.cmake \
CLR_CC=`which arm-buildroot-linux-uclibcgnueabi-gcc` \
CLR_CXX=`which arm-buildroot-linux-uclibcgnueabi-g++` \
./build.sh \
    --arch armel \
    -c release \
    -v m \
    -s Libs+Mono \
    --cross $*
