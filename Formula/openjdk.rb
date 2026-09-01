class Openjdk < Formula
  desc "Development kit for the Java programming language"
  homepage "https://openjdk.org/"
  url "https://github.com/openjdk/jdk26u/archive/refs/tags/jdk-26.0.2.1-ga.tar.gz"
  sha256 "91dd5ddd93e156f00a12c28d9b74b5ee1704e9f12d323d412d158b12e91d56d0"
  license "GPL-2.0-only" => { with: "Classpath-exception-2.0" }
  compatibility_version 1

  livecheck do
    url :stable
    regex(/^jdk[._-]v?(\d+(?:\.\d+)*)-ga$/i)
  end

  bottle do
  end

  keg_only :shadowed_by_macos

  depends_on "autoconf" => :build
  depends_on "pkgconf" => :build
  depends_on "freetype"
  depends_on "giflib"
  depends_on "harfbuzz"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "little-cms2"

  uses_from_macos "unzip" => :build
  uses_from_macos "zip" => :build
  uses_from_macos "cups" => :no_linkage

  on_macos do
    depends_on xcode: :build # for metal
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100
  end

  on_linux do
    depends_on "libxt" => :build
    depends_on "alsa-lib"
    depends_on "fontconfig" => :no_linkage
    depends_on "libx11"
    depends_on "libxext"
    depends_on "libxi"
    depends_on "libxrandr" => :no_linkage
    depends_on "libxrender"
    depends_on "libxtst"
    depends_on "zlib-ng-compat"
  end

  # From https://jdk.java.net/archive/
  resource "boot-jdk" do
    on_macos do
      on_arm do
        url "https://download.java.net/java/GA/jdk26.0.1/458fda22e4c54d5ba572ab8d2b22eb83/8/GPL/openjdk-26.0.1_macos-aarch64_bin.tar.gz"
        sha256 "b2d57405194a312ed4ec6ec08e83b314d3fd2e425e895d704ec5ef8ea6059e17"
      end
      on_intel do
        url "https://github.com/niu541412/homebrew_old_macos/releases/download/openjdk/openjdk@25--25.0.4.1.high_sierra.bottle.tar.gz"
        sha256 "e6cb17ecd7c95d203d5f02a5d05f235863d0b392804f6c6e2e7ce95213387423"
      end
    end
    on_linux do
      on_arm do
        url "https://download.java.net/java/GA/jdk26.0.1/458fda22e4c54d5ba572ab8d2b22eb83/8/GPL/openjdk-26.0.1_linux-aarch64_bin.tar.gz"
        sha256 "12a3649b2f4a0c9f6491d220bdd04b4fff07cae502b435aaff46eac0e36f4df1"
      end
      on_intel do
        url "https://download.java.net/java/GA/jdk26.0.1/458fda22e4c54d5ba572ab8d2b22eb83/8/GPL/openjdk-26.0.1_linux-x64_bin.tar.gz"
        sha256 "2f2802d57b5fc414f1ddf6648ba12cc9a6454cf67b32ac95407c018f2e6ab0b0"
      end
    end
  end

  patch :DATA
  def install
    # ENV.O3
    inreplace "make/autoconf/flags.m4", "MACOSX_VERSION_MIN=11.00.00", "MACOSX_VERSION_MIN=#{MacOS.version}.00"

    boot_jdk = buildpath/"boot-jdk"
    resource("boot-jdk").stage boot_jdk
    boot_jdk = Dir[boot_jdk/"**/Contents/Home"].first if OS.mac?
    java_options = ENV.delete("_JAVA_OPTIONS")

    args = %W[
      --disable-warnings-as-errors
      --with-boot-jdk-jvmargs=#{java_options}
      --with-boot-jdk=#{boot_jdk}
      --with-debug-level=release
      --with-jvm-variants=server
      --with-native-debug-symbols=none
      --with-vendor-bug-url=https://github.com/Homebrew/homebrew-core/issues
      --with-vendor-name=Homebrew
      --with-vendor-url=https://github.com/Homebrew/homebrew-core/issues
      --with-vendor-version-string=Homebrew
      --with-vendor-vm-bug-url=https://github.com/Homebrew/homebrew-core/issues
      --with-version-build=#{revision}
      --without-version-opt
      --without-version-pre
      --with-freetype=system
      --with-giflib=system
      --with-harfbuzz=system
      --with-lcms=system
      --with-libjpeg=system
      --with-libpng=system
      --with-zlib=system
    ]

    ldflags = %W[
      -Wl,-rpath,#{loader_path.gsub("$", "\\$$")}
      -Wl,-rpath,#{loader_path.gsub("$", "\\$$")}/server
    ]
    args += if OS.mac?
      ldflags << "-headerpad_max_install_names #{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"

      # Allow unbundling `freetype` on macOS
      inreplace "make/autoconf/lib-freetype.m4", '= "xmacosx"', '= ""'

      %W[
        --enable-dtrace
        --with-freetype-include=#{formula_opt_include("freetype")}
        --with-freetype-lib=#{formula_opt_lib("freetype")}
        --with-sysroot=#{MacOS.sdk_path}
      ]
    else
      %W[
        --with-x=#{HOMEBREW_PREFIX}
        --with-cups=#{HOMEBREW_PREFIX}
        --with-fontconfig=#{HOMEBREW_PREFIX}
        --with-stdc++lib=dynamic
      ]
    end
    args << "--with-extra-ldflags=#{ldflags.join(" ")}"

    system "bash", "configure", *args

    ENV["MAKEFLAGS"] = "JOBS=#{ENV.make_jobs}"
    5.times do |attempt|
      system "make", "images"
      break
    rescue BuildError
      raise if attempt == 4

      ENV["MAKEFLAGS"] = "JOBS=1"
      opoo "parallel make images failed; retrying serial incremental build (#{attempt + 2}/5)"
    end

    jdk = libexec
    if OS.mac?
      libexec.install Dir["build/*/images/jdk-bundle/*"].first => "openjdk.jdk"
      jdk /= "openjdk.jdk/Contents/Home"
    else
      libexec.install Dir["build/linux-*-server-release/images/jdk/*"]
    end

    bin.install_symlink Dir[jdk/"bin/*"]
    include.install_symlink Dir[jdk/"include/*.h"]
    include.install_symlink Dir[jdk/"include"/OS.kernel_name.downcase/"*.h"]
    man1.install_symlink Dir[jdk/"man/man1/*"]
  end

  def caveats
    on_macos do
      <<~EOS
        For the system Java wrappers to find this JDK, symlink it with
          sudo ln -sfn #{opt_libexec}/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
      EOS
    end
  end

  test do
    (testpath/"HelloWorld.java").write <<~JAVA
      class HelloWorld {
        public static void main(String args[]) {
          System.out.println("Hello, world!");
        }
      }
    JAVA

    system bin/"javac", "HelloWorld.java"

    assert_match "Hello, world!", shell_output("#{bin}/java HelloWorld")
  end
