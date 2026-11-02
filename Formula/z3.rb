class Z3 < Formula
  desc "High-performance theorem prover"
  homepage "https://github.com/Z3Prover/z3"
  url "https://github.com/Z3Prover/z3/archive/refs/tags/z3-5.3.3.tar.gz"
  sha256 "f8373e6a753da6e336f0955fca65c7a56346f3de68a56fd353acb4abf33d4823"
  license "MIT"
  compatibility_version 5
  head "https://github.com/Z3Prover/z3.git", branch: "master"

  livecheck do
    url :stable
    regex(/z3[._-]v?(\d+(?:\.\d+)+)/i)
    strategy :github_latest
  end

  bottle do
  end

  depends_on "cmake" => :build
  # Has Python bindings but are supplementary to the main library
  # which does not need Python.
  depends_on "python@3.15" => [:build, :test]

  # The following macOS conditional should be the inverse of LLVM's Z3 conditional
  on_ventura :or_older do
    fails_with :clang do
      cause "Requires C++20 std::format, https://developer.apple.com/xcode/cpp/#c++20"
    end
  end

  fails_with :gcc do
    version "12"
    cause "Requires C++20 std::format, https://gcc.gnu.org/gcc-13/changes.html#libstdcxx"
  end

  deny_network_access!

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1400)
    # macOS 12's libc++ lacks the floating-point `to_chars` implementation that
    # C++20 `std::format` needs. Use fmt header-only instead, so the generated
    # binaries retain the formula's macOS 12 deployment target.
    ENV.append "CXXFLAGS", "-DFMT_HEADER_ONLY"
    format_sources = %w[
      src/ast/array_decl_plugin.cpp
      src/ast/ast.cpp
      src/ast/bv_decl_plugin.cpp
      src/ast/datatype_decl_plugin.cpp
      src/ast/dl_decl_plugin.cpp
      src/ast/seq_decl_plugin.cpp
    ]
    inreplace format_sources, "<format>", "<fmt/format.h>"
    inreplace format_sources, "std::format(", "fmt::format("

    args = %W[
      -DZ3_LINK_TIME_OPTIMIZATION=ON
      -DZ3_INCLUDE_GIT_DESCRIBE=OFF
      -DZ3_INCLUDE_GIT_HASH=OFF
      -DZ3_INSTALL_PYTHON_BINDINGS=ON
      -DZ3_BUILD_EXECUTABLE=ON
      -DZ3_BUILD_TEST_EXECUTABLES=OFF
      -DZ3_BUILD_PYTHON_BINDINGS=ON
      -DZ3_BUILD_DOTNET_BINDINGS=OFF
      -DZ3_BUILD_JAVA_BINDINGS=OFF
      -DZ3_USE_LIB_GMP=OFF
      -DPYTHON_EXECUTABLE=#{python3}
      -DCMAKE_INSTALL_PYTHON_PKG_DIR=#{Language::Python.site_packages(python3)}
    ]

    if OS.mac? && DevelopmentTools.clang_build_version <= 1400
      args << "-DCMAKE_CXX_COMPILER_AR=#{Formula["llvm"].opt_bin}/llvm-ar"
      args << "-DCMAKE_CXX_COMPILER_RANLIB=#{Formula["llvm"].opt_bin}/llvm-ranlib"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    system "make", "-C", "contrib/qprofdiff"
    bin.install "contrib/qprofdiff/qprofdiff"

    pkgshare.install "examples"
  end

  test do
    system ENV.cc, pkgshare/"examples/c/test_capi.c", "-I#{include}",
                   "-L#{lib}", "-lz3", "-o", testpath/"test"
    system "./test"
    assert_equal version.to_s, shell_output("#{python3} -c 'import z3; print(z3.get_version_string())'").strip
  end
end
