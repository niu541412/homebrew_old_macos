class LlvmAT18 < Formula
  desc "Next-gen compiler infrastructure"
  homepage "https://llvm.org/"
  url "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/llvm-project-18.1.8.src.tar.xz"
  sha256 "0b58557a6d32ceee97c8d533a59b9212d87e0fc4d2833924eb6c611247db2f2a"
  # The LLVM Project is under the Apache License v2.0 with LLVM Exceptions
  license "Apache-2.0" => { with: "LLVM-exception" }

  livecheck do
    skip "No longer developed or maintained"
  end

  bottle do
  end

  # Clang cannot find system headers if Xcode CLT is not installed
  pour_bottle? only_if: :clt_installed

  keg_only :versioned_formula

  # https://llvm.org/docs/GettingStarted.html#requirement
  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "python@3.14" => [:build, :test]
  depends_on "zstd"

  uses_from_macos "libedit"
  uses_from_macos "libffi"
  uses_from_macos "ncurses"

  on_linux do
    depends_on "binutils" => :build # needed for LLVMgold plugin
    depends_on "pkgconf" => :build
    depends_on "zlib-ng-compat"
  end

  # Apply MacPorts backports of upstream commits needed to fix macOS 27
  patch do
    url "https://raw.githubusercontent.com/macports/macports-ports/3e8ffa3fc0a854820d1917bffacc29624ff66a85/lang/llvm-18/files/0140-llvm-no-cmp-spec.patch"
    sha256 "bc24230389a5ba0947e07dc1d6e94ecdb2d67b9baf4206be5d967f73b03cd109"
    type :backport
    resolves "https://github.com/llvm/llvm-project/pull/160804"
  end
  patch do
    url "https://raw.githubusercontent.com/macports/macports-ports/3e8ffa3fc0a854820d1917bffacc29624ff66a85/lang/llvm-18/files/0141-infinity_nan.patch"
    sha256 "13b68937e4c9cd1e84264ebd6656670d02bfefb8571d281145e3ccbf065ff3b6"
    type :backport
    resolves "https://github.com/llvm/llvm-project/pull/164348"
  end

  # Backport commits for macOS 27 SDK
  patch do
    url "https://github.com/llvm/llvm-project/commit/477a65a051ce151895193f8dede1262fdc251132.patch?full_index=1"
    sha256 "4bbdb4ab0eaefce2403fdfa96929026940f153f8e7421feba288cbc3dd8fe6e2"
    type :backport
  end
  patch do
    url "https://raw.githubusercontent.com/Homebrew/homebrew-core/refs/heads/main/Patches/llvm/18.x-arm64e.x1-support.patch"
    type :backport
    resolves "https://github.com/llvm/llvm-project/pull/222721"
  end

  patch :DATA
  def install
    # Apple Clang 10's libc++ has std::optional but lacks its C++17 deduction guides.
    inreplace "llvm/lib/Support/Program.cpp",
              "std::optional(SecondsToWait)", "std::optional<unsigned>(SecondsToWait)"
    inreplace "llvm/lib/Transforms/Utils/MemoryOpRemark.cpp",
              "std::optional(TySize->getFixedValue())", "std::optional<uint64_t>(TySize->getFixedValue())"
    inreplace "llvm/lib/Transforms/Scalar/LowerMatrixIntrinsics.cpp",
              "std::optional(FMF)", "std::optional<FastMathFlags>(FMF)"
    inreplace "llvm/lib/Transforms/InstCombine/InstructionCombining.cpp",
              "std::optional(std::pair(L0, R0))",
              "std::optional<std::pair<Value *, Value *>>(std::pair(L0, R0))"
    inreplace "llvm/lib/Passes/StandardInstrumentations.cpp",
              "std::array FileSuffixes =", "std::array<StringRef, 3> FileSuffixes ="
    inreplace "mlir/lib/Dialect/MemRef/Transforms/ExpandOps.cpp",
              "std::array shouldBeExpandedKinds =",
              "std::array<arith::AtomicRMWKind, 4> shouldBeExpandedKinds ="
    inreplace "mlir/lib/Dialect/ArmSME/Transforms/TileAllocation.cpp",
              "std::array ZA_B_MASKS =", "std::array<TileMask, 1> ZA_B_MASKS ="
    inreplace "mlir/lib/Dialect/ArmSME/Transforms/TileAllocation.cpp",
              "std::array ZA_H_MASKS =", "std::array<TileMask, 2> ZA_H_MASKS ="
    inreplace "mlir/lib/Dialect/ArmSME/Transforms/TileAllocation.cpp",
              "std::array ZA_S_MASKS =", "std::array<TileMask, 4> ZA_S_MASKS ="
    inreplace "mlir/lib/Dialect/ArmSME/Transforms/TileAllocation.cpp",
              "std::array ZA_D_MASKS =", "std::array<TileMask, 8> ZA_D_MASKS ="
    inreplace "mlir/lib/Dialect/ArmSME/Transforms/TileAllocation.cpp",
              "std::array ZA_Q_MASKS =", "std::array<TileMask, 16> ZA_Q_MASKS ="
    inreplace "mlir/lib/Target/LLVMIR/ModuleImport.cpp",
              "std::array ExplicitAttributes{", "std::array<StringLiteral, 9> ExplicitAttributes{"
    inreplace "mlir/lib/Dialect/IRDL/IR/IRDLOps.cpp",
              "std::optional{getConstraintIndicesForArgs(",
              "std::optional<SmallVector<unsigned>>{getConstraintIndicesForArgs("
    inreplace "clang/lib/APINotes/APINotesYAMLCompiler.cpp",
              "std::optional(Ctx->id)", "std::optional<ContextID>(Ctx->id)"
    inreplace "mlir/include/mlir/Dialect/SparseTensor/IR/Enums.h",
              "std::optional(lt)", "std::optional<LevelType>(lt)"
    inreplace "mlir/lib/Dialect/Vector/IR/VectorOps.cpp",
              "ArrayRef(extractPosition)", "ArrayRef<int64_t>(extractPosition)"

    # The clang bindings need a little help finding our libclang.
    inreplace "clang/bindings/python/clang/cindex.py",
              /^(\s*library_path\s*=\s*)None$/,
              "\\1'#{lib}'"

    projects = %w[
      clang
      clang-tools-extra
      lld
      mlir
      polly
    ]
    runtimes = %w[
      compiler-rt
      libcxx
      libcxxabi
      libunwind
    ]

    python_versions = Formula.names
                             .select { |name| name.start_with? "python@" }
                             .map { |py| py.delete_prefix("python@") }

    compat_cxxflags = nil
    if OS.mac? && DevelopmentTools.clang_build_version <= 1000
      # Do not use ENV: LLVM propagates ENV CXXFLAGS to runtimes, which build
      # against newly-built libc++ and must not receive this old-SDK shim.
      compat_cxxflags = "-include #{buildpath}/darwin-cmath-compat.h -D_LIBCPP_DISABLE_AVAILABILITY"
    end

    # compiler-rt has some iOS simulator features that require i386 symbols
    # I'm assuming the rest of clang needs support too for 32-bit compilation
    # to work correctly, but if not, perhaps universal binaries could be
    # limited to compiler-rt. llvm makes this somewhat easier because compiler-rt
    # can almost be treated as an entirely different build from llvm.
    ENV.permit_arch_flags

    args = %W[
      -DLLVM_ENABLE_PROJECTS=#{projects.join(";")}
      -DLLVM_ENABLE_RUNTIMES=#{runtimes.join(";")}
      -DLLVM_POLLY_LINK_INTO_TOOLS=ON
      -DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON
      -DLLVM_LINK_LLVM_DYLIB=ON
      -DLLVM_ENABLE_EH=ON
      -DLLVM_ENABLE_FFI=ON
      -DLLVM_ENABLE_RTTI=ON
      -DLLVM_INCLUDE_BENCHMARKS=OFF
      -DLLVM_INCLUDE_DOCS=OFF
      -DLLVM_INCLUDE_TESTS=OFF
      -DLLVM_INSTALL_UTILS=ON
      -DLLVM_ENABLE_Z3_SOLVER=OFF
      -DLLVM_OPTIMIZED_TABLEGEN=ON
      -DLLVM_TARGETS_TO_BUILD=all
      -DLIBCXX_INSTALL_MODULES=ON
      -DCLANG_PYTHON_BINDINGS_VERSIONS=#{python_versions.join(";")}
      -DLLVM_CREATE_XCODE_TOOLCHAIN=OFF
      -DCLANG_FORCE_MATCHING_LIBCLANG_SOVERSION=OFF
      -DPACKAGE_VENDOR=Homebrew
      -DBUG_REPORT_URL=https://github.com/Homebrew/homebrew-core/issues
      -DCLANG_VENDOR_UTI=org.homebrew.clang
      -DCMAKE_SHARED_LINKER_FLAGS=#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}
    ]
    # Xcode 10 accepts the feature probe but does not implement this flag.
    args << "-DSUPPORTS_FFILE_PREFIX_MAP=OFF" if OS.mac? && DevelopmentTools.clang_build_version <= 1000

    runtimes_cmake_args = []
    builtins_cmake_args = []

    if OS.mac?
      macos_sdk = MacOS.sdk_path
      args << "-DFFI_INCLUDE_DIR=#{macos_sdk}/usr/include/ffi"
      args << "-DFFI_LIBRARY_DIR=#{macos_sdk}/usr/lib"

      libcxx_install_libdir = lib/"c++"
      libcxx_rpaths = [loader_path, rpath(source: libcxx_install_libdir)]

      args << "-DLLVM_BUILD_LLVM_C_DYLIB=ON"
      args << "-DLLVM_ENABLE_LIBCXX=ON"
      args << "-DLIBCXX_PSTL_CPU_BACKEND=libdispatch"
      args << "-DLIBCXX_INSTALL_LIBRARY_DIR=#{libcxx_install_libdir}"
      args << "-DLIBCXXABI_INSTALL_LIBRARY_DIR=#{libcxx_install_libdir}"
      args << "-DDEFAULT_SYSROOT=#{macos_sdk}" if macos_sdk
      runtimes_cmake_args << "-DCMAKE_INSTALL_RPATH=#{libcxx_rpaths.join("|")}"

      # LLVM's newly bootstrapped llvm-ar cannot create a new archive on 10.13.
      # This breaks CMake's libunwind feature checks before any runtime is built.
      if DevelopmentTools.clang_build_version <= 1000
        runtimes_cmake_args << "-DCMAKE_AR=/usr/bin/ar"
        runtimes_cmake_args << "-DCMAKE_RANLIB=/usr/bin/ranlib"
      end

      # Disable builds for OSes not supported by the CLT SDK.
      clt_sdk_support_flags = %w[I WATCH TV].map { |os| "-DCOMPILER_RT_ENABLE_#{os}OS=OFF" }
      builtins_cmake_args += clt_sdk_support_flags
    else
      args << "-DFFI_INCLUDE_DIR=#{formula_opt_include("libffi")}"
      args << "-DFFI_LIBRARY_DIR=#{formula_opt_lib("libffi")}"

      # Disable `libxml2` which isn't very useful.
      args << "-DLLVM_ENABLE_LIBXML2=OFF"
      args << "-DLLVM_ENABLE_LIBCXX=OFF"
      args << "-DCLANG_DEFAULT_CXX_STDLIB=libstdc++"
      # Enable llvm gold plugin for LTO
      args << "-DLLVM_BINUTILS_INCDIR=#{formula_opt_include("binutils")}"
      # Parts of Polly fail to correctly build with PIC when being used for DSOs.
      args << "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
      runtimes_cmake_args += %w[
        -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON

        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
        -DLIBCXX_STATICALLY_LINK_ABI_IN_SHARED_LIBRARY=OFF
        -DLIBCXX_STATICALLY_LINK_ABI_IN_STATIC_LIBRARY=ON
        -DLIBCXX_USE_COMPILER_RT=ON
        -DLIBCXX_HAS_ATOMIC_LIB=OFF

        -DLIBCXXABI_ENABLE_STATIC_UNWINDER=ON
        -DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_SHARED_LIBRARY=OFF
        -DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_STATIC_LIBRARY=ON
        -DLIBCXXABI_USE_COMPILER_RT=ON
        -DLIBCXXABI_USE_LLVM_UNWINDER=ON

        -DLIBUNWIND_USE_COMPILER_RT=ON
        -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON
        -DCOMPILER_RT_USE_LLVM_UNWINDER=ON

        -DSANITIZER_CXX_ABI=libc++
        -DSANITIZER_TEST_CXX=libc++
      ]

      # Prevent compiler-rt from building i386 targets, as this is not portable.
      builtins_cmake_args << "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON"
    end

    if ENV.cflags.present?
      args << "-DCMAKE_C_FLAGS=#{ENV.cflags}"
      runtimes_cmake_args << "-DCMAKE_C_FLAGS=#{ENV.cflags}"
      builtins_cmake_args << "-DCMAKE_C_FLAGS=#{ENV.cflags}"
    end

    if ENV.cxxflags.present?
      args << "-DCMAKE_CXX_FLAGS=#{ENV.cxxflags}"
      runtimes_cmake_args << "-DCMAKE_CXX_FLAGS=#{ENV.cxxflags}"
      builtins_cmake_args << "-DCMAKE_CXX_FLAGS=#{ENV.cxxflags}"
    end

    args << "-DCMAKE_CXX_FLAGS=#{[ENV.cxxflags, compat_cxxflags].compact.join(" ")}" if compat_cxxflags

    args << "-DRUNTIMES_CMAKE_ARGS=#{runtimes_cmake_args.join(";")}" if runtimes_cmake_args.present?
    args << "-DBUILTINS_CMAKE_ARGS=#{builtins_cmake_args.join(";")}" if builtins_cmake_args.present?

    llvmpath = buildpath/"llvm"
    mkdir llvmpath/"build" do
      system "cmake", "-G", "Ninja", "..", *(std_cmake_args + args)
      system "cmake", "--build", "."
      system "cmake", "--build", ".", "--target", "install"
    end

    if OS.mac?
      # Get the version from `llvm-config` to get the correct HEAD or RC version too.
      llvm_version = Utils.safe_popen_read(bin/"llvm-config", "--version").strip
      soversion = Version.new(llvm_version).major.to_s

      # Install versioned symlink, or else `llvm-config` doesn't work properly
      lib.install_symlink "libLLVM.dylib" => "libLLVM-#{soversion}.dylib"

      # Install Xcode toolchain. See:
      # https://github.com/llvm/llvm-project/blob/main/llvm/tools/xcode-toolchain/CMakeLists.txt
      # We do this manually in order to avoid:
      #   1. installing duplicates of files in the prefix
      #   2. requiring an existing Xcode installation
      xctoolchain = prefix/"Toolchains/LLVM#{llvm_version}.xctoolchain"

      system "/usr/libexec/PlistBuddy", "-c", "Add:CFBundleIdentifier string org.llvm.#{llvm_version}", "Info.plist"
      system "/usr/libexec/PlistBuddy", "-c", "Add:CompatibilityVersion integer 2", "Info.plist"
      xctoolchain.install "Info.plist"
      (xctoolchain/"usr").install_symlink [bin, include, lib, libexec, share]
    end

    # Install Vim plugins
    %w[ftdetect ftplugin indent syntax].each do |dir|
      (share/"vim/vimfiles"/dir).install Pathname.glob("*/utils/vim/#{dir}/*.vim")
    end

    # Install Emacs modes
    elisp.install llvmpath.glob("utils/emacs/*.el") + share.glob("clang/*.el")
  end

  def caveats
    on_macos do
      <<~EOS
        To use the bundled libc++ please add the following LDFLAGS:
          LDFLAGS="-L#{opt_lib}/c++ -L#{opt_lib} -lunwind"
      EOS
    end
  end

  test do
    llvm_version = Utils.safe_popen_read(bin/"llvm-config", "--version").strip
    llvm_version_major = Version.new(llvm_version).major.to_s
    soversion = llvm_version_major.dup
    assert_equal version, llvm_version

    assert_equal prefix.to_s, shell_output("#{bin}/llvm-config --prefix").chomp
    assert_equal "-lLLVM-#{soversion}", shell_output("#{bin}/llvm-config --libs").chomp
    assert_equal (lib/shared_library("libLLVM-#{soversion}")).to_s,
                 shell_output("#{bin}/llvm-config --libfiles").chomp

    (testpath/"test.c").write <<~C
      #include <stdio.h>
      int main()
      {
        printf("Hello World!\\n");
        return 0;
      }
    C

    (testpath/"test.cpp").write <<~CPP
      #include <iostream>
      int main()
      {
        std::cout << "Hello World!" << std::endl;
        return 0;
      }
    CPP

    # Testing default toolchain and SDK location.
    system bin/"clang++", "-v",
           "-std=c++11", "test.cpp", "-o", "test++"
    assert_includes MachO::Tools.dylibs("test++"), "/usr/lib/libc++.1.dylib" if OS.mac?
    assert_equal "Hello World!", shell_output("./test++").chomp
    system bin/"clang", "-v", "test.c", "-o", "test"
    assert_equal "Hello World!", shell_output("./test").chomp

    # To test `lld`, we mock a broken `ld` to make sure it's not what's being used.
    (testpath/"fake_ld.c").write <<~C
      int main() { return 1; }
    C
    (testpath/"bin").mkpath
    system ENV.cc, "-v", "fake_ld.c", "-o", "bin/ld"
    with_env(PATH: "#{testpath}/bin:#{ENV["PATH"]}") do
      # Our fake `ld` will produce a compilation error if it is used instead of `lld`.
      system bin/"clang", "-v", "test.c", "-o", "test_lld", "-fuse-ld=lld"
    end
    assert_equal "Hello World!", shell_output("./test_lld").chomp

    # These tests should ignore the usual SDK includes
    with_env(CPATH: nil) do
      # Testing Command Line Tools; skipped on CLT 26.4+ due to __builtin_clzg added in LLVM 19+
      if OS.mac? && MacOS::CLT.installed? && MacOS::CLT.version < "26.4"
        toolchain_path = "/Library/Developer/CommandLineTools"
        cpp_base = (MacOS.version >= :big_sur) ? MacOS::CLT.sdk_path : toolchain_path
        system bin/"clang++", "-v",
               "-isysroot", MacOS::CLT.sdk_path,
               "-isystem", "#{cpp_base}/usr/include/c++/v1",
               "-isystem", "#{MacOS::CLT.sdk_path}/usr/include",
               "-isystem", "#{toolchain_path}/usr/include",
               "-std=c++11", "test.cpp", "-o", "testCLT++"
        assert_includes MachO::Tools.dylibs("testCLT++"), "/usr/lib/libc++.1.dylib"
        assert_equal "Hello World!", shell_output("./testCLT++").chomp
        system bin/"clang", "-v", "test.c", "-o", "testCLT"
        assert_equal "Hello World!", shell_output("./testCLT").chomp
      end

      # Testing Xcode; skipped on Xcode 26.4+ due to __builtin_clzg added in LLVM 19+
      if OS.mac? && MacOS::Xcode.installed? && MacOS::Xcode.version < "26.4"
        cpp_base = (MacOS::Xcode.version >= "12.5") ? MacOS::Xcode.sdk_path : MacOS::Xcode.toolchain_path
        system bin/"clang++", "-v",
               "-isysroot", MacOS::Xcode.sdk_path,
               "-isystem", "#{cpp_base}/usr/include/c++/v1",
               "-isystem", "#{MacOS::Xcode.sdk_path}/usr/include",
               "-isystem", "#{MacOS::Xcode.toolchain_path}/usr/include",
               "-std=c++11", "test.cpp", "-o", "testXC++"
        assert_includes MachO::Tools.dylibs("testXC++"), "/usr/lib/libc++.1.dylib"
        assert_equal "Hello World!", shell_output("./testXC++").chomp
        system bin/"clang", "-v",
               "-isysroot", MacOS.sdk_path,
               "test.c", "-o", "testXC"
        assert_equal "Hello World!", shell_output("./testXC").chomp
      end

      # link against installed libc++
      # related to https://github.com/Homebrew/legacy-homebrew/issues/47149
      cxx_libdir = OS.mac? ? opt_lib/"c++" : opt_lib
      system bin/"clang++", "-v",
             "-isystem", "#{opt_include}/c++/v1",
             "-std=c++11", "-stdlib=libc++", "test.cpp", "-o", "testlibc++",
             "-rtlib=compiler-rt", "-L#{cxx_libdir}", "-Wl,-rpath,#{cxx_libdir}"
      assert_includes (testpath/"testlibc++").dynamically_linked_libraries,
                      (cxx_libdir/shared_library("libc++", "1")).to_s
      (testpath/"testlibc++").dynamically_linked_libraries.each do |lib|
        refute_match(/libstdc\+\+/, lib)
        refute_match(/libgcc/, lib)
        refute_match(/libatomic/, lib)
      end
      assert_equal "Hello World!", shell_output("./testlibc++").chomp
    end

    if OS.linux?
      # Link installed libc++, libc++abi, and libunwind archives both into
      # a position independent executable (PIE), as well as into a fully
      # position independent (PIC) DSO for things like plugins that export
      # a C-only API but internally use C++.
      #
      # FIXME: It'd be nice to be able to use flags like `-static-libstdc++`
      # together with `-stdlib=libc++` (the latter one we need anyways for
      # headers) to achieve this but those flags don't set up the correct
      # search paths or handle all of the libraries needed by `libc++` when
      # linking statically.

      system bin/"clang++", "-v", "-o", "test_pie_runtimes",
                   "-pie", "-fPIC", "test.cpp", "-L#{opt_lib}",
                   "-stdlib=libc++", "-rtlib=compiler-rt",
                   "-static-libstdc++", "-lpthread", "-ldl"
      assert_equal "Hello World!", shell_output("./test_pie_runtimes").chomp
      (testpath/"test_pie_runtimes").dynamically_linked_libraries.each do |lib|
        refute_match(/lib(std)?c\+\+/, lib)
        refute_match(/libgcc/, lib)
        refute_match(/libatomic/, lib)
        refute_match(/libunwind/, lib)
      end

      (testpath/"test_plugin.cpp").write <<~CPP
        #include <iostream>
        __attribute__((visibility("default")))
        extern "C" void run_plugin() {
          std::cout << "Hello Plugin World!" << std::endl;
        }
      CPP
      (testpath/"test_plugin_main.c").write <<~C
        extern void run_plugin();
        int main() {
          run_plugin();
        }
      C
      system bin/"clang++", "-v", "-o", "test_plugin.so",
             "-shared", "-fPIC", "test_plugin.cpp", "-L#{opt_lib}",
             "-stdlib=libc++", "-rtlib=compiler-rt",
             "-static-libstdc++", "-lpthread", "-ldl"
      system bin/"clang", "-v",
             "test_plugin_main.c", "-o", "test_plugin_libc++",
             "test_plugin.so", "-Wl,-rpath=#{testpath}", "-rtlib=compiler-rt"
      assert_equal "Hello Plugin World!", shell_output("./test_plugin_libc++").chomp
      (testpath/"test_plugin.so").dynamically_linked_libraries.each do |lib|
        refute_match(/lib(std)?c\+\+/, lib)
        refute_match(/libgcc/, lib)
        refute_match(/libatomic/, lib)
        refute_match(/libunwind/, lib)
      end
    end

    # Testing mlir
    (testpath/"test.mlir").write <<~MLIR
      func.func @main() {return}

      // -----

      // expected-note @+1 {{see existing symbol definition here}}
      func.func @foo() { return }

      // ----

      // expected-error @+1 {{redefinition of symbol named 'foo'}}
      func.func @foo() { return }
    MLIR
    system bin/"mlir-opt", "--split-input-file", "--verify-diagnostics", "test.mlir"

    (testpath/"scanbuildtest.cpp").write <<~CPP
      #include <iostream>
      int main() {
        int *i = new int;
        *i = 1;
        delete i;
        std::cout << *i << std::endl;
        return 0;
      }
    CPP
    assert_includes shell_output("#{bin}/scan-build make scanbuildtest 2>&1"),
                    "warning: Use of memory after it is freed"

    (testpath/"clangformattest.c").write <<~C
      int    main() {
          printf("Hello world!"); }
    C
    assert_equal "int main() { printf(\"Hello world!\"); }\n",
      shell_output("#{bin}/clang-format -style=google clangformattest.c")

    # This will fail if the clang bindings cannot find `libclang`.
    with_env(PYTHONPATH: prefix/Language::Python.site_packages(python3)) do
      system python3, "-c", <<~PYTHON
        from clang import cindex
        cindex.Config().get_cindex_library()
      PYTHON
    end

    # Ensure LLVM did not regress output of `llvm-config --system-libs` which for a time
    # was known to output incorrect linker flags; e.g., `-llibxml2.tbd` instead of `-lxml2`.
    # On the other hand, note that a fully qualified path to `dylib` or `tbd` is OK, e.g.,
    # `/usr/local/lib/libxml2.tbd` or `/usr/local/lib/libxml2.dylib`.
    abs_path_exts = [".tbd", ".dylib"]
    shell_output("#{bin}/llvm-config --system-libs").chomp.strip.split.each do |lib|
      if lib.start_with?("-l")
        assert !lib.end_with?(".tbd"), "expected abs path when lib reported as .tbd"
        assert !lib.end_with?(".dylib"), "expected abs path when lib reported as .dylib"
      else
        p = Pathname.new(lib)
        if abs_path_exts.include?(p.extname)
          assert p.absolute?, "expected abs path when lib reported as .tbd or .dylib"
        end
      end
    end
  end
