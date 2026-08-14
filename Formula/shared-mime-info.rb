class SharedMimeInfo < Formula
  desc "Database of common MIME types"
  homepage "https://wiki.freedesktop.org/www/Software/shared-mime-info"
  url "https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/2.5.1/shared-mime-info-2.5.1.tar.bz2"
  sha256 "b75b420da9b0be9a3d99b1bee6ed87957b56ab54583ac1a97fbd0dc98ddddb25"
  license "GPL-2.0-only"
  compatibility_version 1
  head "https://gitlab.freedesktop.org/xdg/shared-mime-info.git", branch: "master"

  livecheck do
    url "https://gitlab.freedesktop.org/api/v4/projects/1205/releases"
    regex(/^(?:Release[._-])?v?(\d+(?:[.-]\d+)+)$/i)
    strategy :json do |json, regex|
      json.map { |item| item["tag_name"]&.[](regex, 1)&.tr("-", ".") }
    end
  end

  bottle do
  end

  depends_on "gettext" => :build
  depends_on "itstool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "xmlto" => :build
  depends_on "glib"

  uses_from_macos "libxml2"

  on_macos do
    depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  end

  # This used to be copied rather than symlinked
  link_overwrite "share/mime/packages/freedesktop.org.xml"

  def install
    if OS.mac? && DevelopmentTools.clang_build_version <= 1100
      ENV.llvm_clang
      ENV.append "LDFLAGS", "#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"
    end
    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog"

    system "meson", "setup", "build", "-Dbuild-tests=false", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  post_install_steps do
    update_mime_database
  end

  test do
    ENV["XDG_DATA_HOME"] = testpath

    cp_r share/"mime", testpath
    system bin/"update-mime-database", testpath/"mime"
  end
end
