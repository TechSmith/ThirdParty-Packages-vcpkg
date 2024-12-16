# Check that we have at least one input parameter
if [ $# -lt 1 ]; then
  echo "Usage: $0 <prefix to install everything into>"
  exit 1
fi

# Set the prefix to install everything into
PREFIX=$1

emconfigure ./configure \
  --logfile=configure.log \
  --prefix=${PREFIX} \
  --target-os=none \
  --arch=wasm32 \
  --enable-cross-compile \
  --disable-x86asm \
  --disable-inline-asm \
  --disable-doc \
  --disable-stripping \
  --enable-shared \
  --disable-static \
  --disable-programs \
  --disable-doc \
  --disable-debug \
  --disable-runtime-cpudetect \
  --disable-autodetect \
  --disable-network \
  --disable-filters \
  --disable-demuxers \
  --disable-muxers \
  --disable-bsfs \
  --disable-parsers \
  --disable-protocols \
  --disable-devices \
  --disable-pthreads \
  --disable-encoders \
  --disable-decoders \
  --enable-encoder=aac* \
  --enable-decoder=aac* \
  --enable-decoder=h264 \
  --enable-protocol=file \
  --enable-demuxer=mov \
  --nm=emnm \
  --ar=emar \
  --ranlib=emranlib \
  --cc=emcc \
  --cxx=em++ \
  --objcc=emcc \
  --dep-cc=emcc \
  --extra-cflags="-pthread -g0 -O3" \
  --extra-ldflags="-sSIDE_MODULE=1 -sWASM_BIGINT -pthread -sINITIAL_MEMORY=33554432"

#--extra-cflags="-fPIC"

#  --disable-encoders \
#  --enable-decoder=aac \
#  --disable-decoders \

#  --nm="$EMSDK/upstream/bin/llvm-nm -g" \
#  --ar=emar
#  --cc=emcc
#  --cxx=em++
#  --objcc=emcc
#  --dep-cc=emcc




#--enable-shared \
#--disable-static \
#--disable-optimizations \
#--enable-cross-compile \
#--target-os=win64 \
#--extra-cflags="-MDd" \
#--extra-ldflags="/NODEFAULTLIB:libcmt" \
#--extra-cflags="-I../../libmp3lame/output/" \
#--extra-ldflags="-LIBPATH:../../libmp3lame/output/x64/Debug/" \
#--enable-debug \
#--enable-demuxer=mp3 \
#--enable-encoder=libmp3lame \
#--enable-libmp3lame \
#--enable-muxer=mp3 \
#--enable-protocol=file \
