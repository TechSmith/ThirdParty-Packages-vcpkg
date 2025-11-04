# Soundpipe vcpkg port

This is a custom vcpkg port for the soundpipe library (https://github.com/shybyte/soundpipe).

## Status

Multi-platform support:
- ✅ **Windows**: Uses custom build script with clang-cl for C99 support
- ✅ **Mac**: Uses standard CMake build with Clang C99 support
- ✅ **WASM**: Uses standard CMake build with Emscripten C99 support

## Build Approach

### Windows
- Installs LLVM/clang-cl via Chocolatey for proper C99 support
- Uses custom `build-soundpipe-windows.cmake` script
- Handles MSVC C99 limitations with clang-cl compiler

### Mac/Linux/WASM
- Uses standard CMake build (`CMakeLists.txt`)
- Relies on native C99 compiler support (GCC/Clang/Emscripten)
- No special workarounds needed

## Testing

To test locally:
```powershell
.\build-package.ps1 -PackageName soundpipe
```

## Integration with CommonCpp

Once the package builds successfully in CI, CommonCpp's `AddSoundpipe.cmake` can:
- Use `find_package(soundpipe)` to locate the pre-built vcpkg package
- Fall back to building from source if vcpkg package not found

