class Pandoc < Formula
  desc "Swiss-army knife of markup format conversion"
  homepage "https://pandoc.org/"
  url "https://github.com/jgm/pandoc/archive/refs/tags/3.8.3.tar.gz"
  sha256 "064775f55802fea443c53b9ad61b6af5aab3fcda71c40e8ccb97f650dce78640"
  license "GPL-2.0-or-later"
  head "https://github.com/jgm/pandoc.git", branch: "main"

  bottle do
  end

  depends_on "cabal-install" => :build
  depends_on "ghc" => :build
  depends_on "gmp"
  #depends_on "llvm@18" => :build
  #depends_on "llvm" => :build

  uses_from_macos "unzip" => :build # for cabal install
  uses_from_macos "libffi"
  uses_from_macos "zlib"

  def install
    #llvm = Formula["llvm@18"]
    #llvm = Formula["llvm"]
    #ENV["CC"] = "#{llvm.opt_bin}/clang"
    #ENV["CXX"] = "#{llvm.opt_bin}/clang++"
    system "cabal", "v2-update"
    system "cabal", "v2-install", *std_cabal_v2_args, "pandoc-cli"
    # system "cabal", "v2-install", *std_cabal_v2_args, "pandoc-cli","--with-cc=#{llvm.opt_bin}/clang", "--with-cxx=#{llvm.opt_bin}/clang"
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
