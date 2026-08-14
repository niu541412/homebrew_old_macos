class Lnav < Formula
  desc "Curses-based tool for viewing and analyzing log files"
  homepage "https://lnav.org/"
  url "https://github.com/tstack/lnav/releases/download/v0.14.0/lnav-0.14.0.tar.gz"
  sha256 "0fd591a2e0488a06b3b44d7b384d3d7c6852d68607efc16ef4dec7a6ed054eea"
  license "BSD-2-Clause"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
  end

  head do
    url "https://github.com/tstack/lnav.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "re2c" => :build
  end

  depends_on "rust" => :build
  depends_on "libarchive"
  depends_on "libunistring"
  depends_on "pcre2"
  depends_on "sqlite"
  depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100

  uses_from_macos "bzip2"
  uses_from_macos "curl", since: :catalina

  on_linux do
    depends_on "zlib-ng-compat"
  end

  def install
    if OS.mac? && DevelopmentTools.clang_build_version <= 1100
      ENV.llvm_clang
      ENV.append "LDFLAGS", "#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"
    end
    system "./autogen.sh" if build.head?
    system "./configure", "--with-sqlite3=#{formula_opt_prefix("sqlite")}",
                          "--with-libarchive=#{formula_opt_prefix("libarchive")}",
                          *std_configure_args
    system "make", "install", "V=1"
  end

  test do
    system bin/"lnav", "-V"

    assert_match "col1", pipe_output("#{bin}/lnav -n -c ';from [{ col1=1 }] | take 1'", "foo")
  end
end
