param (
    [Parameter(Mandatory=$true)][string]$BuildArtifactsPath
)

. "$PSScriptRoot\..\..\util.ps1"

$IsOnMacOS = Check-IsOnMacOS

if(-not $IsOnMacOS) {
    Write-Host "Not on Mac OS.  Exiting..."
    exit
}

Write-Host "Running post-build script..."
Push-Location "$BuildArtifactsPath/lib"

# Enumerate files
$main_files = @()
$files_with_versions = @()
$dylib_files = Get-ChildItem -Path . -Filter "*.dylib"
foreach ($dylib_file in $dylib_files) {
    # Check if the file name contains more than one dot
    if (-not ($dylib_file.Name -match '\..*\..*')) {
        $main_files += $dylib_file.Name
    }
    else {
        $files_with_versions += $dylib_file.Name
    }
}

Write-Host ""
Write-Host ""
Write-Host "Dependencies before changes..."
foreach($main_file in $main_files) {
    Write-Host "> $main_file"
    Invoke-Expression "otool -L '$main_file' | grep '@rpath'"
}

Write-Host ""
Write-Host ""
Write-Host "Updating dependencies..."
foreach ($main_file in $main_files) {
    # Main file
    Write-Host ("> $main_file")
    Invoke-Expression "install_name_tool -id '@rpath/$main_file' '$main_file'"

    # All other files that might point to it
    foreach ($possible_current_dependency in $files_with_versions) {
        $base_filename = ($possible_current_dependency -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
        $new_dependency = "$base_filename.dylib"
        if ($main_files -contains $new_dependency) {
            Invoke-Expression "install_name_tool -change '@rpath/$possible_current_dependency' '@rpath/$new_dependency' '$main_file'"
        } else {
            Write-Host (">> Matching main file not found for: $possible_current_dependency!!!")
        }
    }
}

Write-Host ""
Write-Host ""
Write-Host "Dependencies after changes..."
foreach($main_file in $main_files) {
    Write-Host "> $main_file"
    Invoke-Expression "otool -L '$main_file' | grep '@rpath'"
}

Write-Host ""
Write-Host ""
Write-Host "Removing unused symlinks..."
$files = Get-ChildItem -File -Recurse
foreach ($file in $files) {
    if ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Write-Host "Removing symlink: $($file.FullName)"
        Remove-Item $file.FullName
    }
}

# Rename files to the "main" filename we want
Write-Host ""
Write-Host ""
Write-Host "Renaming files..."
$files = Get-ChildItem -File -Recurse
foreach ($file in $files) {
    $old_filename = $file.Name
    $base_filename = ($old_filename -split '[^a-zA-Z0-9]')[0] # Discard anything after the first non-alphanumeric character
    $new_filename = "$base_filename" + [System.IO.Path]::GetExtension($file)
    Write-Host "$old_filename ==> $new_filename"
    Move-Item -Path $file.Name -Destination $new_filename
}

Pop-Location

