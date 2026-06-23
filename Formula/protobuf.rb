class Protobuf < Formula
  desc "Protocol buffers (Google's data interchange format)"
  homepage "https://protobuf.dev/"
  url "https://github.com/protocolbuffers/protobuf/releases/download/v35.1/protobuf-35.1.tar.gz"
  sha256 "f0b6838e7522a8da96126d487068c959bc624926368f3024ac8fd03abd0a1ac4"
  license "BSD-3-Clause"
  compatibility_version 4

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
  end

  depends_on "cmake" => :build
  depends_on "abseil"

  on_macos do
    # TODO: Try restoring tests on Linux in a future release. Currently they
    # fail to build as Clang causes an ABI difference in Abseil that impacts
    # a testcase. Also GCC 13 failed to compile UPB tests in Protobuf 34.0
    depends_on "googletest" => :build
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100
  end

  on_linux do
    depends_on "llvm" => :build if DevelopmentTools.gcc_version < 13
    depends_on "zlib-ng-compat"
  end

  fails_with :gcc do
    version "12"
    cause "fails handling ABSL_ATTRIBUTE_WARN_UNUSED"
  end

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    # TODO: Remove after moving CI to Ubuntu 24.04. Cannot use newer GCC as it
    # will increase minimum GLIBCXX in bottle resulting in a runtime dependency.
    #ENV.llvm_clang if OS.linux? && deps.map(&:name).any?("llvm")

    # Keep `CMAKE_CXX_STANDARD` in sync with the same variable in `abseil.rb`.
    abseil_cxx_standard = 17
    cmake_args = %W[
      -DCMAKE_CXX_STANDARD=#{abseil_cxx_standard}
      -DBUILD_SHARED_LIBS=ON
      -Dprotobuf_BUILD_LIBPROTOC=ON
      -Dprotobuf_BUILD_SHARED_LIBS=ON
      -Dprotobuf_INSTALL_EXAMPLES=ON
      -Dprotobuf_BUILD_TESTS=#{OS.mac? ? "ON" : "OFF"}
      -Dprotobuf_FORCE_FETCH_DEPENDENCIES=OFF
      -Dprotobuf_LOCAL_DEPENDENCIES_ONLY=ON
      -DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}
      -DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}
    ]

    system "cmake", "-S", ".", "-B", "build", *cmake_args, *std_cmake_args
    system "cmake", "--build", "build"
    system "ctest", "--test-dir", "build", "--verbose"
    system "cmake", "--install", "build"

    (share/"vim/vimfiles/syntax").install "editors/proto.vim"
    elisp.install "editors/protobuf-mode.el"
  end

  test do
    (testpath/"test.proto").write <<~PROTO
      syntax = "proto3";
      package test;
      message TestCase {
        string name = 4;
      }
      message Test {
        repeated TestCase case = 1;
      }
    PROTO
    system bin/"protoc", "test.proto", "--cpp_out=."
  end
end
