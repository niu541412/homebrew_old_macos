class Deno < Formula
  desc "Secure runtime for JavaScript and TypeScript"
  homepage "https://deno.com/"
  url "https://github.com/denoland/deno/releases/download/v2.9.7/deno_src.tar.gz"
  sha256 "21069d2f4dd65b6832e3f5c373c24a43a8d35cb3d68d3841e15d0582bed39ea8"
  license "MIT"
  compatibility_version 1
  head "https://github.com/denoland/deno.git", branch: "main"

  bottle do
  end

  depends_on "cmake" => :build
  depends_on "lld" => :build
  depends_on "llvm" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "little-cms2"
  depends_on "sqlite" # needs `sqlite3_unlock_notify`

  uses_from_macos "python" => :build
  uses_from_macos "libffi" => :build, since: :catalina

  on_macos do
    depends_on xcode: ["10.1", :build] # v8 12.9+ uses linker flags introduced in xcode 15
  end

  on_linux do
    depends_on "glib" => :build
    depends_on "pcre2" => :build
    depends_on "zlib-ng-compat"
  end

  conflicts_with "dxpy", because: "both install `dx` binaries"

  def llvm = Formula["llvm"]

  patch :DATA
  def install
    ENV.llvm_clang if DevelopmentTools.clang_build_version <= 1000

    inreplace ".cargo/config.toml", 'MACOSX_DEPLOYMENT_TARGET = "12.0"',
                                    'MACOSX_DEPLOYMENT_TARGET = "10.13"'
    inreplace ".cargo/config.toml", "-Wl,-fixup_chains ", ""

    compat_source = buildpath/"aligned_alloc_compat.c"
    compat_object = buildpath/"aligned_alloc_compat.o"
    compat_source.write <<~C
      #include <stdlib.h>
      void *aligned_alloc(size_t alignment, size_t size) {
        void *pointer = NULL;
        return posix_memalign(&pointer, alignment, size) == 0 ? pointer : NULL;
      }
    C
    system ENV.cc, "-mmacosx-version-min=10.13", "-c", compat_source, "-o", compat_object
    rustflags = '  "link-args=-weak_framework Metal -weak_framework MetalPerformanceShaders ' \
                '-weak_framework QuartzCore -weak_framework CoreGraphics",'
    inreplace ".cargo/config.toml", rustflags,
              "#{rustflags}\n  \"-C\",\n  \"link-arg=#{compat_object}\","

    # Avoid vendored dependencies.
    ENV["CARGO_FEATURE_SYSTEM"] = "1" # libffi
    # ENV.prepend_path "LIBRARY_PATH", formula_opt_lib("libffi")
    ENV["LCMS2_LIB_DIR"] = formula_opt_lib("little-cms2")
    ENV["LIBSQLITE3_SYS_USE_PKG_CONFIG"] = "1"
    # env args for building a release build with our python3 and ninja
    ENV["PYTHON"] = which("python3")
    ENV["NINJA"] = which("ninja")
    # Build with llvm and link against system libc++ (no runtime dep)
    ENV["CLANG_BASE_PATH"] = llvm.prefix

    # use our clang version, and disable lld because the build assumes the lld
    # supports features from newer clang versions (>=20)
    ENV["GN_ARGS"] = "clang_version=#{llvm.version.major} use_lld=#{OS.linux?}"

    # Enable V8 without `__runtime_defaults`, which brings the `upgrade` subcommand and vendored zlib-ng
    features = ["deno_core/v8", "v8/v8"]
    system "cargo", "install", "--no-default-features", "-vv", *std_cargo_args(path: "cli", features:)
    bin.install_symlink bin/"deno" => "dx"
    generate_completions_from_executable(bin/"deno", "completions")
  end

  test do
    require "utils/linkage"

    system bin/"deno", "init", "my_project"
    cd "my_project" do
      system bin/"deno", "test"
    end

    (testpath/"hello.ts").write <<~TYPESCRIPT
      console.log("hello", "deno");
    TYPESCRIPT
    assert_match "hello deno", shell_output("#{bin}/deno run hello.ts")
    assert_match "Welcome to Deno!",
      shell_output("#{bin}/deno run https://deno.land/std@0.100.0/examples/welcome.ts")
    assert_match "hello deno", shell_output("#{bin}/dx -y cowsay hello deno")

    linked_libraries = [
      formula_opt_lib("sqlite")/shared_library("libsqlite3"),
    ]
    unless OS.mac? && MacOS.version >= :big_sur
      linked_libraries += [
        formula_opt_lib("libffi")/shared_library("libffi"),
      ]
    end
    linked_libraries.each do |library|
      assert Utils.binary_linked_to_library?(bin/"deno", library),
              "No linkage with #{library.basename}! Cargo is likely using a vendored version."
    end
  end
end

__END__
diff --git a/cli/tools/desktop.rs b/cli/tools/desktop.rs
index 1111111..2222222 100644
--- a/cli/tools/desktop.rs
+++ b/cli/tools/desktop.rs
@@ -1461,12 +1461,15 @@ async fn run_desktop_app(
   // with UNErrorCodeNotificationsNotAllowed before any user prompt.
   #[cfg(target_os = "macos")]
   let status = {
-    let mut child = disclaim_spawn::spawn(&cmd).with_context(|| {
-      format!(
-        "Failed to launch LAUFEY backend: {}",
-        laufey_backend.display()
-      )
-    })?;
+    let mut child = tokio::process::Command::from(cmd)
+      .kill_on_drop(true)
+      .spawn()
+      .with_context(|| {
+        format!(
+          "Failed to launch LAUFEY backend: {}",
+          laufey_backend.display()
+        )
+      })?;
     child
       .wait()
       .await
@@ -5651,7 +5654,7 @@ async fn create_icns(
 /// resolves "who's asking" to a process that has no notification bundle id.
 /// `responsibility_spawnattrs_setdisclaim` is the same SPI `open(1)` uses
 /// internally — it tells the kernel "this child decides its own permissions".
-#[cfg(target_os = "macos")]
+#[cfg(any())]
 mod disclaim_spawn {
   use std::ffi::CString;
   use std::ffi::OsString;
