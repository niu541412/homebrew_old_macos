class Sk < Formula
  desc "Fuzzy Finder in rust!"
  homepage "https://github.com/skim-rs/skim"
  url "https://github.com/skim-rs/skim/archive/refs/tags/v5.6.6.tar.gz"
  sha256 "4f988bf6da4a5e1f71e296d7f96047db2d24253a06a5597b179206f7ecd034d7"
  license "MIT"
  head "https://github.com/skim-rs/skim.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
  end

  depends_on "rust" => :build
  
  on_macos do
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100
  end

  def install
    inreplace "shell/key-bindings.bash", "[[ ! -v NO_COLOR ]]", '[ -z "${NO_COLOR+x}" ]'   
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    system "cargo", "install", *std_cargo_args

    generate_completions_from_executable(bin/"sk", "--shell")
    bash_completion.install "shell/key-bindings.bash"
    fish_completion.install "shell/key-bindings.fish" => "skim.fish"
    zsh_completion.install "shell/key-bindings.zsh"
    man1.install buildpath.glob("man/man1/*.1")
    bin.install "bin/sk-tmux"
  end

  test do
    assert_match(/.*world/, pipe_output("#{bin}/sk -f wld", "hello\nworld"))
  end
end