end

__END__
--- /dev/null
+++ b/darwin-cmath-compat.h
@@ -0,0 +1,44 @@
+#include <type_traits>
+#include <math.h>
+#if __cplusplus >= 201103L
+#define HB_NOEXCEPT noexcept
+#else
+#define HB_NOEXCEPT
+#endif
+#ifndef _LIBCPP_MATH_H
+inline float abs(float x) HB_NOEXCEPT { return __builtin_fabsf(x); }
+inline double abs(double x) HB_NOEXCEPT { return __builtin_fabs(x); }
+inline long double abs(long double x) HB_NOEXCEPT { return __builtin_fabsl(x); }
+inline long abs(long x) HB_NOEXCEPT { return __builtin_labs(x); }
+inline long long abs(long long x) HB_NOEXCEPT { return __builtin_llabs(x); }
+#endif
+#undef fpclassify
+#undef isfinite
+#undef isinf
+#undef isnan
+#undef isnormal
+#undef signbit
+#undef isgreater
+#undef isgreaterequal
+#undef isless
+#undef islessequal
+#undef islessgreater
+#undef isunordered
+#define HB_UNARY(name, builtin) inline int name(float x) HB_NOEXCEPT { return __builtin##builtin(x); } inline int name(double x) HB_NOEXCEPT { return __builtin##builtin(x); } inline int name(long double x) HB_NOEXCEPT { return __builtin##builtin(x); }
+HB_UNARY(isfinite, _isfinite)
+HB_UNARY(isinf, _isinf)
+HB_UNARY(isnan, _isnan)
+HB_UNARY(isnormal, _isnormal)
+HB_UNARY(signbit, _signbit)
+#undef HB_UNARY
+inline int fpclassify(float x) HB_NOEXCEPT { return __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL, FP_ZERO, x); }
+inline int fpclassify(double x) HB_NOEXCEPT { return __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL, FP_ZERO, x); }
+inline int fpclassify(long double x) HB_NOEXCEPT { return __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL, FP_ZERO, x); }
+#define HB_BINARY(name, builtin) inline int name(float x, float y) HB_NOEXCEPT { return __builtin##builtin(x, y); } inline int name(double x, double y) HB_NOEXCEPT { return __builtin##builtin(x, y); } inline int name(long double x, long double y) HB_NOEXCEPT { return __builtin##builtin(x, y); }
+HB_BINARY(isgreater, _isgreater)
+HB_BINARY(isgreaterequal, _isgreaterequal)
+HB_BINARY(isless, _isless)
+HB_BINARY(islessequal, _islessequal)
+HB_BINARY(islessgreater, _islessgreater)
+HB_BINARY(isunordered, _isunordered)
+#undef HB_BINARY
+#undef HB_NOEXCEPT
