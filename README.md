# homebrew_old_macOS

## Tips for Building Formulae on Deprecated macOS

If you have a deprecated model, such as the Mac Pro 5,1 like mine, the last supported macOS version is 10.13 High Sierra. While the latest [Homebrew](https://brew.sh/) can still run on this system, pre-built bottles are not provided. As a result, Homebrew will attempt to build every formula from source according to the [formula code](https://github.com/Homebrew/homebrew-core/tree/master/Formula). Due to API limitations in this deprecated macOS version, some packages cannot be installed directly using `brew install formula`.

Below is a list of packages that can still be installed via `brew`, based on my experience. Most of them require patches or suitable compilers. However, these tips may not always work due to updates in the upstream source code and Homebrew formula code. Additionally, I can only guarantee that these tips work on macOS 10.13.

Since Homebrew no longer accepts pull requests for unsupported macOS versions, I am simply sharing these tips here.

> [!IMPORTANT]
> - Since brew v4.6.4, `brew install` from source must set `HOMEBREW_DEVELOPER=1`, see [Don&#39;t allow installing formulae from paths without HOMEBREW_DEVELOPER](https://github.com/Homebrew/brew/pull/20414)
> - Since brew v4.7.0, Homebrew has dropped support for macOS versions under Catalina, see [Homebrew 4.7.0 deprecations/disables/removals](https://github.com/Homebrew/brew/pull/20973). Patch the Homebrew directory `/usr/local/Homebrew` to with this [file](Patch/high_sierra.patch) force brew to work again.
> - Restore some pkg-config files for older macOS versions, i.e. [10.13 pkg-config files](https://github.com/Homebrew/brew/tree/0236b2fc2d5556c9913822c4a4f02ec108de8a4e/Library/Homebrew/os/mac/pkgconfig/10.13).
> - Since brew v5.0.0, Homebrew portable ruby no longer supports macOS versions under Catalina, see [Portable Ruby 3.4.7](https://github.com/Homebrew/brew/commit/58a6c827f682e8d5bd0cc23d594ad63e7711c520). You need manually set the `RUBY_URL` to my self-built ruby bottle with this [patch](Patch/portable_ruby.patch).
You need to carefully check the patch file and my repo. So it should be much easier that if you just manaully untar the [bottle](https://github.com/niu541412/homebrew_old_macos/releases) to the directory `/usr/local/Homebrew/Library/Homebrew/vendor/portable-ruby` and set the soft link.

> [!IMPORTANT]
> **Homebrew's recent deprecation of older macOS versions has significantly increased the maintenance overhead for this project. To stay efficient, I will minimize text-based updates.**
>
> **For technical details, please check the Ruby files (.rb) in the [Formula](./Formula) directory. Comparing these with the upstream official repo will highlight my customizations.**

> [!TIP]
>
> 1. **Use Other Compilers:** Sometimes, modern codes are not compatible with built-in macOS versions. Consider using other compilers, e.g. gcc-14 or llvm_clang.
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
  @@ -56,6 +56,10 @@
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

- **Solution:** patch `compiler-rt/lib/builtins/os_version_check.c` with this [patch](https://github.com/macports/macports-ports/blob/master/lang/llvm-20/files/0130-10.14-and-less-availability.patch) file. Then in debug mode, modify `llvm/build/build.ninja` file : add `lib/clang/20/lib/darwin/libclang_rt.osx.a` to the `LINK_LIBRARIES` variable of failed command, e.g. `Link the shared library lib/liblldb.20.1.2.dylib` and `Link the executable bin/lldb-server`.

> [!NOTE]
> Python > 3.13 may conflict with llvm@16 during the build process. You can temporarily uninstall python forcefully and reinstall it later.

### [gcc](https://formulae.brew.sh/formula/gcc)

- **Issue:** Linking error (>=14)
- **Solution:** Use a specific version of gcc for compilation. `brew install gcc --debug --cc=gcc-14`. If you want to use llvm to build, add `ENV.append "LDFLAGS", "-L#{Formula["llvm"].opt_lib}/c++"` to the `args` list in the rb file.
- **Issue2:** `makeinfo` error (>=15)
- **Solution:** Install `texinfo` by `brew install texinfo` and add `depends_on "texinfo" => :build` in the rb file.

### [ruby](https://formulae.brew.sh/formula/ruby)

- **Issue:**

```log
ld: 8 duplicate symbols for architecture x86_64
```

- **Solution:** Use a specific version of gcc for compilation. `brew install ruby --debug --cc=gcc-14`
- **Issuse2:** `Errno::ENOENT: No such file or directory @ apply2files...`
- **Solution:** Replace tar as following this [link](https://github.com/koekeishiya/yabai/issues/1208#issuecomment-1171165126).

### [go](https://formulae.brew.sh/formula/go)

- **Issue:**

```log
Building packages and commands for darwin/amd64.
dyld: Symbol not found: _SecTrustCopyCertificateChain
  Referenced from: /usr/local/Cellar/go/1.25.0/libexec/bin/go (which was built for Mac OS X 12.0)
  Expected in: /System/Library/Frameworks/Security.framework/Versions/A/Security
 in /usr/local/Cellar/go/1.25.0/libexec/bin/go
```

- **Solution:** Go>=1.25.0 use the SecTrustCopyCertificateChain method, see [Commit 937368f](https://github.com/golang/go/commit/937368f84e545db15d3f39c2b33a267ba8ead4a4), thus use the reversed patch:

```diff
--- a/src/crypto/x509/internal/macos/security.go
+++ b/src/crypto/x509/internal/macos/security.go
@@ -122,6 +122,25 @@
 }
 func x509_SecTrustEvaluateWithError_trampoline()
 
+//go:cgo_import_dynamic x509_SecTrustGetCertificateCount SecTrustGetCertificateCount "/System/Library/Frameworks/Security.framework/Versions/A/Security"
+
+func SecTrustGetCertificateCount(trustObj CFRef) int {
+	ret := syscall(abi.FuncPCABI0(x509_SecTrustGetCertificateCount_trampoline), uintptr(trustObj), 0, 0, 0, 0, 0)
+	return int(ret)
+}
+func x509_SecTrustGetCertificateCount_trampoline()
+
+//go:cgo_import_dynamic x509_SecTrustGetCertificateAtIndex SecTrustGetCertificateAtIndex "/System/Library/Frameworks/Security.framework/Versions/A/Security"
+
+func SecTrustGetCertificateAtIndex(trustObj CFRef, i int) (CFRef, error) {
+	ret := syscall(abi.FuncPCABI0(x509_SecTrustGetCertificateAtIndex_trampoline), uintptr(trustObj), uintptr(i), 0, 0, 0, 0)
+	if ret == 0 {
+		return 0, OSStatus{"SecTrustGetCertificateAtIndex", int32(ret)}
+	}
+	return CFRef(ret), nil
+}
+func x509_SecTrustGetCertificateAtIndex_trampoline()
+
 //go:cgo_import_dynamic x509_SecCertificateCopyData SecCertificateCopyData "/System/Library/Frameworks/Security.framework/Versions/A/Security"
 
 func SecCertificateCopyData(cert CFRef) ([]byte, error) {
@@ -134,14 +153,3 @@
 	return b, nil
 }
 func x509_SecCertificateCopyData_trampoline()
-
-//go:cgo_import_dynamic x509_SecTrustCopyCertificateChain SecTrustCopyCertificateChain "/System/Library/Frameworks/Security.framework/Versions/A/Security"
-
-func SecTrustCopyCertificateChain(trustObj CFRef) (CFRef, error) {
-	ret := syscall(abi.FuncPCABI0(x509_SecTrustCopyCertificateChain_trampoline), uintptr(trustObj), 0, 0, 0, 0, 0)
-	if ret == 0 {
-		return 0, OSStatus{"SecTrustCopyCertificateChain", int32(ret)}
-	}
-	return CFRef(ret), nil
-}
-func x509_SecTrustCopyCertificateChain_trampoline()

--- a/src/crypto/x509/internal/macos/security.s
+++ b/src/crypto/x509/internal/macos/security.s
@@ -21,7 +21,9 @@
 	JMP x509_SecTrustEvaluate(SB)
 TEXT ·x509_SecTrustEvaluateWithError_trampoline(SB),NOSPLIT,$0-0
 	JMP x509_SecTrustEvaluateWithError(SB)
+TEXT ·x509_SecTrustGetCertificateCount_trampoline(SB),NOSPLIT,$0-0
+	JMP x509_SecTrustGetCertificateCount(SB)
+TEXT ·x509_SecTrustGetCertificateAtIndex_trampoline(SB),NOSPLIT,$0-0
+	JMP x509_SecTrustGetCertificateAtIndex(SB)
 TEXT ·x509_SecCertificateCopyData_trampoline(SB),NOSPLIT,$0-0
 	JMP x509_SecCertificateCopyData(SB)
-TEXT ·x509_SecTrustCopyCertificateChain_trampoline(SB),NOSPLIT,$0-0
-	JMP x509_SecTrustCopyCertificateChain(SB)

--- a/src/crypto/x509/root_darwin.go
+++ b/src/crypto/x509/root_darwin.go
@@ -73,13 +73,12 @@
 	}
 
 	chain := [][]*Certificate{{}}
-	chainRef, err := macOS.SecTrustCopyCertificateChain(trustObj)
-	if err != nil {
-		return nil, err
-	}
-	defer macOS.CFRelease(chainRef)
-	for i := 0; i < macOS.CFArrayGetCount(chainRef); i++ {
-		certRef := macOS.CFArrayGetValueAtIndex(chainRef, i)
+	numCerts := macOS.SecTrustGetCertificateCount(trustObj)
+	for i := 0; i < numCerts; i++ {
+		certRef, err := macOS.SecTrustGetCertificateAtIndex(trustObj, i)
+		if err != nil {
+			return nil, err
+		}
 		cert, err := exportCertificate(certRef)
 		if err != nil {
 			return nil, err
```

### [php](https://formulae.brew.sh/formula/php)

- **Issue:**

```log
Zend/zend_atomic.h:85:9: error: address argument to atomic operation must be a pointer to non-const _Atomic type ('const _Atomic(bool) *' invalid)
        return __c11_atomic_load(&obj->value, __ATOMIC_SEQ_CST);
               ^                 ~~~~~~~~~~~
```

- **Solution1:** Use a specific version of llvm for compilation. `brew install php --debug --cc=llvm_clang` or modify the `Zend/zend_atomic.h` file as the following reference url.
- **Reference:** [#8881](https://github.com/php/php-src/issues/8881)
- **Solution2:** Replace `uses_from_macos "libffi"` with `depends_on "libffi"`.

### [cmake](https://formulae.brew.sh/formula/cmake)

- **Solution:** Add `ENV["SDKROOT"] = MacOS.sdk_path if OS.mac? && MacOS.version == :high_sierra` to the rb file before `args balabali...` line.

### [z3](https://formulae.brew.sh/formula/z3)

- **Issue:** Linking error.
- **Solution:** Use llvm `brew install z3 --cc=llvm_clang`. Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to args to avoid the linking error.

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

<!-- ### [rust](https://formulae.brew.sh/formula/rust) -->

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

### [jq](https://formulae.brew.sh/formula/jq)

* **Issue:** `unknown type name 'x23define'`
* **Solution:** Add `inreplace "Makefile.in","\\x23","\\#"` into the install block of the local rb file.

### [librsvg](https://formulae.brew.sh/formula/librsvg)

* **Issue1:** `Command `/private/tmp/librsvg-20250319-26233-r4tyc1/librsvg-2.60.0/meson/makedef.py --regex '^rsvg_.' --os darwin --prefix _ --list /private/tmp/librsvg-20250319-26233-r4tyc1/librsvg-2.60.0/rsvg/../win32/librsvg.symbols /private/tmp/librsvg-20250319-26233-r4tyc1/librsvg-2.60.0/rsvg/../win32/librsvg-pixbuf.symbols ` failed with status 127.`
* **Solution1:** Add `depends_on "python"` into the local rb file.
* **Issue2:**

```log
  File "/usr/local/Cellar/python@3.13/3.13.7/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 577, in run
    raise CalledProcessError(retcode, process.args,
                             output=stdout, stderr=stderr)
subprocess.CalledProcessError: Command '[PosixPath('/usr/bin/nm'), '--defined-only', '-g', 'rsvg/librsvg_2.a']' returned non-zero exit status 1.
```

* **Solution2:** Add `ENV.append_path "PATH", Formula["llvm"].opt_bin` into the local rb file.

### [openjdk@21](https://formulae.brew.sh/formula/openjdk@21), [openjdk@17](https://formulae.brew.sh/formula/openjdk@17)

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

  ~~For openjdk@17 use llvm 16 to compile `brew install openjdk@17 --cc=llvm_clang`. It seems it's to due to llvm (>=17) use the dynamic library cache of macOS which is not compatible with the old version. See 2nd Kernel issue of [Release Note](https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-release-notes#Kernel).~~
  
  For opendk >=22, please refer the rb file in [Formula](./Formula) directory. I also built my own [builds](./releases/tag/openjdk), use at your own risk.

### [ghc](https://formulae.brew.sh/formula/ghc)

* **Issue:** `error: instruction requires: AVX-512 ISA`.
* **Solution:** Use llvm compile with specific version. `brew install ghc --cc=llvm_clang`

### [icu4c@76](https://formulae.brew.sh/formula/icu4c@76)

* **Issue:** `configure:9742: error: Python failed to run`, icu4c uses "python" to build it. However, in deprecated macOS, "python" is python2.
* **Solution:** Add `depends_on "python"` into the local rb file.

### [icu4c@77](https://formulae.brew.sh/formula/icu4c@77)

* **Issue:** `measunit_extra.cpp:577:13: error: call to 'abs' is ambiguous`
* **Solution:** patch `source/i18n/measunit_extra.cpp` with
  ```diff
  --- measunit_extra.cpp
  +++ measunit_extra.cpp
  @@ -33,6 +33,7 @@
  #include "util.h"
  #include <limits.h>
  #include <cstdlib>
  +#include <cmath>
  U_NAMESPACE_BEGIN


  @@ -574,7 +575,7 @@
          // Check if the value is integer.
          uint64_t int_result = static_cast<uint64_t>(double_result);
          const double kTolerance = 1e-9;
  -        if (abs(double_result - int_result) > kTolerance) {
  +        if (std::fabs(double_result - int_result) > kTolerance) {
              status = kUnitIdentifierSyntaxError;
              return 0;
          }

  ```

### [netpbm](https://formulae.brew.sh/formula/netpbm)

* **Issue:** `make: python3: No such file or directory`
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
* **Solution1:** Use llvm. Add `ENV.append "LDFLAGS", "#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"` before the make command to avoid the linking error, but do **not** add `--cc=llvm_clang` to the end.
* **Solution2:** Use gcc to build it. However the formula [.rb file](https://github.com/Homebrew/homebrew-core/blob/master/Formula/b/btop.rb) is mandatory to use llvm, so need to modify it and install from local. `depends_on "llvm"...` => `depends_on "gcc"...`; `ENV.llvm_clang if OS.mac?...` => `ENV.cxx if OS.mac?...`

### [node](https://formulae.brew.sh/formula/node), [node@22](https://formulae.brew.sh/formula/node@22), [node@20](https://formulae.brew.sh/formula/node@20), [node@18](https://formulae.brew.sh/formula/node@18)

* **Issue:** `missing os/signpost.h'`, `zlib issue` and `linking issue` etc.
* **Solution:** Just use the rb files in the [Formula](./Formula) diretory.

> [!NOTE]
> Seems only llvm <= 18 can used on deprecated macOS to build node@20 and node@18 due to the deprecated `std::char_traits` api. see [release notes](https://releases.llvm.org/18.1.0/projects/libcxx/docs/ReleaseNotes.html#llvm-19)

### [tesseract](https://formulae.brew.sh/formula/tesseract)

* **Issue:** fatal error: `filesystem` file not found and linker error.
* **Solution:**

  1. patch `src/training/unicharset_extractor.cpp` with

  ```diff
  --- unicharset_extractor.cpp
  +++ unicharset_extractor.cpp
  @@ -21,7 +21,6 @@
  // a unicharset.

  #include <cstdlib>
  -#include <filesystem>
  #include "boxread.h"
  #include "commandlineflags.h"
  #include "commontraining.h" // CheckSharedLibraryVersion
  @@ -65,13 +64,14 @@
    UNICHARSET unicharset;
    // Load input files
    for (int arg = 1; arg < argc; ++arg) {
  -    std::filesystem::path filePath = argv[arg];
  +    const char* filePath = argv[arg];
  +    const char* dot = strrchr(filePath, '.');
      std::string file_data = tesseract::ReadFile(argv[arg]);
      if (file_data.empty()) {
        continue;
      }
      std::vector<std::string> texts;
  -    if (filePath.extension() == ".box") {
  +    if (dot && strcmp(dot, ".box") == 0) {
        tprintf("Extracting unicharset from box file %s\n", argv[arg]);
        bool res = ReadMemBoxes(-1, /*skip_blanks*/ true, &file_data[0],
                      /*continue_on_failure*/ false, /*boxes*/ nullptr, &texts,
  ```

  2. add `ENV.append "LDFLAGS", "#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"` to the rb file.

### [ghostscript](https://formulae.brew.sh/formula/ghostscript)

* **Issue1:** Linking error caused by `tesseract`
* **Solution:** Remove the `tesseract` dependence in the rb file. Or add `ENV.append_to_cflags "-stdlib=libc++" if OS.mac?` to the rb file.
* **Issue2:**  Can't build with recent llvm or gcc.
* **Solution:** Use gcc compile with specific version, e.g. llvm-18. `brew install ghostscript --cc=llvm_clang`

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
  tarball=$(brew fetch --os sonoma ncdu --verbose | grep -o ncdu.*tar\.gz)
  tar xzf $HOME/Library/Caches/Homebrew/downloads/*${tarball} -C .
  # if you want homebrew to register it
  HOMEBREW_PREFIX=$(brew --prefix)
  mv ncdu/ $HOMEBREW_PREFIX/Cellar/
  brew link ncdu
  # but I found brew may clean it when it update...
  ncdu_exe=$(brew --prefix ncdu)/bin/ncdu
  # change the shared libaray path
  for i in $(otool -L $ncdu_exe | grep HOMEBREW_PREFIX | grep -oE @@HOMEBREW_PREFIX@@.*dylib); do
      sudo install_name_tool -change $i ${i/@@HOMEBREW_PREFIX@@/$HOMEBREW_PREFIX} $ncdu_exe
  done
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

### [opencv](https://formulae.brew.sh/formula/opencv)

* **Solution1:** Remove `depends_on "vtk"` and `-DWITH_VTK=ON` from the rb file because [molten-vk](https://formulae.brew.sh/formula/molten-vk) is not supported in deprecated macOS.
* **Solution2:**  Use llvm `brew install opencv --cc=llvm_clang`. Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to args to avoid the linking error.

### [tbb](https://formulae.brew.sh/formula/tbb),

* **Solution:**  Use llvm `brew install tbb --cc=llvm_clang`. Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to args to avoid the linking error.

### [blake3](https://formulae.brew.sh/formula/blake3)

* **Solution:** Build with `--cc=llvm_clang`.

### [openjph](https://formulae.brew.sh/formula/openjph)

* **Solution:** Modify `src/core/others/ojph_mem.c` with this patch:

```diff
--- a/src/core/others/ojph_mem.c
+++ b/src/core/others/ojph_mem.c
@@ -73,7 +73,14 @@
 #else
   void* ojph_aligned_malloc(size_t alignment, size_t size)
   {
+  #if defined(__APPLE__) || defined(__MACH__)
+    void* ptr = NULL;
+    if (posix_memalign(&ptr, alignment, size) != 0)
+      return NULL;
+    return ptr;
+  #else
     return aligned_alloc(alignment, size);
+  #endif 
   }

   void ojph_aligned_free(void* pointer)
```

Then build with `--cc=llvm_clang`.

### [difftastic](https://formulae.brew.sh/formula/difftastic)

* **Issue:** unknown type name 'CCCryptorStatus'.
* **Solution:** Add header in system file `/usr/include/CommonCrypto/CommonRandom.h`. I think this issue maybe fixed by author later.

  `#include <CommonCrypto/CommonCryptoError.h>`
* **Reference:** [can not build mimalloc](https://github.com/microsoft/mimalloc/issues/549)

### [doxygen](https://formulae.brew.sh/formula/doxygen)

* **Solution:** Use a gcc for compilation. `brew install doxygen --cc=gcc-14`.

### [wget](https://formulae.brew.sh/formula/wget)

* **Issue:** `configure: error: --with-ssl=openssl was given, but SSL is not available.`
* **Solution:** libssl.dylib provided by macOS don't have `_OPENSSL_init_ssl` symbol. Set LDFLAGS include /usr/local/lib to use the libssl provided by homebrew.

### [gd](https://formulae.brew.sh/formula/gd)

* **Issue:** `Undefined symbols for architecture x86_64: "_aom_codec_av1_cx", referenced from: _aomCodecEncodeImage in libavif.a(codec_aom.c.o)`
* **Solution:** Add `depends_on "aom"` and `ENV.append "LDFLAGS", "-L#{Formula["aom"].lib} -laom"` to the rb file.

### [glib](https://formulae.brew.sh/formula/glib)

* **Solution:** Replace `uses_from_macos "libffi"` with `depends_on "libffi"`. You may need to uninstall it before upgrade it.

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

* **Solution:** Use gcc or llvm(<=17) for compilation. `brew install openexr --cc=gcc-14`

### [gdk-pixbuf](https://formulae.brew.sh/formula/gdk-pixbuf)

* **Issue1:** `Dependency lookup for libtiff-4 with method 'pkgconfig' failed: Could not generate cflags for libtiff-4: Package libdeflate was not found in the pkg-config search path.`
* **Solution1:** One of following two options should be correct,
  1. Reinstall `libtiff` because it add useless dependence in pkgconfig file.
  2. Add `depends_on "libdeflate"` to the rb file.
* **Issue2:** `env: python3: No such file or directory`
* **Solution2:**Add `depends_on "python" => :build` to the rb file.

### [libheif](https://formulae.brew.sh/formula/libheif)

* **Issue1:** `/tmp/libheif-20241109-81439-f0emb6/libheif-1.19.2/libheif/bitstream.cc:26:10: fatal error: 'bit' file not found`. "bit" is a standard library header since C++20 (gcc>=9 or llvm>=11). When with llvm, add `-DCMAKE_STATIC_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command `cmake -S . -B build balabala...` to avoid the errors.
* **Solution1:** Use gcc or llvm for compilation. `brew install libheif --cc=gcc-xx`
* **Issue2:** pkg_config not found package.

```
CMake Error at gdk-pixbuf/CMakeLists.txt:19 (install):
  install TARGETS given no LIBRARY DESTINATION for module target
  "pixbufloader-heif".
```

* **Solution2:** do not pre-install gdk-pixbuf package, or uninstall it then reinstall it again.

### [snappy](https://formulae.brew.sh/formula/snappy), [abseil](https://formulae.brew.sh/formula/abseil)

- **Issue:** Linking error.
- **Solution:** Use llvm `brew install formula --cc=llvm_clang`.
  Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command
  `cmake -S . -B balabala...` to avoid the linking error.

### [protobuf](https://formulae.brew.sh/formula/protobuf)

- **Issue:** Linking error.
- **Solution:** Use llvm `brew install formula --cc=llvm_clang`.
  Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command
  `cmake -S . -B balabala...` to avoid the linking error.

### [sdl3](https://formulae.brew.sh/formula/sdl2)

* **Issue1:** `error: use of undeclared identifier 'kAudioChannelLayoutTag_WAVE_6_1' 'kAudioChannelLayoutTag_WAVE_7_1'`
* **Solution2:** Modify `/private/tmp/sdl2-balabala.../src/audio/coreaudio/SDL_coreaudio.m` by this patch:

  ```diff
  --- SDL_coreaudio.m
  +++ SDL_coreaudio.m
  @@ -23,6 +23,13 @@
  #ifdef SDL_AUDIO_DRIVER_COREAUDIO

  /* !!! FIXME: clean out some of the macro salsa in here. */
  +#ifndef kAudioChannelLayoutTag_WAVE_6_1
  +#define kAudioChannelLayoutTag_WAVE_6_1 ((188U << 16) | 7)                     ///< 7 channels, L R C LFE Cs Ls Rs
  +#endif
  +
  +#ifndef kAudioChannelLayoutTag_WAVE_7_1
  +#define kAudioChannelLayoutTag_WAVE_7_1 ((188U << 16) | 8)                   ///< 8 channels, L R C LFE Rls Rrs Ls Rs
  +#endif

  #include "SDL_audio.h"
  #include "SDL_hints.h"
  ```
* **Issue2:** Undefined symbols for architecture x86_64:
* **Solution2:** Add these parameters `-DSDL_CAMERA=OFF -DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF -DSDL_DIALOG=OFF -DSDL_GPU=OFF -DSDL_METAL=OFF -DSDL_RENDER_METAL=OFF -DSDL_COCOA=OFF` to the `cmake -S . -B build` command.
* **Issue3:** Framework `UniformTypeIdentifiers` not found.
* **Solution3:** Comment out the line of `sdl_link_dependency(uniformtypeidentifiers` in `CMakeLists.txt`.

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

- **Issue:**  Linker error
- **Solution:** Use llvm `brew install poppler --cc=llvm_clang`.
  + Add `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` and `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command `cmake -S . -B build/shared balabala...` to avoid the linking error.
  + Add `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}` to the cmake command `cmake -S . -B build/static balabala...` to avoid the linking error.
  + Add `depends_on "python" => :build` to the rb file

### [freerdp](https://formulae.brew.sh/formula/freerdp)

- **Issue:** Linker error
- **Solution:** Use LLVM by running `brew install ./freerdp.rb --cc=llvm_clang`.
  Additionally, add the following flags to the CMake command `cmake -S . -B build/shared ...` to avoid the linking error:
  - `-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}`
  - `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}`

> [!NOTE]
> `sdl2` maybe more compatible with `freerdp` on deprecated macOS.

### [itstool](https://formulae.brew.sh/formula/itstool)
- **Solution:** Add "depends_on "icu4c" => :build" to the rb file. This dependency is missing due to the libxml2 bindings, see [itstool: revision bump](https://github.com/Homebrew/homebrew-core/commit/b2570f8cb7d14fd61d6d2f4b9dd149c60b39129a).


### [simdutf](https://formulae.brew.sh/formula/simdutf)

- **Issue:** Linker error
- **Solution:** Use LLVM by running `brew install ./simdutf.rb --cc=llvm_clang`.
  Additionally, add the following flags to the CMake command `cmake -S . -B build ...` to avoid the linking error:
  - `-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}`

### [pandoc](https://formulae.brew.sh/formula/pandoc)

- **Issue1:**

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

- **Solution1:** Add `--allow-newer` to the `cabal v2-install balabala...` command and use LLVM 18 `brew install pandoc --cc=llvm_clang`.
- **Reference:** [Running into depdency conflicts when running cabal test](https://github.com/jgm/pandoc/issues/10597)
- **Issue2:** `folly-2025.09.15.00/folly/concurrency/CacheLocality.cpp:223:35: error: 'path' is unavailable: introduced in macOS 10.15`
- **Solution2:** Recent homebrew has added  missing symbols checking, see [inject __config_site](https://github.com/Homebrew/brew/commit/4077e8e38d9ca9316797e9a12a21bfa292dcb7e6). You can temporarily change the macro `_LIBCPP_HAS_VENDOR_AVAILABILITY_ANNOTATIONS` to `0` in `Library/Homebrew/shims/mac/shared/include/llvm/__config_site`.

### [suite-sparse](https://formulae.brew.sh/formula/suite-sparse)

- **Issue:** Build error
- **Solution:** Not use gcc to build, revert the patch in the following link.
- **Reference:** [forcing it to gcc-15](https://github.com/Homebrew/homebrew-core/pull/253109)
