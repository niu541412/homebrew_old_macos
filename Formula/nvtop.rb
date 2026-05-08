class Nvtop < Formula
  desc "Interactive GPU process monitor"
  homepage "https://github.com/Syllo/nvtop"
  url "https://github.com/Syllo/nvtop/archive/refs/tags/3.3.2.tar.gz"
  sha256 "48a295f3b3a917cc851d1aa8b185c09fde3a1b1e741fc57d7fa96b3671271630"
  license "GPL-3.0-or-later"

  bottle do
  end

  depends_on "cmake" => :build
  uses_from_macos "ncurses"

  on_linux do
    depends_on "libdrm"
    depends_on "systemd"
  end

  patch :DATA
  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # nvtop is a TUI application
    assert_match version.to_s, shell_output("#{bin}/nvtop --version")
  end
end

__END__
--- a/src/extract_gpuinfo_apple.m
+++ b/src/extract_gpuinfo_apple.m
@@ -28,6 +28,16 @@
 #include <IOKit/IOKitLib.h>
 #include <QuartzCore/QuartzCore.h>
 
+#ifndef kIOMainPortDefault
+    #define kIOMainPortDefault kIOMasterPortDefault
+#endif
+
+#ifndef MTLDeviceLocationBuiltIn
+    typedef NS_ENUM(NSUInteger, MTLDeviceLocation) {
+        MTLDeviceLocationBuiltIn = 0,
+    } API_AVAILABLE(macos(10.15));
+#endif
+
 struct gpu_info_apple {
   struct gpu_info base;
   id<MTLDevice> device;
