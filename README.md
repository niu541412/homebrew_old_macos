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
- **Solution:** Use llvm for compilation. `brew install llvm --debug --cc=llvm_clang`
  + Add `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the `args` list to avoid the linking error.
- **Issue3:** Undefined symbols 
```
"__availability_version_check", referenced from:
      ___isPlatformVersionAtLeast in libclang_rt.osx.a(os_version_check.c.o)
      __initializeAvailabilityCheck in libclang_rt.osx.a(os_version_check.c.o)
```
- **Solution:** In debug mode, modify `llvm/build/build.ninja` file : add `lib/clang/20/lib/darwin/libclang_rt.osx.a` to the `LINK_LIBRARIES` variable of failed command, e.g. `Link the shared library lib/liblldb.20.1.2.dylib` and `Link the executable bin/lldb-server` (Testing...). 

~~- **Solution:** Recommand to use the previous llvm as the brew C/C++ compiler, but for building llvm versions beyond 18, use llvm 16. Since brew's "-cc=llvm_clang" option only supports the latest llvm, you can temporarily change the symlink `/usr/local/opt/llvm` to the desired version. Then~~
  ~~`brew install llvm --debug --cc=llvm_clang`~~
  ~~. After installation, revert the symlink to the original. Of course that if you compile the latest llvm, this symlink will be overridden automatically.~~

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

### [php](https://formulae.brew.sh/formula/php)

- **Issue:**

```log
Zend/zend_atomic.h:85:9: error: address argument to atomic operation must be a pointer to non-const _Atomic type ('const _Atomic(bool) *' invalid)
        return __c11_atomic_load(&obj->value, __ATOMIC_SEQ_CST);
               ^                 ~~~~~~~~~~~
```

- **Solution:** Use a specific version of llvm for compilation. `brew install php --debug --cc=llvm_clang` or modify the `Zend/zend_atomic.h` file as the following reference url.
- **Reference:** [#8881](https://github.com/php/php-src/issues/8881)

### [cmake](https://formulae.brew.sh/formula/cmake)(>=4.0)

- **Issue:**

```log
In file included from /private/tmp/cmake-20250403-51275-k5zrwe/cmake-4.0.0/Source/cmArgumentParser.cxx:8:
In file included from /private/tmp/cmake-20250403-51275-k5zrwe/cmake-4.0.0/Source/cmMakefile.h:15:
In file included from //Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/unordered_map:369:
In file included from //Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/__hash_table:19:
//Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/cmath:313:9: error: no member named 'signbit' in the global
      namespace
```
- **Solution:** patch file `Modules/Platform/Darwin-Initialize.cmake` with
```diff
--- Darwin-Initialize.cmake
+++ Darwin-Initialize.cmake
@@ -276,6 +276,8 @@ elseif(CMAKE_OSX_SYSROOT)
     set(CMAKE_OSX_SYSROOT "${_CMAKE_OSX_SYSROOT_PATH}")
   endif()
 endif()
+
+if(APPLE AND CMAKE_HOST_SYSTEM_VERSION VERSION_GREATER_EQUAL "19.0.0")
 if(NOT CMAKE_OSX_SYSROOT)
   # Without any explicit SDK we rely on the toolchain default,
   # which we assume to be what wrappers like /usr/bin/cc use.
@@ -293,3 +295,4 @@ if(NOT CMAKE_OSX_SYSROOT)
   )
   unset(_sdk_macosx)
 endif()
