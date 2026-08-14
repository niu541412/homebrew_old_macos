class Sdl3 < Formula
  desc "Low-level access to audio, keyboard, mouse, joystick, and graphics"
  homepage "https://libsdl.org/"
  url "https://github.com/libsdl-org/SDL/releases/download/release-3.4.14/SDL3-3.4.14.tar.gz"
  sha256 "30d4aa2b3037718142b32dffd4e72f917ebb6cc5227150e7bb9c45efb2153aeb"
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

  patch :DATA
  def install
    inreplace "CMakeLists.txt", "sdl_link_dependency(uniformtypeidentifiers", "#sdl_link_dependency(uniformtypeidentifiers"
    inreplace "cmake/sdl3.pc.in", "@SDL_PKGCONFIG_PREFIX@", HOMEBREW_PREFIX

    args = %w[
      -DSDL_TESTS=OFF
      -DSDL_X11_XTEST=OFF
      -DSDL_WAYLAND=OFF
      -DSDL_CAMERA=OFF
      -DSDL_JOYSTICK=OFF
      -DSDL_HAPTIC=OFF
      -DSDL_DIALOG=OFF
      -DSDL_GPU=OFF
      -DSDL_METAL=OFF
      -DSDL_RENDER_METAL=OFF
      -DSDL_COCOA=OFF
      -DSDL_X11=OFF
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
