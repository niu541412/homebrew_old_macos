class OpenjdkAT8 < Formula
  desc "Development kit for the Java programming language"
  homepage "https://openjdk.org/"
  url "https://github.com/openjdk/jdk8u/archive/refs/tags/jdk8u502-ga.tar.gz"
  version "1.8.0-502"
  BUILD_NUMBER = "b07".freeze # Please update when a new GA release is available: https://wiki.openjdk.org/spaces/jdk8u/overview
  sha256 "c94a5d41b8c260c07672a4b4d9a7f0e27510d71a7d33d9e9625f5e8341832cbf"
  license "GPL-2.0-only"

  livecheck do
    url :stable
    regex(/^jdk(8u\d+)-ga$/i)
    strategy :git do |tags, regex|
      tags.filter_map { |tag| tag[regex, 1]&.gsub("8u", "1.8.0+") }
    end
  end

  bottle do
  end

  keg_only :versioned_formula

  deprecate! date: "2022-03-13", because: :unmaintained
  disable! date: "2030-12-31", because: :unmaintained

  depends_on "autoconf" => :build
  depends_on "pkgconf" => :build
  depends_on "freetype"
  depends_on "giflib"

  uses_from_macos "unzip" => :build
  uses_from_macos "zip" => :build
  uses_from_macos "cups" => :no_linkage

  on_macos do
    depends_on arch: :x86_64
  end

  on_monterey :or_newer do
    depends_on "gawk" => :build
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
  end

  # NOTE: Oracle doesn't serve JDK 7 downloads anymore, so we use Zulu JDK 7 for bootstrapping.
  # https://www.azul.com/downloads/?version=java-7-lts&package=jdk&show-old-builds=true#zulu
  resource "boot-jdk" do
    on_macos do
      url "https://cdn.azul.com/zulu/bin/zulu7.56.0.11-ca-jdk7.0.352-macosx_x64.tar.gz"
      sha256 "31909aa6233289f8f1d015586825587e95658ef59b632665e1e49fc33a2cdf06"
    end
    on_linux do
      on_arm do
        url "https://cdn.azul.com/zulu/bin/zulu8.82.0.21-ca-jdk8.0.432-linux_aarch64.tar.gz"
        sha256 "b400f65b63243e41851f20b64374def6ae687de8d15bfb37ef876c2d77548bf5"
      end
      on_intel do
        url "https://cdn.azul.com/zulu/bin/zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz"
        sha256 "8a7387c1ed151474301b6553c6046f865dc6c1e1890bcf106acc2780c55727c8"
      end
    end
  end

  # NOTE: macOS Sonoma+ SDK removed the JavaNativeFoundation headers required by JDK 8's Serviceability Agent (SA)
  # and AppleScript engine. We provide a header-only shim placed in a framework-like layout and inject the framework
  # search path into saproc.make so the SA debugger backend can find the headers while still linking against the
  # system framework.
  resource "JavaNativeFoundation" do
    on_sonoma :or_newer do
      url "https://github.com/apple/openjdk/archive/refs/tags/iTunesOpenJDK-1014.0.2.12.1.tar.gz"
      sha256 "e8556a73ea36c75953078dfc1bafc9960e64593bc01e733bc772d2e6b519fd4a"
    end
  end

  # Fix `clang++ -std=gnu++11` compile failure issue on macOS.
  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/04ad4a17332e391cd359271965d4c6dac87a7eb2/java/openjdk8/files/0001-8181503-Can-t-compile-hotspot-with-c-11.patch"
    sha256 "a02e0ea7c70390796e46b8b6565f986fedc17a08aa039ee3306438a39a60538a"
    type :unofficial
  end
  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/04ad4a17332e391cd359271965d4c6dac87a7eb2/java/openjdk8/files/0006-Disable-C-11-warnings.patch"
    sha256 "127d9508b72005e849a6ada6adf04bd49a236731d769810e67793bdf2aa722fe"
    type :unofficial
  end
  patch :p0, :DATA

  def install
    _, _, update = version.to_s.rpartition("-")

    boot_jdk = buildpath/"boot-jdk"
    resource("boot-jdk").stage boot_jdk

    java_options = ENV.delete("_JAVA_OPTIONS")

    # Work around clashing -I/usr/include and -isystem headers, as superenv already handles this detail for us.
    inreplace "common/autoconf/flags.m4", '-isysroot \"$SYSROOT\"', ""
    inreplace "common/autoconf/toolchain.m4",
              '-isysroot \"$SDKPATH\" -iframework\"$SDKPATH/System/Library/Frameworks\"', ""

    if OS.mac?
      inreplace "common/autoconf/flags.m4", "MACOSX_VERSION_MIN=11.00.00", "MACOSX_VERSION_MIN=#{MacOS.version}.00"
      inreplace "common/autoconf/generated-configure.sh", "MACOSX_VERSION_MIN=11.00.00", "MACOSX_VERSION_MIN=#{MacOS.version}.00"
      # Fix macOS version detection. After 10.10 this was changed to a 6 digit number,
      # but this Makefile was written in the era of 4 digit numbers.
      inreplace "hotspot/make/bsd/makefiles/gcc.make" do |s|
        s.gsub! "$(subst .,,$(MACOSX_VERSION_MIN))", ENV["HOMEBREW_MACOS_VERSION_NUMERIC"]
        s.gsub! "MACOSX_VERSION_MIN=11.00.00", "MACOSX_VERSION_MIN=#{MacOS.version}"
      end

      if MacOS.version >= :sonoma
        resource("JavaNativeFoundation").stage do
          # Create a framework-like header shim that the saproc.make -F flag will find
          # when searching for JavaNativeFoundation.framework.
          jnf_shim = buildpath/"JavaNativeFoundation.framework"
          jnf_headers = jnf_shim/"Headers"
          jnf_headers.mkpath

          # Copy the headers from Apple's openjdk archive.
          Dir["apple/JavaNativeFoundation/JavaNativeFoundation/*.h"].each do |header|
            cp header, jnf_headers
          end
        end

        # Inject -F flag into saproc.make's SA_SYSROOT_FLAGS so the SA debugger backend compilation
        # finds our header shim before falling through to the (headerless) system framework.
        inreplace "hotspot/make/bsd/makefiles/saproc.make", "SA_SYSROOT_FLAGS=", "SA_SYSROOT_FLAGS=-F#{buildpath} "
      end
    else
      # Fix linker errors on brewed GCC.
      inreplace "common/autoconf/flags.m4", "-Xlinker -O1", ""
      inreplace "hotspot/make/linux/makefiles/gcc.make", "-Xlinker -O1", ""
    end

    args = %W[
      --with-boot-jdk-jvmargs=#{java_options}
      --with-boot-jdk=#{boot_jdk}
      --with-debug-level=release
      --with-conf-name=release
      --with-jvm-variants=server
      --with-milestone=fcs
      --with-native-debug-symbols=none
      --with-update-version=#{update}
      --with-build-number=#{BUILD_NUMBER}
      --with-vendor-bug-url=https://github.com/Homebrew/homebrew-core/issues
      --with-vendor-name=Homebrew
      --with-vendor-url=https://github.com/Homebrew/homebrew-core/issues
      --with-vendor-vm-bug-url=https://github.com/Homebrew/homebrew-core/issues
      --with-giflib=system
    ]

    ldflags = ["-Wl,-rpath,#{loader_path.gsub("$", "\\$$$$")}/server"]

    if OS.mac?
      args += %w[
        --with-toolchain-type=clang
        --with-zlib=system
      ]

      extra_cflags = []
      extra_cxxflags = []

      if MacOS.version >= :sonoma
        # The JDK build system's jdk/makefiles also compile AppleScript sources that import JavaNativeFoundation.
        # Adding -F here ensures those compilation units find our header shim.
        extra_cflags << "-F#{buildpath}"
        extra_cxxflags << "-F#{buildpath}"
      end

      # Work around for Xcode 16 bug: https://bugs.openjdk.org/browse/JDK-8340341
      extra_cflags << "-mllvm -enable-constraint-elimination=0" if DevelopmentTools.clang_build_version == 1600

      args << "--with-extra-cflags=#{extra_cflags.join(" ")}" unless extra_cflags.empty?
      args << "--with-extra-cxxflags=#{extra_cxxflags.join(" ")}" unless extra_cxxflags.empty?
    else
      args += %W[
        --with-toolchain-type=gcc
        --x-includes=#{HOMEBREW_PREFIX}/include
        --x-libraries=#{HOMEBREW_PREFIX}/lib
        --with-cups=#{HOMEBREW_PREFIX}
        --with-fontconfig=#{HOMEBREW_PREFIX}
        --with-stdc++lib=dynamic
      ]
      arch = Hardware::CPU.arm? ? "aarch64" : "amd64"
      extra_rpath = rpath(source: libexec/"lib"/arch, target: libexec/"jre/lib"/arch)
      ldflags << "-Wl,-rpath,#{extra_rpath.gsub("$", "\\$$$$")}"
    end

    args << "--with-extra-ldflags=#{ldflags.join(" ")}"

    system "bash", "common/autoconf/autogen.sh"
    # On High Sierra, superenv otherwise removes the JDK build's explicit
    # -isysroot without adding one back. That mixes /usr/include headers with
    # frameworks from the 10.14 SDK and breaks Availability macro expansion.
    ENV["SDKROOT"] = MacOS.sdk_path if OS.mac? && MacOS.version <= :high_sierra
    system "bash", "configure", *args

    ENV["MAKEFLAGS"] = "JOBS=#{ENV.make_jobs}"
    system "make", "bootcycle-images", "CONF=release"

    cd "build/release/images" do
      if OS.mac?
        libexec.install Dir["j2sdk-bundle/*"].first => "openjdk.jdk"
        jdk = libexec/"openjdk.jdk/Contents/Home"
      else
        libexec.install Dir["j2sdk-image/*"]
        jdk = libexec
      end

      bin.install_symlink Dir[jdk/"bin/*"]
      include.install_symlink Dir[jdk/"include/*.h"]
      include.install_symlink Dir[jdk/"include/*/*.h"]
      man1.install_symlink Dir[jdk/"man/man1/*"]
    end
  end

  def caveats
    on_macos do
      <<~EOS
        For the system Java wrappers to find this JDK, symlink it with
          sudo ln -sfn #{opt_libexec}/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-8.jdk
      EOS
    end
  end

  test do
    (testpath/"HelloWorld.java").write <<~JAVA
      class HelloWorld {
        public static void main(String[] args) {
          System.out.println("Hello, world!");
        }
      }
    JAVA

    system bin/"javac", "HelloWorld.java"

    assert_match "Hello, world!", shell_output("#{bin}/java HelloWorld")
  end
