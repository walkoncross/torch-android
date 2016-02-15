#!/bin/bash
# have ndk-build in your $PATH and the script figures out where your ANDROID_NDK is at.
# optionally, modify the variables below as needed.
NDKABI=21
NDKVER=toolchains/arm-linux-androideabi-4.9

####################################################
# You do not need to modify anything below this line
####################################################
# find system torch, if not found, install it
command -v th >/dev/null 2>&1
TORCHINSTALLCHECK=$?
if [ $TORCHINSTALLCHECK -ne 0 ]; then
    echo "Torch-7 not found on system. Please install it using instructions from http://torch.ch"
    exit -1
fi
# have ndk-build in your PATH and the script figures out where your ANDROID_NDK is at
unamestr=`uname`
ndkbuildloc=`which ndk-build`
if [[ "$?" == 1 ]]; then
    echo "Error: Cannot find ndk-build in PATH. Please add it to PATH environment variable"
    exit 1
fi
if [[ "$unamestr" == 'Linux' ]]; then
    export ANDROID_NDK=`readlink -f $ndkbuildloc|sed 's/ndk-exec.sh//'|sed 's/ndk-build//'`
elif [[ "$unamestr" == 'Darwin' ]]; then
    which greadlink >/dev/null 2>&1
    if [[ "$?" == 1 ]]; then
	brew install coreutils
    fi
    export ANDROID_NDK=`greadlink -f $ndkbuildloc|sed 's/ndk-exec.sh//'|sed 's/ndk-build//'`
fi
echo "Android NDK found at: $ANDROID_NDK"
cd "$(dirname "$0")" # switch to script directory
SCRIPT_ROOT_DIR=`pwd`
INSTALL_DIR=$SCRIPT_ROOT_DIR/install

set +e # hard errors

# Build host luajit for minilua and buildvm
cd distro/exe/luajit-rocks/luajit-2.1
NDK=$ANDROID_NDK
NDKVER=$NDK/$NDKVER
if [[ "$unamestr" == 'Linux' ]]; then
    export NDKP=$NDKVER/prebuilt/linux-x86_64/bin/arm-linux-androideabi-
elif [[ "$unamestr" == 'Darwin' ]]; then
    export NDKP=$NDKVER/prebuilt/darwin-x86_64/bin/arm-linux-androideabi-
fi
NDK_SYSROOT=$NDK/platforms/android-$NDKABI/arch-arm
NDKF="--sysroot $NDK_SYSROOT"
NDKARCH="-march=armv7-a -mfloat-abi=softfp -Wl,--fix-cortex-a8"

# make clean
make HOST_CC="gcc -m32" CC="gcc" HOST_SYS=$unamestr TARGET_SYS=Linux CROSS=$NDKP TARGET_FLAGS="$NDKF $NDKARCH"


cd $SCRIPT_ROOT_DIR

# Build Lua
mkdir -p build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/android.toolchain.cmake -DWITH_LUAJIT21=ON -DWITH_LUAROCKS=OFF \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DANDROID_STL=none -DLIBRARY_OUTPUT_PATH_ROOT=$INSTALL_DIR \
    -DCWRAP_CUSTOM_LUA=th \
    -DLUAJIT_SYSTEM_MINILUA=$SCRIPT_ROOT_DIR/distro/exe/luajit-rocks/luajit-2.1/src/host/minilua \
    -DLUAJIT_SYSTEM_BUILDVM=$SCRIPT_ROOT_DIR/distro/exe/luajit-rocks/luajit-2.1/src/host/buildvm \
    -DCMAKE_C_FLAGS="-DDISABLE_POSIX_MEMALIGN" \
    -DANDROID_NDK_SYSROOT_INCLUDE="$NDK_SYSROOT/usr/include" \
    -DANDROID_NDK_SYSROOT_LIBDIR="$NDK_SYSROOT/usr/lib"

make install

cd ..

echo "done"
