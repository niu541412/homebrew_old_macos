class Openexr < Formula
  desc "High dynamic-range image file format"
  homepage "https://www.openexr.com/"
  url "https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.4.12.tar.gz"
  sha256 "a455779c389f65c64220d45b63ead2900081e5f6337cdf93431cb1032c3e2686"
  license "BSD-3-Clause"
  compatibility_version 1

  bottle do
  end

  depends_on "cmake" => :build
  depends_on "pkgconf" => :build

  depends_on "imath"
  depends_on "libdeflate"
  depends_on "openjph"
  depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100

  on_linux do
    depends_on "zlib-ng-compat"
  end

  # These used to be provided by `ilmbase`
  link_overwrite "include/OpenEXR"
  link_overwrite "lib/libIex.dylib"
  link_overwrite "lib/libIex.so"
  link_overwrite "lib/libIlmThread.dylib"
  link_overwrite "lib/libIlmThread.so"

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, 
        "-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}",
        "-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    resource "homebrew-exr" do
      url "https://github.com/AcademySoftwareFoundation/openexr-images/raw/f17e353fbfcde3406fe02675f4d92aeae422a560/TestImages/AllHalfValues.exr"
      sha256 "eede573a0b59b79f21de15ee9d3b7649d58d8f2a8e7787ea34f192db3b3c84a4"
    end

    resource("homebrew-exr").stage do
      system bin/"exrheader", "AllHalfValues.exr"
    end
  end
end