+endif()
```
.

~~- **Solution:**~~
  ~~In debug mode, `brew install cmake --debug`, add `-isystem /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1` to these `flags.make` in the path `Source/CMakeFiles/*.dir/` and `CursesDialog/CMakeFiles/ccmake.dir`. It's due to `/usr/include/math.h` doesn't have the function `signbit` defined.~~
~~- **Reference:** [1](https://stackoverflow.com/questions/58628377), [2](http://dengxiaolong.com/article/2020/08/mac-1015-compilation-of-spoole-failed.html).~~

### [z3](https://formulae.brew.sh/formula/z3)

- **Issue:** Undefined symbols: "__ZN12rewriter_tplI17elim_term_ite_cfgEC2ER11ast_managerbRS0_"
- **Solution:** Install the head version. `brew install z3 --HEAD `
- **Reference:** [#6869](https://github.com/Z3Prover/z3/issues/6869).

### [gsl](https://formulae.brew.sh/formula/gsl)(>=2.8)

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
- \>=1.83.0

  - **Issue1:** `TypeError: split() takes no keyword arguments`
  - **Solution:** The builtin python in macOS is python2, which doesn't support the `split` function with keyword arguments.
    add `depends_on "python" => :build` to the rb file and comment out `uses_from_macos "python" => :build` in the rb fike.
  - **Issue2:** `call to unavailable member function 'value': introduced in macOS 10.14`
  - **Solution:** patch `rustc-balabala-src/compiler/rustc_llvm/llvm-wrapper/RustWrapper.cpp` with

  ```diff
  --- RustWrapper.cpp
  +++ RustWrapper.cpp
  @@ -1387,7 +1387,7 @@ llvmRustDILocationCloneWithBaseDiscriminator(llvmMetad
                                                unsigned BD) {
    DILocation *Loc = unwrapDIPtr<DILocation>(Location);
    auto NewLoc = Loc->cloneWithBaseDiscriminator(BD);
  -  return wrap(NewLoc.has_value() ? NewLoc.value() : nullptr);
  +  return wrap(NewLoc.has_value() ? *NewLoc : nullptr);
  }

  extern "C" uint64_t llvmRustDIBuilderCreateOpDeref() {
  ```

  And add `ENV.prepend_path "PATH", Formula["llvm"].opt_bin` to the rb file.

  - **Issue3:** `couldn't find required command: "llvm_ar"`
  - **Solution:** patch `rustc-balabala-src/src/bootstrap/src/utils/cc_detect.rs` with

  ```diff
  --- cc_detect.rs
  +++ cc_detect.rs
  @@ -62,7 +62,8 @@ fn cc2ar(cc: &Path, target: TargetSelect
            for suffix in &["gcc", "cc", "clang"] {
                if let Some(idx) = file.rfind(suffix) {
                    let mut file = file[..idx].to_owned();
  -                file.push_str("ar");
  +                file.pop();
  +                file.push_str("-ar");
                    return Some(parent.join(&file));
                }
            }
  ```

  - **Issue4:** `ld: symbol(s) not found for architecture x86_64`
  - **Solution:** add configure parameter `--llvm-ldflags=-L#{Formula["llvm"].opt_lib}/c++` to the rb file. If
    still not work, try to temporally hide `/usr/lib/libc++.dylib`.

### [harfbuzz](https://formulae.brew.sh/formula/harfbuzz)

- **Issue:** `../src/hb-coretext.cc:210:31: error: use of undeclared identifier 'CTFontManagerCreateFontDescriptorsFromData'; did you mean 'CTFontManagerCreateFontDescriptorFromData'?`
- **Solution:** patch `src/hb-coretext.cc` with:
```diff
--- a/src/hb-coretext.cc
+++ b/src/hb-coretext.cc
@@ -34,6 +34,8 @@
 
 #include "hb-coretext.hh"
 
+extern "C" CFArrayRef CTFontManagerCreateFontDescriptorsFromData(CFDataRef data) CT_AVAILABLE(macos(10.13), ios(7.0), watchos(2.0), tvos(9.0));
+
 /**
  * SECTION:hb-coretext
  * @title: hb-coretext
```

to `/System/Library/Frameworks/CoreText.framework/Versions/A/Headers/CTFontManager.h`.
It's seems `CTFontManagerCreateFontDescriptorsFromData` is forgot to declare in macOS 10.13

### [librsvg](https://formulae.brew.sh/formula/librsvg)

~~**Issue1:** `subprocess.CalledProcessError: Command '[PosixPath('/usr/bin/nm'), '--defined-only', '-g', 'rsvg/librsvg_2.a']' returned non-zero exit status 1.`~~
~~`/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm: /private/tmp/librsvg-20250304-48945-hfcy5l/librsvg-2.59.2/build/rsvg/librsvg_2.a(std-c5c1ffaef87f3f54.std.5e7d81c0803c9b5b-cgu.00.rcgu.o) Invalid value (Producer: 'LLVM18.1.8' Reader: 'LLVM APPLE_1_1000.11.45.5_0')`~~
~~**Solution:** The nm which is provided by macOS is not compatible with the rust. Use the llvm-nm of the llvm version which matched the rust instead, e.g., add `ENV.prepend_path "PATH", Formula["llvm@18"].opt_bin` into the rb file.~~

* **Issue:** `Command `/private/tmp/librsvg-20250319-26233-r4tyc1/librsvg-2.60.0/meson/makedef.py --regex '^rsvg_.' --os darwin --prefix _ --list /private/tmp/librsvg-20250319-26233-r4tyc1/librsvg-2.60.0/rsvg/../win32/librsvg.symbols /private/tmp/librsvg-20250319-26233-r4tyc1/librsvg-2.60.0/rsvg/../win32/librsvg-pixbuf.symbols ` failed with status 127.`
* **Solution:** Add `depends_on "python"` into the local rb file.

### [openjdk@17](https://formulae.brew.sh/formula/openjdk@17)

- **Issue:** `cuse of undeclared identifier 'NSBundleExecutableArchitectureARM64'`
- **Solution:**patch `jdk17u-jdk-17.balabala-ga/src/java.desktop/macosx/native/libawt_lwawt/awt/CGraphicsDevice.m` with

  ```diff
  --- CGraphicsDevice.m
  +++ CGraphicsDevice.m
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

### [netpbm](https://formulae.brew.sh/formula/netpbm)

* **Issue:** 
* **Solution:** Add `depends_on "python"` into the local rb file.

### [pango](https://formulae.brew.sh/formula/pango)

* **Issue:** `Python failed to run`
* **Solution:** Add `depends_on "python"` into the local rb file.

### [carthage](https://formulae.brew.sh/formula/carthage)

* **Issue:**  `swift-build-tool -f .build/release.yaml` shows error:

```log
/private/tmp/carthage/Source/XCDBLD/XcodeVersion.swift:18:2: error: missing return in a function expected to return 'Int?
```

* **Solution:** let this function provide a return value, i.e., add **return** before line 18: `version.components(separatedBy: ".").first.flatMap(Int.init)` of "XcodeVersion.swift".

### [btop](https://formulae.brew.sh/formula/btop)

* **Issue:** linking errors, Undefined symbols for architecture x86_64:
* **Solution1:** Use llvm. Add `ENV.append "LDFLAGS", "-L#{Formula["llvm"].opt_lib}/c++"` before the make command to avoid the linking error, but do not add `--cc=llvm_clang` to the end.
* **Solution2:** Use gcc to build it. However the formula [.rb file](https://github.com/Homebrew/homebrew-core/blob/master/Formula/b/btop.rb) is mandatory to use llvm, so need to modify it and install from local. `depends_on "llvm"...` => `depends_on "gcc"...`; `ENV.llvm_clang if OS.mac?...` => `ENV.cxx if OS.mac?...`

### [node](https://formulae.brew.sh/formula/node)(>=23.9)

> [!IMPORTANT]
> node>=23.9 only suppport in macOS Catalina and later. Besides, node>=16.X can only be built in macOS>= 10.14 (Xcode >=11), see [macOS 10.13/Xcode 10.1 due to missing os/signpost.h](https://github.com/nodejs/node/issues/39584#issuecomment-889692761).

* **Issue:** linking errors, Undefined symbols for architecture x86_64:
* **Solution:** Use llvm. Add `ENV.append "LDFLAGS", "-L#{Formula["llvm"].opt_lib}/c++"` before the make command  to avoid the linking error.

### [tesseract](https://formulae.brew.sh/formula/tesseract)

* **Issue:** fatal error: `filesystem` file not found
* **Solution:** Use llvm to build, i.e. brew install tesseract --cc=llvm_clang. BTW, remove `training` options during `make` and `make install` steps (not sure).

### [ghostscript](https://formulae.brew.sh/formula/ghostscript)

* **Issue1:** Linking error caused by `tesseract`
* **Solution:** Currently no good solution, just remove the `tesseract` dependence in the rb file.
* **Issue2:**  Can't build with llvm or recent gcc.
* **Solution:** Use gcc compile with specific version. `brew install ghostscript --cc=gcc-xx`

### [numpy](https://formulae.brew.sh/formula/numpy), [lftp](https://formulae.brew.sh/formula/lftp)

* **Solution:** Needs gcc or llvm for compilation. `brew install formula --cc=llvm_clang` or `brew install formula --cc=gcc-xx`

### [coreutils](https://formulae.brew.sh/formula/coreutils)

* **Solution:** Use llvm. `brew install coreutils --cc=llvm_clang`

### [zig](https://formulae.brew.sh/formula/zig)(<=0.9.1_2)

> [!WARNING]
> (<=0.9.1_2, higher version not support)

* **Issue:** Compatibility issue.
* **Solution:** Modify `lib/std/special/compiler_rt/os_version_check.zig` with this patch:
  ```diff
  --- os_version_check.zig
  +++ os_version_check.zig
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

- **Reference** [#10318](https://github.com/ziglang/zig/issues/10318), [#11684](https://github.com/ziglang/zig/pull/11684)

### [ncdu](https://formulae.brew.sh/formula/ncdu)(>2)

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

### [icu4c@77](https://formulae.brew.sh/formula/icu4c@77)

* **Issue:** `measunit_extra.cpp:577:13: error: call to 'abs' is ambiguous`
* **Solution:** Use gcc or llvm to compile.

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

### [gd](https://formulae.brew.sh/formula/gd)

* **Issue:** `Undefined symbols for architecture x86_64: "_aom_codec_av1_cx", referenced from: _aomCodecEncodeImage in libavif.a(codec_aom.c.o)`
* **Solution:** Add `depends_on "aom"` and `ENV.append "LDFLAGS", "-L#{Formula["aom"].lib} -laom"` to the rb file.

### [jpeg-xl](https://formulae.brew.sh/formula/jpeg-xl)

* **Solution:** Use a specific version (maybe <14) of gcc for compilation. `brew install jpeg-xl --cc=gcc-xx`
* **Reference:** [MacOS brew install jpeg-xl error](https://github.com/libjxl/libjxl/issues/2461)

### [libavif](https://formulae.brew.sh/formula/libavif)

* **Issue:** `CMake Error at build/_deps/libargparse-src/CMakeLists.txt:24: Parse error.  Expected a newline, got identifier with text "ninstall".`
* **Solution:** Edit `build/_deps/libargparse-src/CMakeLists.txt`, change `include(GNUInstallDirs)ninstall(TARGETS libargparse ...` to

```
include(GNUInstallDirs)
install(TARGETS libargparse...
```

.

### [chafa](https://formulae.brew.sh/formula/chafa)

* **Issue:**

```
Undefined symbols for architecture x86_64:
  "_aom_codec_av1_cx", referenced from:
      _aomCodecEncodeImage in libavif.a(codec_aom.c.o)
```

* **Solution:** add libaom in during linking, e.g., add `ENV["LIBS"] = "-laom"` to rb file.

### [shared-mime-info](https://formulae.brew.sh/formula/shared-mime-info)

* **Solution:** Use a higher version of gcc for compilation. `brew install shared-mime-info --cc=gcc-14`

### [openexr](https://formulae.brew.sh/formula/openexr)

* **Solution:** Use a higher version of gcc for compilation. `brew install openexr --cc=gcc-14`

### [gdk-pixbuf](https://formulae.brew.sh/formula/gdk-pixbuf)

* **Issue:** `Dependency lookup for libtiff-4 with method 'pkgconfig' failed: Could not generate cflags for libtiff-4: Package libdeflate was not found in the pkg-config search path.`
* **Solution:** Reinstall `libtiff` because it add useless dependence in pkgconfig file. ~~Add `depends_on "libdeflate"` into  gdk-pixbuf.rb file, or add the the pkgconfig path of libdeflate into the environment variable `PKG_CONFIG_PATH`.~~

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
  --- SDL_coreaudio.m
  +++ SDL_coreaudio.m
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

- **Issue1:** `    AsyncSocket::failRead(__func__, ex); ^~~~~~~~ fatal error: too many errors emitted, stopping now [-ferror-limit=]`
- **Solution:** patch  `folly-balabala/folly/io/async/fdsock/AsyncFdSocket.h` with:

```diff
--- AsyncFdSocket.h
+++ AsyncFdSocket.h
@@ -20,6 +20,16 @@
 #include <folly/io/async/fdsock/SocketFds.h>
 #include <folly/portability/GTestProd.h>
 
+#ifdef __APPLE__
+#include <AvailabilityMacros.h>
+#if MAC_OS_X_VERSION_MIN_REQUIRED < 110000
+#ifdef __DARWIN_ALIGN32
+#undef __DARWIN_ALIGN32
+#define __DARWIN_ALIGN32(p) ((__darwin_size_t)((__darwin_size_t)(p) + __DARWIN_ALIGNBYTES32) &~ __DARWIN_ALIGNBYTES32)
+#endif
+#endif
+#endif
+
 namespace folly {
 
 /**
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

- **Issue 1:** Dependency missing `SDL3`, which is only supported to be built on macOS 11+. See [Bumped deployment requirements](https://github.com/libsdl-org/SDL/commit/cdde6dd7bb182a430f82c5e059122b350df7f1dd). However, it seems it can be deployed to 10.13 with the build on newer macOS.
- **Solution:** Continue using `SDL2`. Modify the [rb](https://github.com/Homebrew/homebrew-core/blob/9040bc413622ff58d9df25e2f8735b062c58eeb5/Formula/f/freerdp.rb) file with the latest FreeRDP tarball.
- **Issue 2:** Linker error
- **Solution:** Use LLVM by running `brew install ./freerdp.rb --cc=llvm_clang`.
  Additionally, add the following flags to the CMake command `cmake -S . -B build/shared ...` to avoid the linking error:
  - `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}`
  - `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}`

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

- **Solution:** Add `--allow-newer` to the `cabal v2-install balabala...` command and use LLVM 18 `brew install pandoc --cc=llvm_clang`.
- **Reference:** [Running into depdency conflicts when running cabal test](https://github.com/jgm/pandoc/issues/10597)
