if [ $# -lt 3 ]; then
    echo "Usage: $0 <src_x64_dir> <src_arm64_dir> <dest_universal_dir>"
    exit 1
fi

src_x64_dir=$1
src_arm64_dir=$2
dest_universal_dir=$3

X86_64_LIB_DIR=${src_x64_dir}/lib
ARM64_LIB_DIR=${src_arm64_dir}/lib
UNIVERSAL_LIB_DIR=${dest_universal_dir}/lib

rm -rf ${dest_universal_dir} # start clean

mkdir -p ${UNIVERSAL_LIB_DIR}

# Assume arm64 and x86_64 are identical.
cp -R ${src_arm64_dir}/include ${dest_universal_dir}/include

# Make install paths relative for both arm64 and x86_64
#
# Only do this on actual files, not symbolic links (-type f)

# Function to make install paths relative
makeInstallPathsRelative() {
  find "$1" -name "*.$2" -type f -exec chmod +w {} \;
  find "$1" -name "*.$2" -type f -exec python3 makeInstallPathsRelative.py @rpath {} \;
}

# Function to create universal binaries for .a and .dylib files
createUniversalBinaries() {
  local source_dir="$1"
  local destination_dir="$2"

  for libPath in "${source_dir}"/*.{a,dylib}; do
    filename="$(basename "$libPath")"
    if [[ -L "$libPath" ]]; then
      echo "lib = $libPath - copy symlink"
      cp -a "$libPath" "${destination_dir}/$filename"
    else
      echo "lib = $libPath - need lipo"
      lipo -create -output "${destination_dir}/$filename" "${ARM64_LIB_DIR}/$filename" "${X86_64_LIB_DIR}/$filename"
    fi
  done
}

# Make install paths relative for both .a and .dylib files
makeInstallPathsRelative "$ARM64_LIB_DIR" "a"
makeInstallPathsRelative "$X86_64_LIB_DIR" "a"
makeInstallPathsRelative "$ARM64_LIB_DIR" "dylib"
makeInstallPathsRelative "$X86_64_LIB_DIR" "dylib"

# Create universal binaries for .a and .dylib files
createUniversalBinaries "$ARM64_LIB_DIR" "$UNIVERSAL_LIB_DIR"
