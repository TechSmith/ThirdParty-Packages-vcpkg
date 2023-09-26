if [ $# -lt 3 ]; then
    echo "Usage: $0 <src_x64_path> <src_arm64_path> <dest_universal_path>"
    exit 1
fi

src_x64_path=$1
src_arm64_path=$2
dest_universal_path=$3

X86_64_LIB=${src_x64_path}/lib
ARM64_LIB=${src_arm64_path}/lib
UNIVERSAL_LIB=${dest_universal_path}/lib

rm -rf ${dest_universal_path} # start clean

mkdir -p ${UNIVERSAL_LIB}

# Assume arm64 and x86_64 are identical.
cp -R ${src_arm64_path}/include ${dest_universal_path}/include

# Make install paths relative for both arm64 and x86_64
#
# Only do this on actual files, not symbolic links (-type f)
find ${ARM64_LIB} -name "*.a" -type f -exec chmod +w {} \;
find ${ARM64_LIB} -name "*.a" -type f -exec python3 makeInstallPathsRelative.py @rpath {} \;
find ${X86_64_LIB} -name "*.a" -type f -exec chmod +w {} \;
find ${X86_64_LIB} -name "*.a" -type f -exec python3 makeInstallPathsRelative.py @rpath {} \;

# look through arm64 dylibs and start lipo'ing
for staticLibPath in ${ARM64_LIB}/*.a; do   
   filename="$(basename $staticLibPath)"
   if [[ -L "$staticLibPath" ]]; then
     echo "lib = $staticLibPath - copy symlink"
     cp -a $staticLibPath ${UNIVERSAL_LIB}/$filename
   else
     echo "lib = $staticLibPath - need lipo"
     lipo -create -output ${UNIVERSAL_LIB}/$filename ${ARM64_LIB}/$filename ${X86_64_LIB}/$filename
   fi
done

