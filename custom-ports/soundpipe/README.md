# Soundpipe vcpkg port

This is a custom vcpkg port for the soundpipe library (https://github.com/shybyte/soundpipe).

## Status

Windows-only port currently. The port uses a custom build script (`build-soundpipe-windows.cmake`) 
adapted from CommonCpp's proven Windows build approach to handle soundpipe's C99 requirements.

## Challenges

Soundpipe requires C99 features (particularly void pointer arithmetic) that MSVC's cl.exe doesn't support.
The build script compiles as C++ with compatibility wrappers to work around this.

## Testing

To test locally:
```powershell
.\build-package.ps1 -PackageName soundpipe
```

## Integration

Once the package builds successfully in CI, CommonCpp can consume it via find_package(soundpipe).
