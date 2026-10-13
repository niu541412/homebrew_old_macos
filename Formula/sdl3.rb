class Sdl3 < Formula
  desc "Low-level access to audio, keyboard, mouse, joystick, and graphics"
  homepage "https://libsdl.org/"
  url "https://github.com/libsdl-org/SDL/releases/download/release-3.4.18/SDL3-3.4.18.tar.gz"
  sha256 "9c75cf16330322c217dedd2e0609f1124f1b54b8633e763467b4684d0f4334a3"
  license "Zlib"
  compatibility_version 1
  head "https://github.com/libsdl-org/SDL.git", branch: "main"

  livecheck do
    url :stable
    regex(/release[._-](\d+(?:\.\d+)+)/i)
    strategy :github_latest
  end

  bottle do
  end

  depends_on "cmake" => :build
  depends_on "pkgconf" => :build

  on_linux do
    # Features are built into library if dependency is found at build-time.
    # These are then enabled at runtime if library can be dynamically loaded,
    # so we can provide extra features via build-only dependencies. This includes
    # PipeWire and Wayland used on modern Linux which have large dependency trees.
    depends_on "libxkbcommon" => :build
    depends_on "mesa" => :build
    depends_on "pipewire" => :build
    depends_on "wayland" => :build

    # Runtime dependencies are for older PulseAudio and X11. These are used if
    # running a Linux container on macOS and should have higher compatibility
    depends_on "libx11" => :no_linkage
    depends_on "libxcursor" => :no_linkage
    depends_on "libxext" => :no_linkage
    depends_on "libxfixes" => :no_linkage
    depends_on "libxi" => :no_linkage
    depends_on "libxrandr" => :no_linkage
    depends_on "libxscrnsaver" => :no_linkage
    depends_on "pulseaudio" => :no_linkage
  end

  deny_network_access!

  patch :DATA
  def install
    inreplace "CMakeLists.txt", "sdl_link_dependency(uniformtypeidentifiers", "#sdl_link_dependency(uniformtypeidentifiers"
    inreplace "cmake/sdl3.pc.in", "@SDL_PKGCONFIG_PREFIX@", HOMEBREW_PREFIX

    args = %w[
      -DSDL_TESTS=OFF
      -DSDL_X11_XTEST=OFF
      -DSDL_CAMERA=OFF
      -DSDL_GPU=OFF
      -DHAVE_FRAMEWORK_GAMECONTROLLER=OFF
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.c").write <<~CPP
      #include <SDL3/SDL.h>
      int main() {
        if (SDL_Init(SDL_INIT_VIDEO) != 1) {
          return 1;
        }
        SDL_Quit();
        return 0;
      }
    CPP
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lSDL3", "-o", "test"
    ENV["SDL_VIDEODRIVER"] = "dummy"
    system "./test"
  end
end

__END__
--- a/src/audio/coreaudio/SDL_coreaudio.m
+++ b/src/audio/coreaudio/SDL_coreaudio.m
@@ -22,6 +22,14 @@

 #ifdef SDL_AUDIO_DRIVER_COREAUDIO

+#ifndef kAudioChannelLayoutTag_WAVE_6_1
+#define kAudioChannelLayoutTag_WAVE_6_1 ((188U << 16) | 7)                     ///< 7 channels, L R C LFE Cs Ls Rs
+#endif
+
+#ifndef kAudioChannelLayoutTag_WAVE_7_1
+#define kAudioChannelLayoutTag_WAVE_7_1 ((188U << 16) | 8)                   ///< 8 channels, L R C LFE Rls Rrs Ls Rs
+#endif
+
 #include "../SDL_sysaudio.h"
 #include "SDL_coreaudio.h"
 #include "../../thread/SDL_systhread.h"
--- a/src/video/cocoa/SDL_cocoaclipboard.m
+++ b/src/video/cocoa/SDL_cocoaclipboard.m
@@ -26,7 +26,12 @@
 #include "../../events/SDL_events_c.h"
 #include "../../events/SDL_clipboardevents_c.h"
 
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
 #include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
+#define SDL_HAVE_UNIFORMTYPEIDENTIFIERS 1
+#else
+#include <CoreServices/CoreServices.h>
+#endif
 
 @interface Cocoa_PasteboardDataProvider : NSObject<NSPasteboardItemDataProvider>
 {
@@ -85,6 +90,7 @@ static char **GetMimeTypes(int *pnformats)
         for (NSPasteboardItem *item in items) {
             NSArray<NSString *> *types = [item types];
             for (NSString *type in types) {
+#ifdef SDL_HAVE_UNIFORMTYPEIDENTIFIERS
                 if (@available(macOS 11.0, *)) {
                     UTType *uttype = [UTType typeWithIdentifier:type];
                     NSString *mime_type = [uttype preferredMIMEType];
@@ -95,6 +101,7 @@ static char **GetMimeTypes(int *pnformats)
                         ++nformats;
                     }
                 }
+#endif
                 NSUInteger len = [type lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
                 formatsSz += len;
                 ++nformats;
@@ -107,6 +114,7 @@ static char **GetMimeTypes(int *pnformats)
             for (NSPasteboardItem *item in items) {
                 NSArray<NSString *> *types = [item types];
                 for (NSString *type in types) {
+#ifdef SDL_HAVE_UNIFORMTYPEIDENTIFIERS
                     if (@available(macOS 11.0, *)) {
                         UTType *uttype = [UTType typeWithIdentifier:type];
                         NSString *mime_type = [uttype preferredMIMEType];
@@ -118,6 +126,7 @@ static char **GetMimeTypes(int *pnformats)
                             strPtr += len;
                         }
                     }
+#endif
                     NSUInteger len = [type lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
                     SDL_memcpy(strPtr, [type UTF8String], len);
                     new_mime_types[i++] = strPtr;
--- a/src/dialog/cocoa/SDL_cocoadialog.m
+++ b/src/dialog/cocoa/SDL_cocoadialog.m
@@ -25,7 +25,10 @@
 #ifdef SDL_PLATFORM_MACOS
 
 #import <Cocoa/Cocoa.h>
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
 #import <UniformTypeIdentifiers/UTType.h>
+#define SDL_HAVE_UNIFORMTYPEIDENTIFIERS 1
+#endif
 
 #ifdef SDL_VIDEO_DRIVER_COCOA
 extern void Cocoa_SetWindowHasModalDialog(SDL_Window *window, bool has_modal);
@@ -43,6 +46,7 @@
     //  allow too many files than not allow the one the user actually needs, so just take the part after the '.'
     const char *dot = SDL_strrchr(pattern_ptr, '.');
     NSString *extstr = [NSString stringWithFormat: @"%s", dot ? (dot + 1) : pattern_ptr];
+#ifdef SDL_HAVE_UNIFORMTYPEIDENTIFIERS
     if (@available(macOS 11.0, *)) {
         UTType *uttype = [UTType typeWithFilenameExtension:extstr];
         if (uttype) {  // still failed? Don't add the pattern. This is what the pre-macOS11 path does internally anyhow.
@@ -51,6 +55,9 @@
     } else {
         [types addObject:extstr];
     }
+#else
+    [types addObject:extstr];
+#endif
 }
 
 static void ReactivateAfterDialog(void)
@@ -150,11 +157,15 @@
         }
 
         if (!has_all_files) {
+#ifdef SDL_HAVE_UNIFORMTYPEIDENTIFIERS
             if (@available(macOS 11.0, *)) {
                 [dialog setAllowedContentTypes:types];
             } else {
                 [dialog setAllowedFileTypes:types];
             }
+#else
+            [dialog setAllowedFileTypes:types];
+#endif
         }
     }
 
--- a/src/video/cocoa/SDL_cocoamodes.m
+++ b/src/video/cocoa/SDL_cocoamodes.m
@@ -283,6 +283,7 @@
 
 static char *Cocoa_GetDisplayName(CGDirectDisplayID displayID)
 {
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
     if (@available(macOS 10.15, *)) {
        NSScreen *screen = GetNSScreenForDisplayID(displayID);
        if (screen) {
@@ -292,6 +293,7 @@
             }
         }
     }
+#endif
 
     // This API is deprecated in 10.9 with no good replacement (as of 10.15).
     io_service_t servicePort = CGDisplayIOServicePort(displayID);
@@ -311,6 +313,7 @@
     HDR->SDR_white_level = 1.0f;
     HDR->HDR_headroom = 1.0f;
 
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
     if (@available(macOS 10.15, *)) {
         NSScreen *screen = GetNSScreenForDisplayID(displayID);
         if (screen) {
@@ -321,6 +324,7 @@
             }
         }
     }
+#endif
 }
 
 static bool Cocoa_GetUsableBounds(CGDirectDisplayID displayID, SDL_Rect *rect)
--- a/src/render/metal/SDL_render_metal.m
+++ b/src/render/metal/SDL_render_metal.m
@@ -716,6 +716,7 @@
         case SDL_PIXELFORMAT_ABGR2101010:
             pixfmt = MTLPixelFormatRGB10A2Unorm;
             break;
+#if !defined(SDL_PLATFORM_MACOS) || __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
         case SDL_PIXELFORMAT_RGB565:
             if (@available(macOS 11.0, *)) {
                 pixfmt = MTLPixelFormatB5G6R5Unorm;
@@ -736,6 +737,7 @@
                 pixfmt = MTLPixelFormatABGR4Unorm;
             }
             break;
+#endif
         case SDL_PIXELFORMAT_INDEX8:
         case SDL_PIXELFORMAT_IYUV:
         case SDL_PIXELFORMAT_YV12:
@@ -1985,6 +1987,7 @@
         case MTLPixelFormatRGBA32Float:
             format = SDL_PIXELFORMAT_RGBA128_FLOAT;
             break;
+#if !defined(SDL_PLATFORM_MACOS) || __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
         case MTLPixelFormatB5G6R5Unorm:
             format = SDL_PIXELFORMAT_RGB565;
             break;
@@ -1997,6 +2000,7 @@
         case MTLPixelFormatABGR4Unorm:
             format = SDL_PIXELFORMAT_RGBA4444;
             break;
+#endif
         default:
             SDL_SetError("Unknown framebuffer pixel format");
             return NULL;
@@ -2413,6 +2417,7 @@
         SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_ABGR2101010);
         SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_RGBA64_FLOAT);
         SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_RGBA128_FLOAT);
