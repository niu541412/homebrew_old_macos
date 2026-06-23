class Newsboat < Formula
  desc "RSS/Atom feed reader for text terminals"
  homepage "https://newsboat.org/"
  url "https://newsboat.org/releases/2.44/newsboat-2.44.tar.xz"
  sha256 "8cb376b14c44809750a41b74c239a47092edb8e496f657c38af9b852dd8e4ea4"
  license "MIT"
  head "https://github.com/newsboat/newsboat.git", branch: "master"

  bottle do
  end

  depends_on "asciidoctor" => :build
  depends_on "gettext" => :build
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "xz" => :build
  depends_on "json-c"

  depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  uses_from_macos "curl", since: :catalina
  uses_from_macos "libxml2"
  uses_from_macos "libxslt"
  uses_from_macos "ncurses"
  uses_from_macos "sqlite"

  on_macos do
    depends_on "make" => :build
    depends_on "gettext"
  end

  on_tahoe do
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version == 1700

    fails_with :clang do
      build 1700
      cause "https://github.com/llvm/llvm-project/issues/142118"
    end
  end

  # Newsboat have their own libstfl fork. Upstream libsftl is gone:
  # https://github.com/Homebrew/homebrew-core/pull/89981
  # They do not want to be the new upstream, but use that fork as a temporary
  # workaround until they migrate to some rust crate
  # https://github.com/newsboat/newsboat/issues/232
  resource("libstfl") do
    url "https://github.com/newsboat/stfl.git",
        revision: "bbb2404580e845df2556560112c8aefa27494d66"
  end

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    resource("libstfl").stage do
      if OS.mac?
        ENV.append "LDLIBS", "-liconv"
        ENV.append "LIBS", "-lncurses -lruby -liconv"

        inreplace "stfl_internals.h", "ncursesw/ncurses.h", "ncurses.h"
        inreplace %w[stfl.pc.in ruby/Makefile.snippet], "ncursesw", "ncurses"

        inreplace "Makefile" do |s|
          s.gsub! "ncursesw", "ncurses"
          s.gsub! "-Wl,-soname,$(SONAME)", "-Wl"
          s.gsub! "libstfl.so.$(VERSION)", "libstfl.$(VERSION).dylib"
          s.gsub! "libstfl.so", "libstfl.dylib"
        end

        # Fix ncurses linkage for Perl bundle
        inreplace "perl5/Makefile.PL", "-lncursesw", "-L#{MacOS.sdk_path}/usr/lib -lncurses"
      else
        ENV.append "LIBS", "-lncursesw -lruby"
        inreplace "Makefile", "$(LDLIBS) $^", "$^ $(LDLIBS)"
      end

      # Fix "call to undeclared function 'wget_wch'".
      ENV.append_to_cflags "-D_XOPEN_SOURCE_EXTENDED=1"

      # Fails race condition of test:
      #   ImportError: dynamic module does not define init function (init_stfl)
      #   make: *** [python/_stfl.so] Error 1
      ENV.deparallelize do
        system "make"
        system "make", "install", "prefix=#{libexec}"
      end

      cp (libexec/"lib/libstfl.so"), (libexec/"lib/libstfl.so.0") if OS.linux?
    end

    inreplace "Makefile", "-Werror ", ""
    
    gettext = Formula["gettext"]

    ENV["GETTEXT_BIN_DIR"] = gettext.opt_bin.to_s
    ENV["GETTEXT_LIB_DIR"] = gettext.lib.to_s
    ENV["GETTEXT_INCLUDE_DIR"] = gettext.include.to_s
    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog"

    # Remove once libsftl is not used anymore
    ENV.prepend_path "PKG_CONFIG_PATH", libexec/"lib/pkgconfig"
    ENV.append "LDFLAGS", "-Wl,-rpath,#{libexec}/lib"

    # Work around Apple's ncurses5.4-config outputting -lncursesw
    if OS.mac? && MacOS.version >= :sonoma
      system "gmake", "config", "prefix=#{prefix}"
      inreplace "config.mk", "-lncursesw", "-lncurses"
    end

    # Call `make` as `gmake` to use Homebrew `make`.
    system "gmake", "install", "prefix=#{prefix}"
  end

  test do
    (testpath/"urls.txt").write "https://github.blog/subscribe/"
    assert_match "Newsboat - Exported Feeds", shell_output("LC_ALL=C #{bin}/newsboat -e -u urls.txt")
  end
end
