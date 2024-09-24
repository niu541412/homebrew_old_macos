# homebrew_old_macOS

[TOC]

## Tips for Building Formulae on Deprecated macOS

If you have a deprecated model, such as the Mac Pro 5,1 as mine, the last supported macOS version is 10.13 High Sierra. While the latest [Homebrew](https://brew.sh/) can still run on this system version, pre-built bottles are not provided. Therefore, Homebrew will try to build every formula from source following the [Formula code](https://github.com/Homebrew/homebrew-core/tree/master/Formula). Due to the API limitations of this deprecated macOS, some packages cannot be installed directly with `brew install formula`.

Below is a list of packages that can still be installed using the `brew` command, based on my experience. Most of them require patches or suitable compilers. Note that these tips might not always work due to updates in the upstream source code and Homebrew formula code. Besides, I only garentee that these tips only work on 10.13

Because Homebrew will not recieve pull request for unsupport macOS version, I only leave these tips here.

## General Tips

1. **Use Older Compilers:** Sometimes, modern compilers are not compatible with older macOS versions. Consider using older versions of GCC or Clang.
2. **Patching:** Some formulae might require patching to work correctly on older macOS versions. Check the formula's issues or pull requests for patches or create your own if needed.
3. **Dependencies:** Ensure all dependencies are correctly installed. Sometimes, manual installation of dependencies is required.
4. **Environment Variables:** Setting environment variables like `SDKROOT`, `MACOSX_DEPLOYMENT_TARGET`, and `CFLAGS` can help in building some formulae.

## Formulae with solution

### llvm

- **Issue1:** error: use of undeclared identifier 'CPU_SUBTYPE_ARM64E'
- **Solution:** Modify `/private/tmp/llvm-balabala.../llvm-project-version.src/lldb/source/Host/macosx/objcxx/HostInfoMacOSX.mm` by this patch:

  ```diff
  --- HostInfoMacOSX.mm
  +++ HostInfoMacOSX.mm-new
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
- **Solution:** Recommand to use the previous LLVM as the brew C/C++ compiler, but for building LLVM versions beyond 18, use LLVM 16. Since brew's "-cc=llvm_clang" option only supports the latest LLVM, you can temporarily change the symlink `/usr/local/opt/llvm` to the desired version. Then
  
  `brew install llvm --debug --cc=llvm_clang`
  
  . After installation, revert the symlink to the original. Of course that if you compile the latest LLVM, this symlink will be overridden automatically.


### gcc

- **Issue:** Any buiding errors
- **Solution:** Use a specific version of GCC for compilation.
  `brew install llvm --debug --cc=gcc-14`

### z3

- **Issue:** Undefined symbols: "__ZN12rewriter_tplI17elim_term_ite_cfgEC2ER11ast_managerbRS0_"
- **Solution:** Install the head version. `brew install z3 --HEAD `
- **Reference:** [https://github.com/Z3Prover/z3/issues/6869](#6869)

### gsl (>=2.8)

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

### rust

* **Issue:** Python dependency. Recent rust will use "python" to build libaray. However, in deprecated macOS, "python" is python2.
* **Solution:** Change PATH in debug mode or modify the `configure` file.

### carthage

* **Issue:**  `swift-build-tool -f .build/release.yaml` shows error:
```log
/private/tmp/carthage/Source/XCDBLD/XcodeVersion.swift:18:2: error: missing return in a function expected to return 'Int?
```
* **Solution:** let this function provide a return value, i.e., add **return** before line 18: `version.components(separatedBy: ".").first.flatMap(Int.init)` of "XcodeVersion.swift".

### btop

* **Issue:**  linking errors, Undefined symbols for architecture x86_64:
* **Solution:** Using GCC to build it. However the fomula [.rb file](https://github.com/Homebrew/homebrew-core/blob/master/Formula/b/btop.rb) is mandatroy to use llvm, so need to modify it and install from local. `depends_on "llvm"...` => `depends_on "gcc"...`; `ENV.llvm_clang if OS.mac?...` => `ENV.cxx if OS.mac?...`

### ghostscript

* **Issue:**  Can't build with llvm or recent gcc.
* **Solution:** Use GCC version less than 13.
  `brew install ghostscript --cc=gcc-12 `

### numpy

* **Solution:** Needs GCC or LLVM for compilation.
  `brew install numpy --cc=llvm_clang`

### zig (<=0.9.1_2, higher version not support)

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

### ncdu (>2)

* **Issue:** depends on a recent zig.
* **Solution:** Download the bottle for monterey and modify the link path.

  ```shell
  brew fetch --os monterey ncdu
  tar xf balabala...
  # #if you want homebrew to register it
  # cp -r balabala... $HOMEBREW_PREFIX/Cellar
  # brew link ncdu
  # #but I found brew will clean it when it update...
  # change the link path.
  libncurse_path=$(otool -L /path/to/ncdu | grep libncurse | sed s/\(.*\)//g | sed $'s/^\t//g')
  libncurse_new=${HOMEBREW_PREFIX}$(echo $libncurse_path|sed s/@@HOMEBREW_PREFIX@@//g)
  sudo install_name_tool -change $libncurse_path $libncurse_new /path/to/ncdu 
  ```
* **Tip:** `gdu` provide similar function to `ncdu` which is written in Go.

### openssl@3

* **Issue:** Possible test failures.
* **Solution:** Use debug mode and manually run tests.
  Run `brew install openssl@3 --debug`
  If you encounter an error named "test_cmp_http", enter the shell and execute:
  `make test TESTS='-test_cmp_http'`
  If additional errors occur, append them similarly to `-test_cmp_http`.
* **Reference:** [OpenSSL Issue on GitHub](https://github.com/openssl/openssl/issues/22467#issuecomment-1779402143)

### difftastic

* **Issue:** unknown type name 'CCCryptorStatus'.
* **Solution:** Add header in system file `/usr/include/CommonCrypto/CommonRandom.h`. I think this issue maybe fixed by author later.

  `#include <CommonCrypto/CommonCryptoError.h>`
  
  ~~Then compile with llvm
  `brew install difftastic --cc=llvm_clang`~~
* **Reference:** [can not build mimalloc](https://github.com/microsoft/mimalloc/issues/549)

### doxygen

* **Solution:** Use a higher version of GCC for compilation.
  `brew install doxygen --cc=gcc-14`

### jpeg-xl

* **Solution:** Use a higher version of GCC for compilation.
  `brew install jpeg-xl --cc=gcc-14`

### shared-mime-info

* **Solution:** Use a higher version of GCC for compilation.
  `brew install shared-mime-info --cc=gcc-14`

### libheif

* **Issue:** pkg_config not found package.
```
CMake Error at gdk-pixbuf/CMakeLists.txt:19 (install):
  install TARGETS given no LIBRARY DESTINATION for module target
  "pixbufloader-heif".
```
* **Solution:** do not pre-install pgdk-pixbuf package, or uninstall it then reinstall it again.

~~brew install in debug mode `brew install pkg_config --debug`, then choose to the shell and run cmake with specific flags.~~
  ~~shell
  #first error
  cmake -S . -B build -DWITH_RAV1E=OFF -DWITH_DAV1D=OFF -DWITH_SvtEnc=OFF -DCMAKE_INSTALL_RPATH=@loader_path/../lib -DCMAKE_INSTALL_PREFIX=/usr/local/Cellar/libheif/1.17.6_1 -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_VERBOSE_MAKEFILE=ON -DFETCHCONTENT_FULLY_DISCONNECTED=ON -Wno-dev -DBUILD_TESTING=OFF -DWITH_GDK_PIXBUF=OFF
  #second error
  cmake -S . -B static -DWITH_RAV1E=OFF -DWITH_DAV1D=OFF -DWITH_SvtEnc=OFF -DCMAKE_INSTALL_RPATH=@loader_path/../lib -DCMAKE_INSTALL_PREFIX=/usr/local/Cellar/libheif/1.17.6_1 -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_VERBOSE_MAKEFILE=ON -DFETCHCONTENT_FULLY_DISCONNECTED=ON -Wno-dev -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DWITH_GDK_PIXBUF=OFF~~
