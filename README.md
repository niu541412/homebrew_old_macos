# homebrew_old_macOS

## Tips for Building Formulae on Deprecated macOS

If you have a deprecated model, such as the Mac Pro 5,1 like mine, the last supported macOS version is 10.13 High Sierra. While the latest [Homebrew](https://brew.sh/) can still run on this system, pre-built bottles are not provided. As a result, Homebrew will attempt to build every formula from source according to the [formula code](https://github.com/Homebrew/homebrew-core/tree/master/Formula). Due to API limitations in this deprecated macOS version, some packages cannot be installed directly using `brew install formula`.  

Below is a list of packages that can still be installed via `brew`, based on my experience. Most of them require patches or suitable compilers. However, these tips may not always work due to updates in the upstream source code and Homebrew formula code. Additionally, I can only guarantee that these tips work on macOS 10.13.  

Since Homebrew no longer accepts pull requests for unsupported macOS versions, I am simply sharing these tips here.  

> [!TIP]
>
> 1. **Use Older Compilers:** Sometimes, modern compilers are not compatible with older macOS versions. Consider using older versions of gcc or Clang.
> 2. **Patching:** Some formulae might require patching to work correctly on older macOS versions. Check the formula's issues or pull requests for patches or create your own if needed.
> 3. **Dependencies:** Ensure all dependencies are correctly installed. Sometimes, manual installation of dependencies is required.
> 4. **Environment Variables:** Setting environment variables like `SDKROOT`, `MACOSX_DEPLOYMENT_TARGET`, and `CFLAGS` can help in building some formulae.

## Formulae with solution

### [llvm](https://formulae.brew.sh/formula/llvm)

- **Issue1:** error: use of undeclared identifier 'CPU_SUBTYPE_ARM64E'
- **Solution:** Modify `/private/tmp/llvm-balabala.../llvm-project-version.src/lldb/source/Host/macosx/objcxx/HostInfoMacOSX.mm` by this patch:

  ```diff
  --- HostInfoMacOSX.mm
  +++ HostInfoMacOSX.mm
  @@ -53,6 +53,11 @@
  #define CPU_TYPE_ARM64 (CPU_TYPE_ARM | CPU_ARCH_ABI64)
  #endif

  +#ifndef CPU_SUBTYPE_ARM64E
  +#define CPU_SUBTYPE_ARM64E ((cpu_subtype_t) 2)
  +#endif
  +
  #ifndef CPU_TYPE_ARM64_32
  #define CPU_ARCH_ABI64_32 0x02000000
  #define CPU_TYPE_ARM64_32 (CPU_TYPE_ARM | CPU_ARCH_ABI64_32)
  ```
- **Reference:** [Stack Overflow: How to install llvm@13 on macOS High Sierra](https://stackoverflow.com/questions/69906053/how-to-install-llvm13-with-homerew-on-macos-high-sierra-10-13-6-got-built-tar)
- **Issue2:** Undefined symbols "std::__1::__libcpp_verbose_abort(char const*, ...)" or something like this
- **Solution:** Recommand to use the previous llvm as the brew C/C++ compiler, but for building llvm versions beyond 18, use llvm 16. Since brew's "-cc=llvm_clang" option only supports the latest llvm, you can temporarily change the symlink `/usr/local/opt/llvm` to the desired version. Then

  `brew install llvm --debug --cc=llvm_clang`

  . After installation, revert the symlink to the original. Of course that if you compile the latest llvm, this symlink will be overridden automatically.

> [!NOTE]
> Python > 3.13 may conflict with llvm@16 during the build process. You can temporarily uninstall python forcefully and reinstall it later.

### [gcc](https://formulae.brew.sh/formula/gcc)

- **Issue:** Any buiding errors
- **Solution:** Use a specific version of gcc for compilation. `brew install gcc --debug --cc=gcc-14`

### [ruby](https://formulae.brew.sh/formula/ruby)

- **Issue:**

```log
ld: 8 duplicate symbols for architecture x86_64
```

- **Solution:** Use a specific version of gcc for compilation. `brew install ruby --debug --cc=gcc-14`
- **Issuse2:** `Errno::ENOENT: No such file or directory @ apply2files...`
- **Solution:** Replace tar as following this [link](https://github.com/koekeishiya/yabai/issues/1208#issuecomment-1171165126).

### [z3](https://formulae.brew.sh/formula/z3)

- **Issue:** Undefined symbols: "__ZN12rewriter_tplI17elim_term_ite_cfgEC2ER11ast_managerbRS0_"
- **Solution:** Install the head version. `brew install z3 --HEAD `
- **Reference:** [https://github.com/Z3Prover/z3/issues/6869](#6869)

### [gsl (&gt;=2.8)](https://formulae.brew.sh/formula/gsl "&gt;=2.8")

* **Issue:** ld parameter issue.
* **Solution:** Patch `configure` script.

  ```diff
  --- a/configure
  +++ b/configure
  @@ -8763,6 +8763,8 @@ printf "%s\n" "$lt_cv_ld_force_load" >&6
         case $MACOSX_DEPLOYMENT_TARGET,$host in
           10.[012],*|,*powerpc*-darwin[5-8]*)
             _lt_dar_allow_undefined='$wl-flat_namespace $wl-undefined ${wl}suppress' ;;
  +        *-darwin1[0-9].*)
  +          _lt_dar_allow_undefined='$wl-undefined ${wl}dynamic_lookup' ;;
           *)
             _lt_dar_allow_undefined='$wl-undefined ${wl}dynamic_lookup $wl-no_fixup_chains' ;;
         esac
  ```

### [rust](https://formulae.brew.sh/formula/rust)

- ~~<= 1.82.0~~
  ~~* **Issue1:** Python dependency. Recent rust will use "python" to build libaray. However, in deprecated macOS, "python" is python2.~~
  ~~* **Solution:** Change PATH in debug mode or modify the `configure` file.~~
  ~~* **Issue2:** /usr/local/Cellar/llvm/19.1.2/include/llvm/CodeGen/MachineFunction.h:440:39: error: call to unavailable function 'get': introduced in macOS 10.14~~
  ~~* **Solution:** use llvm 17, you can temporarily change the symlink `/usr/local/opt/llvm` to the desired version. llvm is mandatory to compile in rust formula.~~
- \>1.83.0

  - **Solution:** use llvm 18, you can temporarily change the symlink `/usr/local/opt/llvm` to the desired version. llvm is mandatory to compile in rust formula.
- \>1.84.0

  - **Issue:** `call to unavailable member function 'value': introduced in macOS 10.14`
  - **Solution:** patch `rustc-balabala-src/compiler/rustc_llvm/llvm-wrapper/RustWrapper.cpp` with

  ```diff
  --- RustWrapper.cpp	2025-01-15 20:39:28
  +++ RustWrapper.cpp	2025-01-15 20:39:53
  @@ -1310,7 +1310,7 @@ llvmRustDILocationCloneWithBaseDiscriminator(llvmMetad
                                                unsigned BD) {
    DILocation *Loc = unwrapDIPtr<DILocation>(Location);
    auto NewLoc = Loc->cloneWithBaseDiscriminator(BD);
  -  return wrap(NewLoc.has_value() ? NewLoc.value() : nullptr);
  +  return wrap(NewLoc.has_value() ? *NewLoc : nullptr);
  }

  extern "C" uint64_t llvmRustDIBuilderCreateOpDeref() {
  ```
> [!NOTE]
> Do not add `--cc=llvm_clang` option when you build rust formula because it will fail to find `llvm-ar`.
> Maybe also need llvm 18 and need to run `make`, `build/bootstrap/debug/bootstrap build --stage 2 -v` or `VERBOSE=1 make` to get the failed command and then manually in the shell after errors with the brew command.


### [openjdk@17](https://formulae.brew.sh/formula/openjdk@17)

- **Issue:** `cuse of undeclared identifier 'NSBundleExecutableArchitectureARM64'`
- **Solution:**patch `jdk17u-jdk-17.balabala-ga/src/java.desktop/macosx/native/libawt_lwawt/awt/CGraphicsDevice.m` with
  ```diff
  --- CGraphicsDevice.m   2025-01-19 19:53:36.000000000 +0800
  +++ CGraphicsDevice.m   2025-01-19 19:55:30.000000000 +0800
  @@ -28,6 +28,10 @@
  #include "GeomUtilities.h"
  #include "JNIUtilities.h"

  +#ifndef NSBundleExecutableArchitectureARM64
  +#define NSBundleExecutableArchitectureARM64 0x0100000c
  +#endif
  +
  /**
    * Some default values for invalid CoreGraphics display ID.
    */
  ```

  And use llvm 16 to compile `brew install openjdk@17 --cc=llvm_clang`. It seems it's to due to llvm (>=17) use the dynamic library cache of macOS which is not compatible with the old version. See 2nd Kernel issue of [Release Note](https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-release-notes#Kernel).

### [ghc](https://formulae.brew.sh/formula/ghc)
* **Issue:** `error: instruction requires: AVX-512 ISA`.
* **Solution:** Use llvm compile with specific version. `brew install ghc --cc=llvm_clang`

### [icu4c@76](https://formulae.brew.sh/formula/icu4c@76)
* **Issue:** `configure:9742: error: Python failed to run`, icu4c uses "python" to build it. However, in deprecated macOS, "python" is python2.
* **Solution:** Add `depends_on "python"` into the local rb file.

### [carthage](https://formulae.brew.sh/formula/carthage)
* **Issue:**  `swift-build-tool -f .build/release.yaml` shows error:
```log
/private/tmp/carthage/Source/XCDBLD/XcodeVersion.swift:18:2: error: missing return in a function expected to return 'Int?
```
* **Solution:** let this function provide a return value, i.e., add **return** before line 18: `version.components(separatedBy: ".").first.flatMap(Int.init)` of "XcodeVersion.swift".

### [btop](https://formulae.brew.sh/formula/btop)
* **Issue:** linking errors, Undefined symbols for architecture x86_64:
* **Solution1:** Use llvm. Add `ENV.append "LDFLAGS", "-L#{Formula["llvm"].opt_lib}/c++"` before the make command  to avoid the linking error.
* **Solution2:** Use gcc to build it. However the formula [.rb file](https://github.com/Homebrew/homebrew-core/blob/master/Formula/b/btop.rb) is mandatory to use llvm, so need to modify it and install from local. `depends_on "llvm"...` => `depends_on "gcc"...`; `ENV.llvm_clang if OS.mac?...` => `ENV.cxx if OS.mac?...`


### [tesseract](https://formulae.brew.sh/formula/tesseract)

* **Issue:** fatal error: `filesystem` file not found
* **Solution:** For the src file using header `filesystem`, e.g. baseapi.cpp, ccutil.cpp, use the code in 5.4.0 version. Remove training options during `make` and `make install` steps.

### [ghostscript](https://formulae.brew.sh/formula/ghostscript)

* **Issue:**  Can't build with llvm or recent gcc.
* **Solution:** Use gcc compile with specific version. `brew install ghostscript --cc=gcc-xx`

### [numpy](https://formulae.brew.sh/formula/numpy), [lftp](https://formulae.brew.sh/formula/lftp)

* **Solution:** Needs gcc or llvm for compilation. `brew install formula --cc=llvm_clang` or `brew install formula --cc=gcc-xx`

### [coreutils](https://formulae.brew.sh/formula/coreutils)
* **Solution:** Use llvm. `brew install coreutils --cc=llvm_clang`

### [zig](https://formulae.brew.sh/formula/zig)

> [!WARNING]
> (<=0.9.1_2, higher version not support)

* **Issue:** Compatibility issue.
* **Solution:** Modify `os_version_check.zig`.
  ```diff
  diff --git a/lib/std/special/compiler_rt/os_version_check.zig b/lib/std/special/compiler_rt/os_version_check.zig
  index d7408e2..e4bfbce 100644
  --- a/lib/std/special/compiler_rt/os_version_check.zig
  +++ b/lib/std/special/compiler_rt/os_version_check.zig
  @@ -22,12 +22,11 @@ inline fn constructVersion(major: u32, minor: u32, subminor: u32) u32 {

  // Darwin-only
  pub fn __isPlatformVersionAtLeast(platform: u32, major: u32, minor: u32, subminor: u32) callconv(.C) i32 {
  -    return @boolToInt(_availability_version_check(1, &[_]dyld_build_version_t{
  -        .{
  -            .platform = platform,
  -            .version = constructVersion(major, minor, subminor),
  -        },
  -    }));
  +    const build_version = dyld_build_version_t{
  +        .platform = platform,
  +        .version = constructVersion(major, minor, subminor),
  +    };
  +    return @boolToInt(&[_]dyld_build_version_t{build_version} == &[_]dyld_build_version_t{build_version});
  }
  ```

- **Reference** [https://github.com/ziglang/zig/issues/10318](#10318), [https://github.com/ziglang/zig/pull/11684](#11684)

### [ncdu (&gt;2)](https://formulae.brew.sh/formula/ncdu "&gt;2")

* **Issue:** depends on a recent zig.
* **Solution:** Download the bottle for monterey and modify the link path.

  ```shell
  # uninstall old version
  brew uninstall ncdu
  tarball=$(brew fetch --os ventura ncdu|grep Downloading|grep -o ncdu.*tar\.gz)
  tar xzf $HOME/Library/Caches/Homebrew/downloads/*${tarball} -C .
  # #if you want homebrew to register it
  mv ncdu $HOMEBREW_PREFIX/Cellar
  brew link ncdu
  # #but I found brew may clean it when it update...
  # change the link path.
  ncdu_executable=$(brew --prefix ncdu)/bin/ncdu
  libncurse_path=$(otool -L $ncdu_executable| grep libncurse | sed s/\(.*\)//g | sed $'s/^\t//g')
  libncurse_new=${HOMEBREW_PREFIX}$(echo $libncurse_path|sed s/@@HOMEBREW_PREFIX@@//g)
  sudo install_name_tool -change $libncurse_path $libncurse_new $ncdu_executable
  ```

> [!NOTE]
> [`gdu`](https://github.com/dundee/gdu) which is written in go provides similar function to `ncdu`.

### [openssl@3](https://formulae.brew.sh/formula/openssl@3)
* **Issue:** Possible test failures.
* **Solution:** Use debug mode and manually run tests.
  Run `brew install openssl@3 --debug`
  If you encounter an error named "test_cmp_http", enter the shell and execute:
  `make test TESTS='-test_cmp_http'`
  If additional errors occur, append them similarly to `-test_cmp_http`.
* **Reference:** [OpenSSL Issue on GitHub](https://github.com/openssl/openssl/issues/22467#issuecomment-1779402143)

### [difftastic](https://formulae.brew.sh/formula/difftastic)
* **Issue:** unknown type name 'CCCryptorStatus'.
* **Solution:** Add header in system file `/usr/include/CommonCrypto/CommonRandom.h`. I think this issue maybe fixed by author later.

  `#include <CommonCrypto/CommonCryptoError.h>`

  ~~Then compile with llvm
  `brew install difftastic --cc=llvm_clang`~~
* **Reference:** [can not build mimalloc](https://github.com/microsoft/mimalloc/issues/549)

### [doxygen](https://formulae.brew.sh/formula/doxygen)
* **Solution:** Use a higher version of gcc for compilation. `brew install doxygen --cc=gcc-14`

### [wget](https://formulae.brew.sh/formula/wget)
* **Issue:** `configure: error: --with-ssl=openssl was given, but SSL is not available.`
* **Solution:** libssl.dylib provided by macOS don't have `_OPENSSL_init_ssl` symbol. Set LDFLAGS include /usr/local/lib to use the libssl provided by homebrew.

### [jpeg-xl](https://formulae.brew.sh/formula/jpeg-xl)
* **Solution:** Use a specific version (maybe <14) of gcc for compilation. `brew install jpeg-xl --cc=gcc-13`

### [libavif](https://formulae.brew.sh/formula/)
* **Issue:** `CMake Error at build/_deps/libargparse-src/CMakeLists.txt:24:
  Parse error.  Expected a newline, got identifier with text "ninstall".`
* **Solution:** Edit `build/_deps/libargparse-src/CMakeLists.txt`, change `...(GNUInstallDirs)\\\\ninstall(TARGETS...` to 
```
...(GNUInstallDirs)
install(TARGETS...
```
.


### [shared-mime-info](https://formulae.brew.sh/formula/shared-mime-info)
* **Solution:** Use a higher version of gcc for compilation. `brew install shared-mime-info --cc=gcc-14`

### [openexr](https://formulae.brew.sh/formula/openexr)
* **Solution:** Use a higher version of gcc for compilation. `brew install openexr --cc=gcc-14`

### [gdk-pixbuf](https://formulae.brew.sh/formula/gdk-pixbuf)
* **Issue:** `Dependency lookup for libtiff-4 with method 'pkgconfig' failed: Could not generate cflags for libtiff-4: Package libdeflate was not found in the pkg-config search path.`
* **Solution:** Add `depends_on "libdeflate"` into  gdk-pixbuf.rb file, or add the the pkgconfig path of libdeflate into the environment variable `PKG_CONFIG_PATH`.

### [libheif](https://formulae.brew.sh/formula/libheif)

* **Issue1:** `/tmp/libheif-20241109-81439-f0emb6/libheif-1.19.2/libheif/bitstream.cc:26:10: fatal error: 'bit' file not found`. "bit" is a standard library header since C++20 (gcc>=9 or llvm>=11).
* **Solution1:** Use gcc or llvm for compilation. `brew install libheif --cc=gcc-xx`
* **Issue2:** pkg_config not found package.

```
CMake Error at gdk-pixbuf/CMakeLists.txt:19 (install):
  install TARGETS given no LIBRARY DESTINATION for module target
  "pixbufloader-heif".
```

* **Solution2:** do not pre-install gdk-pixbuf package, or uninstall it then reinstall it again.
~~brew install in debug mode `brew install libheif --debug`, then choose to the shell and run cmake with specific flags.~~
  ~~shell
  #first error
  cmake -S . -B build -DWITH_RAV1E=OFF -DWITH_DAV1D=OFF -DWITH_SvtEnc=OFF -DCMAKE_INSTALL_RPATH=@loader_path/../lib -DCMAKE_INSTALL_PREFIX=/usr/local/Cellar/libheif/1.17.6_1 -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_VERBOSE_MAKEFILE=ON -DFETCHCONTENT_FULLY_DISCONNECTED=ON -Wno-dev -DBUILD_TESTING=OFF -DWITH_GDK_PIXBUF=OFF
  #second error
  cmake -S . -B static -DWITH_RAV1E=OFF -DWITH_DAV1D=OFF -DWITH_SvtEnc=OFF -DCMAKE_INSTALL_RPATH=@loader_path/../lib -DCMAKE_INSTALL_PREFIX=/usr/local/Cellar/libheif/1.17.6_1 -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_VERBOSE_MAKEFILE=ON -DFETCHCONTENT_FULLY_DISCONNECTED=ON -Wno-dev -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DWITH_GDK_PIXBUF=OFF~~

### [snappy](https://formulae.brew.sh/formula/snappy), [abseil](https://formulae.brew.sh/formula/abseil), [protobuf](https://formulae.brew.sh/formula/protobuf)
- **Issue:** Linking error.
- **Solution1:** Use llvm `brew install formula --cc=llvm_clang`.
Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command
`cmake -S . -B balabala...` to avoid the linking error.

### [sdl2](https://formulae.brew.sh/formula/sdl2)
* **Issue:** `error: use of undeclared identifier 'kAudioChannelLayoutTag_WAVE_6_1' 'kAudioChannelLayoutTag_WAVE_7_1'`
* **Solution:** Modify `/private/tmp/sdl2-balabala.../src/audio/coreaudio/SDL_coreaudio.m` by this patch:

  ```diff
  --- SDL_coreaudio.m     2025-01-17 00:24:16.000000000 +0800
  +++ SDL_coreaudio.m     2025-01-17 00:20:11.000000000 +0800
  @@ -23,6 +23,14 @@
  #ifdef SDL_AUDIO_DRIVER_COREAUDIO

  /* !!! FIXME: clean out some of the macro salsa in here. */
  +#ifndef kAudioChannelLayoutTag_WAVE_6_1
  +#define kAudioChannelLayoutTag_WAVE_6_1 ((188U << 16) | 7)                     ///< 7 channels, L R C LFE Cs Ls Rs
  +#endif
  +
  +#ifndef kAudioChannelLayoutTag_WAVE_7_1
  +#define kAudioChannelLayoutTag_WAVE_7_1 ((188U << 16) | 8)                   ///< 8 channels, L R C LFE Rls Rrs Ls Rs
  +#endif
  +

  #include "SDL_audio.h"
  #include "SDL_hints.h"
  ```

### [folly](https://formulae.brew.sh/formula/folly)
- **Issue1:** `    AsyncSocket::failRead(__func__, ex);
                 ^~~~~~~~
fatal error: too many errors emitted, stopping now [-ferror-limit=]`
- **Solution:** Append the following macros content to `#include <folly/io/async/fdsock/SocketFds.h>` in `folly-balabala/folly/io/async/fdsock/AsyncFdSocket.h`:
```c++
#ifdef __APPLE__
#include <AvailabilityMacros.h>
#if MAC_OS_X_VERSION_MIN_REQUIRED < 110000
#ifdef __DARWIN_ALIGN32
#undef __DARWIN_ALIGN32
#define __DARWIN_ALIGN32(p) ((__darwin_size_t)((__darwin_size_t)(p) + __DARWIN_ALIGNBYTES32) &~ __DARWIN_ALIGNBYTES32)
#endif
#endif
#endif
```
- **Reference:** [Installation with homebrew fails (Mac) #2031](https://github.com/facebook/folly/issues/2031#issuecomment-1752127213)

- **Issue2:**  Linker error
- **Solution:** Use llvm `brew install folly --cc=llvm_clang`.
  + Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command
`cmake -S . -B build/shared balabala...` to avoid the linking error.
  + Add `-DCMAKE_STATIC_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command
`cmake -S . -B build/static balabala...` to avoid the linking error.


### [poppler](https://formulae.brew.sh/formula/poppler)
- **Issue2:**  Linker error
- **Solution:** Use llvm `brew install poppler --cc=llvm_clang`.
  + Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command `cmake -S . -B build/shared balabala...` to avoid the linking error.
  + Add `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command `cmake -S . -B build/static balabala...` to avoid the linking error.


### [freerdp](https://formulae.brew.sh/formula/freerdp)
- **Issue2:**  Linker error
- **Solution:** Use llvm `brew install freerdp --cc=llvm_clang`.
  + Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command `cmake -S . -B build/shared balabala...` to avoid the linking error.


### [pandoc](https://formulae.brew.sh/formula/pandoc)
- **Issue:**  
```
Error: [Cabal-7107]
Could not resolve dependencies:
[__0] trying: pandoc-3.6.3 (user goal)
[__1] trying: tls-2.1.7 (dependency of pandoc)
[__2] trying: serialise-0.2.6.1 (dependency of tls)
[__3] next goal: base (dependency of pandoc)
[__3] rejecting: base-4.21.0.0/installed-inplace (conflict: serialise => base>=4.11 && <4.21)
[__3] skipping: base-4.21.0.0 (has the same characteristics that caused the previous version to fail: excluded by constraint '>=4.11 && <4.21' from 'serialise')
```
- **Solution:** Add `--allow-newer` to the `cabal v2-install balabala...` command and use LLVM 18 `brew install folly --cc=llvm_clang`.
- **Reference:** [Running into depdency conflicts when running cabal test](https://github.com/jgm/pandoc/issues/10597)