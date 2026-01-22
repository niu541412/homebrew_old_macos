class OpenjdkAT17 < Formula
  desc "Development kit for the Java programming language"
  homepage "https://openjdk.org/"
  url "https://github.com/openjdk/jdk17u/archive/refs/tags/jdk-17.0.18-ga.tar.gz"
  sha256 "15c4fbd1d69254d362c24e82f4e9ab7ed69c8ebc7daf996500210698c944230a"
  license "GPL-2.0-only" => { with: "Classpath-exception-2.0" }

  livecheck do
    url :stable
    regex(/^jdk[._-]v?(17(?:\.\d+)*)-ga$/i)
  end

  bottle do
  end

  keg_only :versioned_formula

  depends_on "autoconf" => :build
  depends_on "pkgconf" => :build
  depends_on xcode: :build # for metal

  depends_on "freetype"
  depends_on "giflib"
  depends_on "harfbuzz"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "little-cms2"

  uses_from_macos "cups"
  uses_from_macos "unzip"
  uses_from_macos "zip"
  uses_from_macos "zlib"

  on_linux do
    depends_on "alsa-lib"
    depends_on "fontconfig"
    depends_on "libx11"
    depends_on "libxext"
    depends_on "libxi"
    depends_on "libxrandr"
    depends_on "libxrender"
    depends_on "libxt"
    depends_on "libxtst"
  end

  # From https://jdk.java.net/archive/
  resource "boot-jdk" do
    on_macos do
      on_arm do
        url "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_macos-aarch64_bin.tar.gz"
        sha256 "602d7de72526368bb3f80d95c4427696ea639d2e0cc40455f53ff0bbb18c27c8"
      end
      on_intel do
        url "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_macos-x64_bin.tar.gz"
        sha256 "b85c4aaf7b141825ad3a0ea34b965e45c15d5963677e9b27235aa05f65c6df06"
      end
    end
    on_linux do
      on_arm do
        url "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_linux-aarch64_bin.tar.gz"
        sha256 "13bfd976acf8803f862e82c7113fb0e9311ca5458b1decaef8a09ffd91119fa4"
      end
      on_intel do
        url "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_linux-x64_bin.tar.gz"
        sha256 "0022753d0cceecacdd3a795dd4cea2bd7ffdf9dc06e22ffd1be98411742fbb44"
      end
    end
  end

  patch :DATA
  def install
    inreplace "make/autoconf/flags.m4", "MACOSX_VERSION_MIN=11.00.00", "MACOSX_VERSION_MIN=#{MacOS.version}.00"

    boot_jdk = buildpath/"boot-jdk"
    resource("boot-jdk").stage boot_jdk
    boot_jdk /= "Contents/Home" if OS.mac?
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

    ldflags = ["-Wl,-rpath,#{loader_path.gsub("$", "\\$$")}/server"]
    args += if OS.mac?
      ldflags << "-headerpad_max_install_names #{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"

      # Allow unbundling `freetype` on macOS
      inreplace "make/autoconf/lib-freetype.m4", '= "xmacosx"', '= ""'

      %W[
        --enable-dtrace
        --with-freetype-include=#{Formula["freetype"].opt_include}
        --with-freetype-lib=#{Formula["freetype"].opt_lib}
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

    if DevelopmentTools.clang_build_version == 1600 && MacOS::Xcode.version < "16.2"
      args << "--with-extra-cflags=-mllvm -enable-constraint-elimination=0"
    end

    system "bash", "configure", *args

    inreplace "build/macosx-x86_64-server-release/spec.gmk" do |s|
       s.gsub! /^(PNG_CFLAGS:=.*) -I\/usr\/include/, "\\1"
    end

    ENV["MAKEFLAGS"] = "JOBS=#{ENV.make_jobs}"
    system "make", "images"

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
          sudo ln -sfn #{opt_libexec}/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
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

--- a/src/java.desktop/macosx/native/libawt_lwawt/awt/CDesktopPeer.m	
+++ b/src/java.desktop/macosx/native/libawt_lwawt/awt/CDesktopPeer.m	
@@ -61,6 +61,7 @@
 
     // Prepare NSOpenConfig object
     NSArray<NSURL *> *urls = @[urlToOpen];
+    #if MAC_OS_X_VERSION_MIN_REQUIRED >= 101500
     NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
     configuration.activates = YES; // To bring app to foreground
     configuration.promptsUserIfNeeded = YES; // To allow macOS desktop prompts
@@ -81,6 +82,18 @@
     }];
 
     dispatch_semaphore_wait(semaphore, timeout);
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
 
 JNI_COCOA_EXIT(env);
     return status;
@@ -110,9 +123,13 @@
 
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
@@ -124,7 +141,11 @@
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
@@ -139,6 +160,7 @@
         }
     }
 
+    #if MAC_OS_X_VERSION_MIN_REQUIRED >= 101500
     // dispatch semaphores used to wait for the completion handler to update and return status
     dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
     dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)); // 1 second timeout
@@ -155,6 +177,17 @@
     }];
 
     dispatch_semaphore_wait(semaphore, timeout);
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
 
 JNI_COCOA_EXIT(env);
     return status;
