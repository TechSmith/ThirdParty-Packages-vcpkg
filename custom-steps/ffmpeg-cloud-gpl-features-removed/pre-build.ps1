Import-Module "$PSScriptRoot/../../scripts/ps-modules/Build" -DisableNameChecking

# Lots of comments, since this build gave me a lot of trouble.

# Objective: build ffmpeg with a small set of flags disabled. By applying a minimal patch
# on top of an upstream ffmpeg version, we avoid having to maintain (and update) our own cmake
# build script. It also should make it easy to update to new versions of the upstream build script,
# and allow us an easy route to update to new versions for security patches.

# How to update the patch file. It's a bit manual right now.
# - Clone the vcpkg repo anywhere (https://github.com/microsoft/vcpkg.git)
# - Pick a tag to base our patches off of
# - Update vcpkgHash to be this tag name in preconfigured-packages.json. Must be the same or patching will fail in confusing ways.
# - Copy the upstream portfile: `cp path/to/vcpkg/ports/ffmpeg/portfile.cmake custom-steps/ffmpeg-cloud-gpl-features-removed/portfile-upstream.cmake`
# - Copy the upstream portfile to modify: `cp custom-steps/ffmpeg-cloud-gpl-features-removed/portfile-upstream.cmake custom-steps/ffmpeg-cloud-gpl-features-removed/portfile-upstream-modified.cmake`
# - Make desired changes to the custom-steps/ffmpeg-cloud-gpl-features-removed/portfile-upstream-modified.cmake
# - Run git diff --no-index custom-steps/ffmpeg-cloud-gpl-features-removed/portfile-upstream.cmake custom-steps/ffmpeg-cloud-gpl-features-removed/portfile-upstream-modified.cmake > custom-steps/ffmpeg-cloud-gpl-features-removed/tsc-cloud-ffmpeg-edits.patch
# - Fix up the patch file:
#   - Change encoding to be UTF-8 (powershell piping issue)
#   - Change line endings to be LF instead of CRLF
#   - Delete the first two lines with "diff --git" and "index ######"
#   - Edit the source and destination paths to be: a/portfile.cmake and b/portfile.cmake
#   - Commit the patch to the repository, and it should get applied in this function!
# - Now the patch should work

# How to troubleshoot when the wrong version of ffmpeg is getting built
# - Do a local build with vcpkg to verify your patched portfile works
# - If patching fails or build fails with confusing errors, vcpkg is most likely building the wrong version of ffmpeg. 
# - Check that any other custom-ports named "ffmpeg" are deleted in this repo before building. Grab a file list of the source code root, or try to grep any matches for "ffmpeg"
# - Check upstream versions file to see if our requested version of ffmpeg exists on this vcpkg tag (cat $vcpkgInstallDir/versions/f-/ffmpeg.json)
# - Print upstream portfile before and after patching to see if it matches what you expected
# - Print full file tree of $vcpkgInstallDir (or source code root) to inspect buildtrees folder or other possibly cached files
# - Running `vcpkg list` and `vcpkg remove ffmpeg` in case ffmpeg is somehow already installed

function Patch-Ffmpeg-From-Upstream{
    $vcpkgInstallDir = Get-VcpkgInstallDir
    $upstreamPortFileDir = Get-Item "$vcpkgInstallDir/ports/ffmpeg" | Select-Object -ExpandProperty FullName
    $upstreamPortFileToPatch = Get-Item "$vcpkgInstallDir/ports/ffmpeg/portfile.cmake" | Select-Object -ExpandProperty FullName
    
    $tscFfmpegPatchFile = "$PSScriptRoot/tsc-cloud-ffmpeg-edits.patch"

    Write-Message "Applying TechSmith patch file '$tscFfmpegPatchFile' to upstream vcpkg ffmpeg port '$upstreamPortFileToPatch' for build later"
    
    $patchSuccess = Apply-VcpkgPortPatch -PortName "ffmpeg" -PatchFile "$tscFfmpegPatchFile" -WorkingDirectory "$upstreamPortFileDir"
    
    if (-not $patchSuccess) {
        Write-Message "FATAL: Failed to apply patch to ffmpeg upstream" -Error
        exit 1
    }

    # Debug: if patching isn't working right or you want quick testing, just copy the upstream portfile and uncomment this
    # $debugPortFile = Get-Item "$PSScriptRoot/../../custom-ports/ffmpeg-cloud-gpl-features-removed/portfile-upstream-modified.cmake" | Select-Object -ExpandProperty FullName
    #Write-Message "DEBUG: replacing upstream portfile with modified copy from '${debugPortFile}'"
    #Copy-Item -Force -Path $debugPortFile -Destination $upstreamPortFile -Verbose

    # Debug: print patched portfile to troubleshoot
    #echo "DEBUG: contents of $upstreamPortFile"
    #cat $upstreamPortFile
}

function Delete-Other-FFmpeg-Ports{
    # We consume ffmpeg as a "dependency", but vcpkg will always try building the other ffmpeg ports in this repo unless we delete it.
    # I tried overriding settings in this custom-port with vcpkg.json and vcpkg-configuration.json, but couldn't get it working right.
    # This shouldn't affect other builds that target these custom ports.
    Write-Message "Deleting other ffmpeg custom port directories, since they interfere with this build that consumes upstream ffmpeg as a dependency"

    $problematicFfmpegDir = Get-Item "$PSScriptRoot/../../custom-ports/ffmpeg" | Select-Object -ExpandProperty FullName
    $problematicFfmpegDir2 = Get-Item "$PSScriptRoot/../../custom-steps/ffmpeg" | Select-Object -ExpandProperty FullName
    $problematicFfmpegDir3 = Get-Item "$PSScriptRoot/../../custom-ports/ffmpeg-cloud-gpl" | Select-Object -ExpandProperty FullName
    $problematicFfmpegDir4 = Get-Item "$PSScriptRoot/../../custom-steps/ffmpeg-cloud-gpl" | Select-Object -ExpandProperty FullName

    Remove-Item -Path $problematicFfmpegDir -Recurse -Force -Verbose
    Remove-Item -Path $problematicFfmpegDir2 -Recurse -Force -Verbose
    Remove-Item -Path $problematicFfmpegDir3 -Recurse -Force -Verbose
    Remove-Item -Path $problematicFfmpegDir4 -Recurse -Force -Verbose
}

function Get-Dependencies{
    Write-Host "Installing OS dependencies for ffmpeg build"

    if ( Get-IsOnLinux ) {
        sudo apt update
        sudo apt install -y curl zip unzip tar git gcc g++ python3 nasm pkg-config make
        sudo apt upgrade -y
    }

    if ( Get-IsOnWindowsOS ) {
        # No dependencies needed for windows
        exit
    }

    Write-Host "Done installing OS dependencies for ffmpeg build"
}


function Prebuild-Main{
    if( Get-IsOnMacOS ) {
        throw "We don't support builds for mac at this time, but it should be easy to set up"
    }

    Delete-Other-FFmpeg-Ports
    Patch-Ffmpeg-From-Upstream
    Get-Dependencies
}

Prebuild-Main
