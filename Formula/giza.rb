class Giza < Formula
  desc "Scientific plotting library for C/Fortran built on cairo"
  homepage "https://danieljprice.github.io/giza/"
  url "https://github.com/danieljprice/giza/releases/download/v2.0.2/giza-v2.0.2.tar.gz"
  sha256 "2dc801eb976ab28d083cb41b5e4dc595c4d956d9fed173c5d76fcf29eca0210d"
  license "LGPL-3.0-only"
  head "https://github.com/danieljprice/giza.git", branch: "main"

  bottle do
  end

  depends_on "pkgconf" => :build

  depends_on "cairo"
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "gcc" # for gfortran
  depends_on "libx11"

  def install
    inreplace "src/giza-driver-osxcocoa.m", "_layer", "_gizaLayer"

    system "./configure", "--disable-silent-rules", *std_configure_args
    system "make", "install"

    # Install test files to use during `brew test`
    rm(Dir["test/**/Makefile*"])
    prefix.install "test"
  end

  test do
    cp_r prefix/"test/C/.", testpath

    flags = %W[
      -I#{include}
      -I#{formula_opt_include("cairo")}/cairo
      -L#{lib}
      -L#{formula_opt_lib("libx11")}
      -L#{formula_opt_lib("cairo")}
      -lX11
      -lcairo
      -lgiza
    ]

    %w[
      test-XOpenDisplay.c
      test-cairo-xw.c
      test-giza-xw.c
      test-rectangle.c
      test-window.c
    ].each do |file|
      system ENV.cc, file, *flags
    end
  end
end
