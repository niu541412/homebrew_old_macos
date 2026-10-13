class Mold < Formula
  desc "Modern Linker"
  homepage "https://github.com/rui314/mold"
  url "https://github.com/rui314/mold/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "1dee837e227b0c3f2661def602ef8ddc0b889ae5b1d28c1ddec5f29e08e5ceb5"
  license "MIT"
  head "https://github.com/rui314/mold.git", branch: "main"

  # There can be a notable gap between when a version is tagged and a
  # corresponding release is created, so we check the "latest" release instead
  # of the Git tags.
  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
  end

  depends_on "rust" => :build

  on_macos do
    depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  end

  on_linux do
    depends_on "zlib-ng-compat"

    # Some arch-aarch64-* tests depend on Clang. For instance:
    # https://github.com/rui314/mold/blob/v3.0.0/tests/arch-aarch64-tlsle-ldst.sh#L121
    on_arm do
      depends_on "llvm" => :test
    end
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    if DevelopmentTools.clang_build_version <= 1000
      ENV.llvm_clang
      ENV["MACOSX_DEPLOYMENT_TARGET"] = MacOS.version.to_s
    end

    ENV["MOLD_LIBDIR"] = opt_lib
    system "cargo", "install", *std_cargo_args(path: "cli")

    # https://github.com/rui314/mold/blob/main/install-mold.sh
    (lib/"mold").install "target/release/mold-wrapper.so" if OS.linux?
    man1.install "docs/mold.1"
    bin.install_symlink bin/"mold" => "ld.mold"
    (libexec/"mold").install_symlink bin/"mold" => "ld"
    man1.install_symlink man1/"mold.1" => "ld.mold.1"

    pkgshare.install "tests"
  end

  test do
    (testpath/"test.c").write <<~C
      int main(void) { return 0; }
    C

    linker_flag = case ENV.compiler
    when /^gcc(-(\d|10|11))?$/ then "-B#{libexec}/mold"
    when :clang, /^gcc-\d{2,}$/ then "-fuse-ld=mold"
    else odie "unexpected compiler"
    end

    extra_flags = %w[-fPIE -pie]
    extra_flags += %w[--target=x86_64-unknown-linux-gnu -nostdlib] unless OS.linux?

    system ENV.cc, linker_flag, *extra_flags, "test.c"
    if OS.linux?
      system "./a.out"
    else
      assert_match "ELF 64-bit LSB pie executable, x86-64", shell_output("file a.out")
    end

    return unless OS.linux?

    cp_r pkgshare/"tests", testpath

    # Remove non-native tests.
    arch = Hardware::CPU.arch.to_s
    arch = "aarch64" if arch == "arm64"
    testpath.glob("tests/arch-*.sh")
            .reject { |f| f.basename(".sh").to_s.match?(/^arch-#{arch}-/) }
            .each(&:unlink)

    inreplace testpath.glob("tests/*.sh") do |s|
      s.gsub!(%r{(\./|`pwd`/|\$PWD/)?mold-wrapper}, lib/"mold/mold-wrapper", audit_result: false)
      s.gsub!(%r{(\.|`pwd`|\$PWD)/mold}, bin/"mold", audit_result: false)
      s.gsub!(/-B(\.|`pwd`|\$PWD)/, "-B#{libexec}/mold", audit_result: false)
    end

    # The `inreplace` rules above do not work well on this test. To avoid adding
    # too much complexity to the regex rules, it is manually tested below
    # instead.
    (testpath/"tests/mold-wrapper2.sh").unlink
    assert_match "mold-wrapper.so",
      shell_output("#{bin}/mold -run bash -c 'echo $LD_PRELOAD'")

    # Run the remaining tests.
    testpath.glob("tests/*.sh").each { |t| system "bash", t }
  end
end
