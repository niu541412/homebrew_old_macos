class GobjectIntrospection < Formula
  include Language::Python::Shebang
  include Language::Python::Virtualenv

  desc "Generate introspection data for GObject libraries"
  homepage "https://gi.readthedocs.io/en/latest/"
  url "https://download.gnome.org/sources/gobject-introspection/1.86/gobject-introspection-1.86.0.tar.xz"
  sha256 "920d1a3fcedeadc32acff95c2e203b319039dd4b4a08dd1a2dfd283d19c0b9ae"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.0-or-later", "MIT"]
  revision 1
  compatibility_version 1

  bottle do
  end

  depends_on "bison" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "cairo"
  depends_on "glib"
  depends_on "pkgconf"
  # Ships a `_giscanner.cpython-314-darwin.so`, so needs a specific version.
  depends_on "python@3.14"

  uses_from_macos "flex" => :build
  uses_from_macos "libffi", since: :catalina

  pypi_packages package_name:   "",
                extra_packages: %w[mako markdown setuptools]

  resource "mako" do
    url "https://files.pythonhosted.org/packages/59/8a/805404d0c0b9f3d7a326475ca008db57aea9c5c9f2e1e39ed0faa335571c/mako-1.3.11.tar.gz"
    sha256 "071eb4ab4c5010443152255d77db7faa6ce5916f35226eb02dc34479b6858069"
  end

  resource "markdown" do
    url "https://files.pythonhosted.org/packages/2b/f4/69fa6ed85ae003c2378ffa8f6d2e3234662abd02c10d216c0ba96081a238/markdown-3.10.2.tar.gz"
    sha256 "994d51325d25ad8aa7ce4ebaec003febcce822c3f8c911e3b17c52f7f589f950"
  end

  resource "markupsafe" do
    url "https://files.pythonhosted.org/packages/7e/99/7690b6d4034fffd95959cbe0c02de8deb3098cc577c67bb6a24fe5d7caa7/markupsafe-3.0.3.tar.gz"
    sha256 "722695808f4b6457b320fdc131280796bdceb04ab50fe1795cd540799ebe1698"
  end

  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/4f/db/cfac1baf10650ab4d1c111714410d2fbb77ac5a616db26775db562c8fab2/setuptools-82.0.1.tar.gz"
    sha256 "7d872682c5d01cfde07da7bccc7b65469d3dca203318515ada1de5eda35efbf9"
  end

  # Fix library search path on non-/usr/local installs (e.g. Apple Silicon)
  # See: https://github.com/Homebrew/homebrew-core/issues/75020
  #      https://gitlab.gnome.org/GNOME/gobject-introspection/-/merge_requests/273
  patch :DATA

  def install
    venv = virtualenv_create(libexec, "python3.14")
    venv.pip_install resources
    ENV.prepend_path "PATH", venv.root/"bin"

    ENV["GI_SCANNER_DISABLE_CACHE"] = "true"
    if OS.mac? && MacOS.version == :ventura && DevelopmentTools.clang_build_version == 1500
      ENV.append "LDFLAGS", "-Wl,-ld_classic"
    end

    inreplace "giscanner/transformer.py", "/usr/share", "#{HOMEBREW_PREFIX}/share"
    inreplace "meson.build",
      "config.set_quoted('GOBJECT_INTROSPECTION_LIBDIR', join_paths(get_option('prefix'), get_option('libdir')))",
      "config.set_quoted('GOBJECT_INTROSPECTION_LIBDIR', '#{HOMEBREW_PREFIX}/lib')"

    system "meson", "setup", "build", "-Dpython=#{venv.root}/bin/python",
                                      "-Dextra_library_paths=#{HOMEBREW_PREFIX}/lib",
                                      *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"

    rewrite_shebang python_shebang_rewrite_info(venv.root/"bin/python"), *bin.children
  end

  test do
    (testpath/"main.c").write <<~C
      #include <girepository.h>

      int main (int argc, char *argv[]) {
        GIRepository *repo = g_irepository_get_default();
        g_assert_nonnull(repo);
        return 0;
      }
    C

    pkgconf_flags = shell_output("pkgconf --cflags --libs gobject-introspection-1.0").strip.split
    system ENV.cc, "main.c", "-o", "test", *pkgconf_flags
    system "./test"
  end
end

__END__
diff --git a/girepository/gitypelib.c b/girepository/gitypelib.c
index 29349da..5619cfb 100644
--- a/girepository/gitypelib.c
+++ b/girepository/gitypelib.c
@@ -2261,6 +2261,22 @@ load_one_shared_library (const char *shlib)
 {
   GSList *p;
   GModule *m;
+#ifdef EXTRA_LIBRARY_PATHS
+  static gsize extra_libs_initialized = 0;
+
+  if (g_once_init_enter (&extra_libs_initialized))
+    {
+      gchar **paths = g_strsplit(EXTRA_LIBRARY_PATHS, G_SEARCHPATH_SEPARATOR_S, 0);
+      gint i;
+      gsize initialized = 1;
+      for (i = g_strv_length(paths) - 1 ; i >= 0 ; i--)
+        {
+          g_irepository_prepend_library_path(paths[i]);
+	      }
+      g_strfreev(paths);
+      g_once_init_leave (&extra_libs_initialized, initialized);
+    }
+#endif
 
 #ifdef __APPLE__
   /* On macOS, @-prefixed shlib paths (@rpath, @executable_path, @loader_path)
diff --git a/meson.build b/meson.build
index 7b8bf1c..ea29ff5 100644
--- a/meson.build
+++ b/meson.build
@@ -222,6 +222,10 @@ if host_system in ['windows', 'cygwin']
   g_ir_scanner_env.prepend(var, gio_dep.get_variable('giomoduledir'))
 endif
 
+if get_option('extra_library_paths') != ''
+  config.set_quoted('EXTRA_LIBRARY_PATHS', get_option('extra_library_paths'))
+endif
+
 configure_file(
   configuration: config,
   output: 'config.h'
diff --git a/meson_options.txt b/meson_options.txt
index cbc63ed..e2e7577 100644
--- a/meson_options.txt
+++ b/meson_options.txt
@@ -49,3 +49,7 @@ option('gi_cross_pkgconfig_sysroot_path', type: 'string',
 option('tests', type: 'boolean', value: true,
   description: 'Build and run tests'
 )
+
+option('extra_library_paths', type: 'string',
+  description: 'A list of file paths, joined together using the searchpath separator character, that will be used to search for shared libraries'
+)
