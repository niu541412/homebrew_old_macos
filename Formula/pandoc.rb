class Pandoc < Formula
  desc "Swiss-army knife of markup format conversion"
  homepage "https://pandoc.org/"
  url "https://github.com/jgm/pandoc/archive/refs/tags/3.9.tar.gz"
  sha256 "d8da16e1ad1f685123fbc1a5a83b74766bcfd939dc6989484822f023bb70438f"
  license "GPL-2.0-or-later"
  compatibility_version 1
  head "https://github.com/jgm/pandoc.git", branch: "main"

  bottle do
  end

  depends_on "cabal-install" => :build
  depends_on "ghc" => :build
  depends_on "gmp"
  # manually switch to llvm@18
  #depends_on "llvm@18" => :build
  #depends_on "llvm" => :build

  uses_from_macos "unzip" => :build # for cabal install
  uses_from_macos "libffi"
  uses_from_macos "zlib"

  def install
    # Workaround to build aeson with GHC 9.14, https://github.com/haskell/aeson/issues/1155
    args = ["--allow-newer=base,containers,template-haskell"]
    llvm = Formula["llvm@18"]
    #llvm = Formula["llvm"]
    #ENV["CC"] = "#{llvm.opt_bin}/clang"
    #ENV["CXX"] = "#{llvm.opt_bin}/clang++"
    ENV.append_to_cflags "#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}" if OS.mac?
    system "cabal", "v2-update"
    system "cabal", "v2-install", *args, *std_cabal_v2_args, "pandoc-cli"
    #system "cabal", "v2-install", *args, *std_cabal_v2_args, "pandoc-cli","--with-cc=#{llvm.opt_bin}/clang", "--with-cxx=#{llvm.opt_bin}/clang"
    generate_completions_from_executable(bin/"pandoc", "--bash-completion",
                                         shells: [:bash], shell_parameter_format: :none)
    man1.install "pandoc-cli/man/pandoc.1"
  end

  test do
    input_markdown = <<~MARKDOWN
      # Homebrew

      A package manager for humans. Cats should take a look at Tigerbrew.
    MARKDOWN
    expected_html = <<~HTML
      <h1 id="homebrew">Homebrew</h1>
      <p>A package manager for humans. Cats should take a look at
      Tigerbrew.</p>
    HTML
    assert_equal expected_html, pipe_output("#{bin}/pandoc -f markdown -t html5", input_markdown, 0)
  end
end