end

__END__
--- a/src/java.desktop/macosx/native/libawt_lwawt/awt/CGraphicsDevice.m
+++ b/src/java.desktop/macosx/native/libawt_lwawt/awt/CGraphicsDevice.m
@@ -28,6 +28,10 @@
 #include "GeomUtilities.h"
 #include "JNIUtilities.h"
 
+#ifndef NSBundleExecutableArchitectureARM64
+#define NSBundleExecutableArchitectureARM64 0x0100000c
+#endif
+
 /**
  * Some default values for invalid CoreGraphics display ID.
  */

--- a/src/hotspot/os/bsd/memMapPrinter_macosx.cpp
+++ b/src/hotspot/os/bsd/memMapPrinter_macosx.cpp
@@ -25,6 +25,14 @@
 
 #if defined(__APPLE__)
 
+#ifndef VM_MEMORY_MALLOC_MEDIUM
+#define VM_MEMORY_MALLOC_MEDIUM 12
+#endif
+
+#ifndef VM_MEMORY_MALLOC_PROB_GUARD
+#define VM_MEMORY_MALLOC_PROB_GUARD 13
+#endif
+
 #include "nmt/memMapPrinter.hpp"
 #include "runtime/os.hpp"
 #include "utilities/align.hpp"

--- a/src/java.desktop/macosx/native/libawt_lwawt/awt/CDesktopPeer.m	
+++ b/src/java.desktop/macosx/native/libawt_lwawt/awt/CDesktopPeer.m	
@@ -61,6 +61,7 @@
 
     // Prepare NSOpenConfig object
     NSArray<NSURL *> *urls = @[urlToOpen];
+    #if MAC_OS_X_VERSION_MIN_REQUIRED >= 101500
     NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
     configuration.activates = YES; // To bring app to foreground
     configuration.promptsUserIfNeeded = YES; // To allow macOS desktop prompts
@@ -85,6 +86,19 @@
     dispatch_semaphore_wait(semaphore, timeout);
     dispatch_release(semaphore);
 
+    #else
+    NSError *error = nil;
+    NSWorkspaceLaunchOptions options = NSWorkspaceLaunchDefault;
+    [[NSWorkspace sharedWorkspace] openURLs:urls
+                                    withApplication:appURI
+                                    options:options
+                                    configuration:@{}
+                                    error:&error];
+    if (error) {
+        status = (OSStatus)error.code;
+    }
+    #endif
+
 JNI_COCOA_EXIT(env);
     return status;
 }
@@ -113,9 +127,13 @@
 
     // Prepare NSOpenConfig object
     NSArray<NSURL *> *urls = @[urlToOpen];
