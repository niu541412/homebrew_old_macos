class Btop < Formula
  desc "Resource monitor. C++ version and continuation of bashtop and bpytop"
  homepage "https://github.com/aristocratos/btop"
  url "https://github.com/aristocratos/btop/archive/refs/tags/v1.4.6.tar.gz"
  sha256 "4beb90172c6acaac08c1b4a5112fb616772e214a7ef992bcbd461453295a58be"
  license "Apache-2.0"
  head "https://github.com/aristocratos/btop.git", branch: "main"

  bottle do
  end

  depends_on "lowdown" => :build

  on_macos do
    depends_on "coreutils" => :build
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1600
  end

  on_linux do
    depends_on "gcc"
  end

  fails_with :clang do
    build 1600
    cause "Requires C++23 support for `std::ranges::to`"
  end

  fails_with :gcc do
    version "13"
    cause "Requires C++23 support for `std::ranges::to`"
  end

  def install
    #ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1499 || MacOS.version == :ventura)
    ENV.append "LDFLAGS", "#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"
    ENV.append "CC", "-D_GNU_SOURCE" if OS.linux? && Hardware::CPU.intel?

    system "make", "CXX=#{ENV.cxx}", "STRIP=true"
    system "make", "PREFIX=#{prefix}", "install"
  end

  test do
    # The build will silently skip the manpage if it can't be built,
    # so let's double-check that it was.
    assert_path_exists man1/"btop.1"

    require "pty"
    require "io/console"

    config = (testpath/".config/btop")
    mkdir config/"themes"
    begin
      (config/"btop.conf").write <<~EOS
        #? Config file for btop v. #{version}

        update_ms=2000
        log_level=DEBUG
      EOS

      r, w, pid = PTY.spawn(bin/"btop", "--force-utf")
      r.winsize = [80, 130]
      sleep 5
      w.write "q"
    rescue Errno::EIO
      # Apple silicon raises EIO
    end

    log = (testpath/".local/state/btop.log").read
    # SMC is not available in VMs.
    log = log.lines.grep_v(/ERROR:.* SMC /).join if Hardware::CPU.virtualized?
    assert_match "===> btop++ v.#{version}", log
    refute_match(/ERROR:/, log)
  ensure
    Process.kill("TERM", pid)
  end
end