end

__END__
--- jdk/src/share/native/com/sun/java/util/jar/pack/jni.cpp
+++ jdk/src/share/native/com/sun/java/util/jar/pack/jni.cpp
@@ -292,7 +292,7 @@

   if (uPtr->aborting()) {
     THROW_IOE(uPtr->get_abort_message());
-    return false;
+    return 0;
   }

   // We have fetched all the files.
--- jdk/src/macosx/native/com/sun/media/sound/PLATFORM_API_MacOSX_Ports.cpp
+++ jdk/src/macosx/native/com/sun/media/sound/PLATFORM_API_MacOSX_Ports.cpp
@@ -609,7 +609,7 @@
                 // get the channel name
                 char *channelName;
                 CFStringRef cfname = NULL;
-                const AudioObjectPropertyAddress address = {kAudioObjectPropertyElementName, port->scope, ch};
+                const AudioObjectPropertyAddress address = {kAudioObjectPropertyElementName, port->scope, (unsigned)ch};
                 UInt32 size = sizeof(cfname);
                 OSStatus err = AudioObjectGetPropertyData(mixer->deviceID, &address, 0, NULL, &size, &cfname);
                 if (err == noErr) {
--- jdk/src/macosx/native/sun/awt/CDesktopPeer.m
+++ jdk/src/macosx/native/sun/awt/CDesktopPeer.m
@@ -60,8 +60,9 @@
         return -1;
     }
 