+    #if MAC_OS_X_VERSION_MIN_REQUIRED >= 101500
     NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
     configuration.activates = YES; // To bring app to foreground
     configuration.promptsUserIfNeeded = YES;  // To allow macOS desktop prompts
+    #else
+    NSWorkspaceLaunchOptions options = NSWorkspaceLaunchDefault;
+    #endif
 
     // pre-checks for open/print/edit before calling openURLs API
     if (action == sun_lwawt_macosx_CDesktopPeer_OPEN
@@ -128,7 +146,11 @@
         }
         // Additionally set forPrinting=TRUE for print
         if (action == sun_lwawt_macosx_CDesktopPeer_PRINT) {
+            #if MAC_OS_X_VERSION_MIN_REQUIRED >= 101500
             configuration.forPrinting = YES;
+            #else
+            options |= NSWorkspaceLaunchAndPrint;
+            #endif
         }
     } else if (action == sun_lwawt_macosx_CDesktopPeer_EDIT) {
         if (appURI == nil
@@ -144,6 +166,7 @@
         }
     }
 
+    #if MAC_OS_X_VERSION_MIN_REQUIRED >= 101500
     // dispatch semaphores used to wait for the completion handler to update and return status
     dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
     dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)); // 1 second timeout
@@ -164,6 +187,18 @@ JNI_COCOA_ENTER(env);
     dispatch_semaphore_wait(semaphore, timeout);
     dispatch_release(semaphore);
 
+    #else
+    NSError *error = nil;
+    [[NSWorkspace sharedWorkspace] openURLs:urls
+                                    withApplication:appURI
+                                    options:options
+                                    configuration:@{}
+                                    error:&error];
+    if (error) {
+        status = (OSStatus)error.code;
+    }
+    #endif
+
     [urlToOpen release];
 JNI_COCOA_EXIT(env);
     return status;

--- a/src/hotspot/share/gc/g1/g1OopClosures.inline.hpp
+++ b/src/hotspot/share/gc/g1/g1OopClosures.inline.hpp
@@ -285,7 +285,7 @@ template <class T> void G1RebuildRemSetC
   G1HeapRegionRemSet* rem_set = to->rem_set();
   if (rem_set->is_tracked()) {
     if (to->is_young()) {
-      G1BarrierSet::g1_barrier_set()->write_ref_field_post(p);
+      G1BarrierSet::g1_barrier_set()->write_ref_field_post<AS_NORMAL>(p);
     } else {
       G1HeapRegion* from = _g1h->heap_region_containing(p);
 
--- a/make/autoconf/flags-ldflags.m4
+++ b/make/autoconf/flags-ldflags.m4
@@ -71,7 +71,7 @@ AC_DEFUN([FLAGS_SETUP_LDFLAGS_HELPER],
     BASIC_LDFLAGS_JVM_ONLY="-mno-omit-leaf-frame-pointer -mstack-alignment=16 \
         -fPIC"
 
-    LDFLAGS_LTO="-flto=auto -fuse-linker-plugin -fno-strict-aliasing"
+    LDFLAGS_LTO="-flto -fuse-linker-plugin -fno-strict-aliasing"
     LDFLAGS_CXX_PARTIAL_LINKING="$MACHINE_FLAG -r"
 
     if test "x$OPENJDK_TARGET_OS" = xlinux; then
@@ -108,7 +108,7 @@ AC_DEFUN([FLAGS_SETUP_LDFLAGS_HELPER],
     fi
     # FIXME: We should really generalize SetSharedLibraryOrigin instead.
     OS_LDFLAGS_JVM_ONLY="-Wl,-rpath,@loader_path/. -Wl,-rpath,@loader_path/.."
-    OS_LDFLAGS="-mmacosx-version-min=$MACOSX_VERSION_MIN -Wl,-reproducible"
+    OS_LDFLAGS="-mmacosx-version-min=$MACOSX_VERSION_MIN"
   fi
 
   # Setup debug level-dependent LDFLAGS
--- a/src/hotspot/share/runtime/atomic.hpp
+++ b/src/hotspot/share/runtime/atomic.hpp
@@ -162,7 +162,6 @@ class AtomicImpl {
     Translated
   };
 
-#if defined(__GNUC__) && !defined(__clang__)
   // Workaround for gcc bug. Make category() public, else we get this error
   //   error: 'static constexpr AtomicImpl::Category AtomicImpl::category()
   //     [with T = unsigned int]' is private within this context
@@ -170,7 +169,6 @@ class AtomicImpl {
   // class a couple lines below, in this same class!
   // https://gcc.gnu.org/bugzilla/show_bug.cgi?id=122098
 public:
-#endif
   // Selection of Atomic<T> category, based on T.
   template<typename T>
   static constexpr Category category();
