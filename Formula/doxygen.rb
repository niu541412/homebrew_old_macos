class Doxygen < Formula
  desc "Generate documentation for several programming languages"
  homepage "https://www.doxygen.nl/"
  url "https://doxygen.nl/files/doxygen-1.16.1.src.tar.gz"
  mirror "https://downloads.sourceforge.net/project/doxygen/rel-1.16.1/doxygen-1.16.1.src.tar.gz"
  sha256 "201ce33b514ea87cc1697c0dcf829692c2695c1812683a9cc622194b05e263a8"
  license "GPL-2.0-only"
  head "https://github.com/doxygen/doxygen.git", branch: "master"

  livecheck do
    url "https://www.doxygen.nl/download.html"
    regex(/href=.*?doxygen[._-]v?(\d+(?:\.\d+)+)[._-]src\.t/i)
  end

  bottle do
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "llvm" => :build

  uses_from_macos "flex" => :build, since: :big_sur
  uses_from_macos "python" => :build, since: :catalina

  def install
    system "cmake", "-S", ".", "-B", "build",
                    "-DPython_EXECUTABLE=#{which("python3")}",
                    "-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    system "cmake", "-S", ".", "-B", "build", "-Dbuild_doc=1", *std_cmake_args
    man1.install buildpath.glob("build/man/*.1")
  end

  test do
    system bin/"doxygen", "-g"
    system bin/"doxygen", "Doxyfile"
  end
end