+#if !defined(SDL_PLATFORM_MACOS) || __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
         if (@available(macOS 11.0, iOS 13.0, tvOS 13.0, *)) {
             if ([mtldevice supportsFamily:MTLGPUFamilyApple1]) {
                 SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_RGB565);
@@ -2421,6 +2426,7 @@
                 SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_RGBA4444);
             }
         }
+#endif
         SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_INDEX8);
         SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_YV12);
         SDL_AddSupportedTextureFormat(renderer, SDL_PIXELFORMAT_IYUV);
--- a/src/joystick/apple/SDL_mfijoystick.m
+++ b/src/joystick/apple/SDL_mfijoystick.m
@@ -1494,6 +1494,7 @@
 
 static bool IOS_JoystickSetLED(SDL_Joystick *joystick, Uint8 red, Uint8 green, Uint8 blue)
 {
+#ifdef SDL_JOYSTICK_MFI
     @autoreleasepool {
         SDL_JoystickDeviceItem *device = joystick->hwdata;
 
@@ -1512,6 +1513,7 @@
             }
         }
     }
+#endif
     return SDL_Unsupported();
 }
 
@@ -1522,6 +1524,7 @@
 
 static bool IOS_JoystickSetSensorsEnabled(SDL_Joystick *joystick, bool enabled)
 {
+#ifdef SDL_JOYSTICK_MFI
     @autoreleasepool {
         SDL_JoystickDeviceItem *device = joystick->hwdata;
 
@@ -1538,6 +1541,7 @@
             }
         }
     }
+#endif
 
     return SDL_Unsupported();
 }
@@ -1633,6 +1637,7 @@
 
 static bool IOS_JoystickGetGamepadMapping(int device_index, SDL_GamepadMapping *out)
 {
+#ifdef SDL_JOYSTICK_MFI
     SDL_JoystickDeviceItem *device = GetDeviceForIndex(device_index);
     if (device == NULL) {
         return false;
@@ -1765,6 +1770,7 @@
 
         return true;
     }
+#endif
     return false;
 }
 
