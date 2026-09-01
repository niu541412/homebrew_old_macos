class Simdutf < Formula
  desc "Unicode conversion routines, fast"
  homepage "https://simdutf.github.io/simdutf/"
  url "https://github.com/simdutf/simdutf/archive/refs/tags/v9.1.0.tar.gz"
  sha256 "24e3510a4c95a9e6eb0fb4a27eea650d13773231cbd8b564ed9670aa5484d193"
  license any_of: ["Apache-2.0", "MIT"]
  compatibility_version 4
  head "https://github.com/simdutf/simdutf.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
  end

  depends_on "aklomp-base64" => :build
  depends_on "cmake" => :build
  depends_on "icu4c@78"
  depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100

  uses_from_macos "python" => :build

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    args = %W[
      -DBUILD_SHARED_LIBS=ON
      -DCMAKE_INSTALL_RPATH=#{rpath}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
      -DCPM_LOCAL_PACKAGES_ONLY=ON
      -DPython3_EXECUTABLE=#{which("python3")}
      -DSIMDUTF_BENCHMARKS=ON
      -DCMAKE_EXE_LINKER_FLAGS=#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}
    ]
    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
    bin.install "build/benchmarks/benchmark" => "sutf-benchmark"
  end

  test do
    system bin/"sutf-benchmark", "--random-utf8", "10240", "-I", "100"
  end
end
