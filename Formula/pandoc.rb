class Pandoc < Formula
  desc "Swiss-army knife of markup format conversion"
  homepage "https://pandoc.org/"
  url "https://github.com/jgm/pandoc/archive/refs/tags/3.11.tar.gz"
  sha256 "61d05e7fc57e995a61367bee1bb73a8bb278cda3c787b7e4e27b30037e17aeed"
  license "GPL-2.0-or-later"
  compatibility_version 7
  head "https://github.com/jgm/pandoc.git", branch: "main"

  bottle do
  end

  depends_on "cabal-install" => :build
  depends_on "ghc" => :build
  depends_on "gmp"

  uses_from_macos "unzip" => :build # for cabal install
  uses_from_macos "libffi", since: :catalina

  on_linux do
    depends_on "zlib-ng-compat"
  end

  def install
    # Workaround to build aeson with GHC 9.14, https://github.com/haskell/aeson/issues/1155
    args = ["--allow-newer=base,containers,template-haskell"]

    system "cabal", "v2-update"
    system "cabal", "v2-install", *args, *std_cabal_v2_args, "pandoc-cli"
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
