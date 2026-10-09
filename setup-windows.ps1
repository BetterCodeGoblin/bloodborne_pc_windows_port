# One-time Windows setup for building bbport. Run from the repository root:
#     powershell -ExecutionPolicy Bypass -File setup-windows.ps1
# 1. MSYS2 in C:\msys64 (installed if missing) with the MinGW64 toolchain and libraries.
# 2. Git submodules.
# 3. Dependencies MSYS2 does not package (magic_enum, miniz, xbyak) in third_party\win-deps.
# Every download is pinned to a version and SHA-256. No admin rights needed. Game files are
# never downloaded: provide your own decrypted dump of CUSA03173 v1.09.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Root = $PSScriptRoot
$Msys = 'C:\msys64'
$Deps = Join-Path $Root 'third_party\win-deps'
$Work = Join-Path $env:TEMP 'bbport-setup'
New-Item -ItemType Directory -Force $Work | Out-Null

function Fetch($url, $file, $sha256) {
    $path = Join-Path $Work $file
    if (-not (Test-Path $path) -or (Get-FileHash $path -Algorithm SHA256).Hash -ne $sha256.ToUpper()) {
        Write-Host "Downloading $url"
        Invoke-WebRequest $url -OutFile $path -UseBasicParsing
    }
    $actual = (Get-FileHash $path -Algorithm SHA256).Hash
    if ($actual -ne $sha256.ToUpper()) { throw "SHA-256 mismatch for $file`n expected $sha256`n actual   $actual" }
    return $path
}

function MsysBash($command) {
    $env:MSYSTEM = 'MINGW64'; $env:CHERE_INVOKING = '1'
    & "$Msys\usr\bin\bash.exe" -lc $command
    if ($LASTEXITCODE -ne 0) { throw "MSYS2 command failed ($LASTEXITCODE): $command" }
}

# --- 1. MSYS2 ---------------------------------------------------------------------------------
if (-not (Test-Path "$Msys\usr\bin\bash.exe")) {
    if (Test-Path $Msys) { throw "$Msys exists but has no usr\bin\bash.exe; move it aside and rerun." }
    $sfx = Fetch 'https://github.com/msys2/msys2-installer/releases/download/2026-09-27/msys2-base-x86_64-20260927.sfx.exe' `
                 'msys2-base-x86_64-20260927.sfx.exe' 'ad336cccfda47758b5e15cda993fbba421115cb0b126697daef1ee4dfe37209f'
    Write-Host "Extracting MSYS2 to $Msys"
    & $sfx -y -oC:\ | Out-Null
    MsysBash 'true'                                  # first-run initialization (keyring)
}
Write-Host 'Updating MSYS2 and installing packages (this can take a while)'
# Twice: the first run may update the MSYS2 runtime itself and stop.
& "$Msys\usr\bin\bash.exe" -lc 'pacman -Syuu --noconfirm' | Out-Null
MsysBash 'pacman -Syuu --noconfirm'
MsysBash ('pacman -S --needed --noconfirm ' + (@(
    'gcc', 'cmake', 'ninja', 'pkgconf', 'python', 'tk', 'vulkan-headers', 'vulkan-loader',
    'vulkan-memory-allocator', 'fmt', 'boost', 'robin-map', 'xxhash', 'sdl3', 'zydis',
    'glslang', 'ffmpeg', 'spirv-headers') | ForEach-Object { "mingw-w64-x86_64-$_" }) -join ' ')

# --- 2. Submodules ----------------------------------------------------------------------------
Write-Host 'Initializing git submodules'
git -C $Root config core.longpaths true
git -C $Root submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw 'git submodule update failed' }

# --- 3. magic_enum, miniz, xbyak --------------------------------------------------------------
New-Item -ItemType Directory -Force "$Deps\include", "$Deps\lib" | Out-Null
$env:PATH = "$Msys\mingw64\bin;$env:PATH"   # gcc needs its own DLLs and cc1
$me = Fetch 'https://github.com/Neargye/magic_enum/releases/download/v0.9.8/magic_enum-v0.9.8.tar.gz' `
            'magic_enum-v0.9.8.tar.gz' '88709dc8a9697168a75e039470d73ed0cffbc17567976eb5e096f946a2c0d521'
$mz = Fetch 'https://github.com/richgel999/miniz/releases/download/3.1.2/miniz-3.1.2.zip' `
            'miniz-3.1.2.zip' 'f0446d863f9c19926ad9483c523fdc42e42b8d4a6a431d27e09d49c79a140d9a'
$xb = Fetch 'https://github.com/herumi/xbyak/archive/refs/tags/v7.43.tar.gz' `
            'xbyak-v7.43.tar.gz' '8fb0ed1ba0cc299b02aea3da84485083c9779a5c38b652640b2e331b7ca964f1'
foreach ($d in 'magic_enum', 'miniz', 'xbyak') { $p = Join-Path $Work $d; if (Test-Path $p) { Remove-Item -Recurse -Force $p }; New-Item -ItemType Directory $p | Out-Null }
tar -xzf $me -C "$Work\magic_enum"
tar -xf $mz -C "$Work\miniz"
tar -xzf $xb -C "$Work\xbyak" --strip-components=1
Copy-Item -Recurse -Force "$Work\magic_enum\include\magic_enum" "$Deps\include\"
Copy-Item -Recurse -Force "$Work\xbyak\xbyak" "$Deps\include\"
Copy-Item -Force "$Work\miniz\miniz.h" "$Deps\include\"
& "$Msys\mingw64\bin\gcc.exe" -O2 -c "$Work\miniz\miniz.c" -o "$Work\miniz\miniz.o"
if ($LASTEXITCODE -ne 0) { throw 'compiling miniz failed' }
& "$Msys\mingw64\bin\ar.exe" rcs "$Deps\lib\libminiz.a" "$Work\miniz\miniz.o"
if ($LASTEXITCODE -ne 0) { throw 'archiving miniz failed' }

Write-Host ''
Write-Host 'Setup complete. Next:'
Write-Host '  build.bat'
Write-Host '  launch_gui.bat        (select <your dump>\CUSA03173\eboot.bin, v1.09)'