-    // Prepare NSOpenConfig object
     NSArray<NSURL *> *urls = @[urlToOpen];
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
+    // Use the completion-handler API when building with the 10.15+ SDK.
     NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
     configuration.activates = YES; // To bring app to foreground
     configuration.promptsUserIfNeeded = YES; // To allow macOS desktop prompts
@@ -82,6 +83,18 @@
     }];
 
     dispatch_semaphore_wait(semaphore, timeout);
+#else
+    // NSWorkspaceOpenConfiguration was introduced in the 10.15 SDK.
+    // The older API provides equivalent application selection on 10.14.
+    NSString *bundleIdentifier = [[NSBundle bundleWithURL:appURI] bundleIdentifier];
+    BOOL opened = [[NSWorkspace sharedWorkspace]
+            openURLs:urls
+            withAppBundleIdentifier:bundleIdentifier
+            options:NSWorkspaceLaunchDefault
+            additionalEventParamDescriptor:nil
+            launchIdentifiers:nil];
+    status = opened ? noErr : -1;
+#endif
 
 JNF_COCOA_EXIT(env);
     return status;
@@ -109,8 +122,9 @@
     NSURL *appURI = [workspace URLForApplicationToOpenURL:urlToOpen];
     NSURL *defaultTerminalApp = [workspace URLForApplicationToOpenURL:[NSURL URLWithString:@"file:///bin/sh"]];
 
-    // Prepare NSOpenConfig object
     NSArray<NSURL *> *urls = @[urlToOpen];
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
+    // Use the completion-handler API when building with the 10.15+ SDK.
     NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
     configuration.activates = YES; // To bring app to foreground
     configuration.promptsUserIfNeeded = YES;  // To allow macOS desktop prompts
@@ -125,7 +139,9 @@
         }
         // Additionally set forPrinting=TRUE for print
         if (action == sun_lwawt_macosx_CDesktopPeer_PRINT) {
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
             configuration.forPrinting = YES;
+#endif
         }
     } else if (action == sun_lwawt_macosx_CDesktopPeer_EDIT) {
         if (appURI == nil
@@ -156,8 +172,21 @@
     }];
 
     dispatch_semaphore_wait(semaphore, timeout);
+#else
+    NSWorkspaceLaunchOptions options = NSWorkspaceLaunchDefault;
+    if (action == sun_lwawt_macosx_CDesktopPeer_PRINT) {
+        options |= NSWorkspaceLaunchAndPrint;
+    }
+    NSString *bundleIdentifier = [[NSBundle bundleWithURL:appURI] bundleIdentifier];
+    BOOL opened = [workspace
+            openURLs:urls
+            withAppBundleIdentifier:bundleIdentifier
+            options:options
+            additionalEventParamDescriptor:nil
+            launchIdentifiers:nil];
+    status = opened ? noErr : -1;
+#endif
 
 JNF_COCOA_EXIT(env);
     return status;
 }
-
