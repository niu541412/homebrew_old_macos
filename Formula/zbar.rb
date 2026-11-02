class Zbar < Formula
  desc "Suite of barcodes-reading tools"
  homepage "https://linuxtv.org/downloads/zbar/"
  url "https://linuxtv.org/downloads/zbar/zbar-0.23.95.tar.gz"
  sha256 "7b0907a3114503e0a8fbd1c6bfdb61592e6ded79f68716d7ca673ddeb6a87e99"
  license "LGPL-2.1-only"
  head "https://github.com/mchehab/zbar.git", branch: "master"

  livecheck do
    url :homepage
    regex(/href=.*?zbar[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
  end

  depends_on "gettext" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "xmlto" => :build

  depends_on "imagemagick"
  depends_on "jpeg-turbo"

  uses_from_macos "python", since: :catalina

  on_macos do
    depends_on "fontconfig"
    depends_on "freetype"
    depends_on "gettext"
    depends_on "glib"
    depends_on "liblqr"
    depends_on "libomp"
    depends_on "libtool"
    depends_on "little-cms2"
  end

  on_linux do
    depends_on "dbus"
  end

  deny_network_access!

  def install
    args = %w[
      -Dvideo=false
      -Djava=disabled
      -Dqt=false
      -Dgtk=no
      -Dx11=disabled
    ]

    # zbar uses gettext but upstream only links libintl on Windows, and the
    # newer macOS linker no longer resolves it transitively. Link it explicitly.
    ENV.append "LDFLAGS", "-lintl" if OS.mac?

    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog"

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"

    pkgshare.install "examples/qr-code.png"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/zbarimg --version")

    output = shell_output("#{bin}/zbarimg -1 #{pkgshare}/qr-code.png 2>/dev/null")
    assert_match "QR-Code:https://github.com/mchehab/zbar", output
  end
end
