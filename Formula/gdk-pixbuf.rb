class GdkPixbuf < Formula
  desc "Toolkit for image loading and pixel buffer manipulation"
  homepage "https://gtk.org"
  url "https://download.gnome.org/sources/gdk-pixbuf/2.44/gdk-pixbuf-2.44.6.tar.xz"
  sha256 "140c2d0b899fcf853ee92b26373c9dc228dbcde0820a4246693f4328a27466fa"
  license "LGPL-2.1-or-later"
  revision 1
  compatibility_version 1

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

  def install
    # Use HOMEBREW_PREFIX to find modules installed by dependents without
    # needing environment variables or inreplaces. In order to support this,
    # we need install into a staging directory.
    meson_args = std_meson_args.map { |s| s.sub prefix, HOMEBREW_PREFIX }
    ENV["DESTDIR"] = buildpath/"stage"

    #inreplace "gdk-pixbuf/meson.build",
    #          "-DGDK_PIXBUF_LIBDIR=\"@0@\"'.format(gdk_pixbuf_libdir)",
    #          "-DGDK_PIXBUF_LIBDIR=\"@0@\"'.format('#{HOMEBREW_PREFIX}/lib')"

    #ENV["DESTDIR"] = "/"
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
                                      *meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
    prefix.install Pathname(File.join("stage", HOMEBREW_PREFIX)).children
  end

    # Other packages should use the top-level modules directory
    # rather than dumping their files into the gdk-pixbuf keg.
    #inreplace lib/"pkgconfig/gdk-pixbuf-#{gdk_so_ver}.pc" do |s|
    #  s.change_make_var! "prefix", HOMEBREW_PREFIX
    #end
  #end

  # The directory that loaders.cache gets linked into, also has the "loaders"
  # directory that is scanned by gdk-pixbuf-query-loaders in the first place
  #def module_dir
  #  "#{HOMEBREW_PREFIX}/lib/gdk-pixbuf-#{gdk_so_ver}/#{gdk_module_ver}"
  #end

  #def post_install
  #  ENV["GDK_PIXBUF_MODULEDIR"] = "#{module_dir}/loaders"
  #  system bin/"gdk-pixbuf-query-loaders", "--update-cache"
  post_install_steps do
    gdk_pixbuf_query_loaders
  end

  test do
    (testpath/"test.c").write <<~C
      #include <gdk-pixbuf/gdk-pixbuf.h>

      int main(int argc, char *argv[]) {
        GType type = gdk_pixbuf_get_type();
        return 0;
      }
    C
    #flags = shell_output("pkgconf --cflags --libs gdk-pixbuf-#{gdk_so_ver}").chomp.split

    gdk_pixbuf_pc = lib.glob("pkgconfig/gdk-pixbuf-*.pc").first.basename(".pc")
    flags = shell_output("pkgconf --cflags --libs #{gdk_pixbuf_pc}").chomp.split
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"

    # Check that HOMEBREW_PREFIX paths are used
    gdk_pixbuf_cache_file = shell_output("pkgconf --variable=gdk_pixbuf_cache_file #{gdk_pixbuf_pc}").chomp
    loaders = shell_output(bin/"gdk-pixbuf-query-loaders")
    assert_match "#{HOMEBREW_PREFIX}/lib/", gdk_pixbuf_cache_file
    assert_match "LoaderDir = #{HOMEBREW_PREFIX}/lib/gdk-pixbuf-", loaders
    refute_match prefix.realpath.to_s, loaders
  end
end
