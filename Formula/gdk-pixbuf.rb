class GdkPixbuf < Formula
  desc "Toolkit for image loading and pixel buffer manipulation"
  homepage "https://gtk.org"
  url "https://download.gnome.org/sources/gdk-pixbuf/2.44/gdk-pixbuf-2.44.5.tar.xz"
  sha256 "69b93e09139b80c0ee661503d60deb5a5874a31772b5184b9cd5462a4100ab68"
  license "LGPL-2.1-or-later"

  bottle do
  end

  depends_on "docutils" => :build # for rst2man
  depends_on "gettext" => :build
  depends_on "gobject-introspection" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => [:build, :test]
  depends_on "glib"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "libdeflate" => :build
  depends_on "python" => :build
  uses_from_macos "libffi", since: :catalina

  on_macos do
    depends_on "gettext"
  end

  on_linux do
    depends_on "shared-mime-info"
  end

  # gdk-pixbuf has an internal version number separate from the overall
  # version number that specifies the location of its module and cache
  # files, this will need to be updated if that internal version number
  # is ever changed (as evidenced by the location no longer existing)
  def gdk_so_ver
    "2.0"
  end

  def gdk_module_ver
    "2.10.0"
  end

  def install
    inreplace "gdk-pixbuf/meson.build",
              "-DGDK_PIXBUF_LIBDIR=\"@0@\"'.format(gdk_pixbuf_libdir)",
              "-DGDK_PIXBUF_LIBDIR=\"@0@\"'.format('#{HOMEBREW_PREFIX}/lib')"

    ENV["DESTDIR"] = "/"
    system "meson", "setup", "build", "-Drelocatable=false",
                                      "-Dnative_windows_loaders=false",
                                      "-Dtests=false",
                                      "-Dinstalled_tests=false",
                                      "-Dman=true",
                                      "-Dgtk_doc=false",
                                      "-Dpng=enabled",
                                      "-Dtiff=enabled",
                                      "-Djpeg=enabled",
                                      "-Dothers=enabled",
                                      "-Dintrospection=enabled",
                                      "-Dglycin=disabled",
                                      *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"

    # Other packages should use the top-level modules directory
    # rather than dumping their files into the gdk-pixbuf keg.
    inreplace lib/"pkgconfig/gdk-pixbuf-#{gdk_so_ver}.pc" do |s|
      s.change_make_var! "prefix", HOMEBREW_PREFIX
    end
  end

  # The directory that loaders.cache gets linked into, also has the "loaders"
  # directory that is scanned by gdk-pixbuf-query-loaders in the first place
  def module_dir
    "#{HOMEBREW_PREFIX}/lib/gdk-pixbuf-#{gdk_so_ver}/#{gdk_module_ver}"
  end

  def post_install
    ENV["GDK_PIXBUF_MODULEDIR"] = "#{module_dir}/loaders"
    system bin/"gdk-pixbuf-query-loaders", "--update-cache"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <gdk-pixbuf/gdk-pixbuf.h>

      int main(int argc, char *argv[]) {
        GType type = gdk_pixbuf_get_type();
        return 0;
      }
    C
    flags = shell_output("pkgconf --cflags --libs gdk-pixbuf-#{gdk_so_ver}").chomp.split
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
