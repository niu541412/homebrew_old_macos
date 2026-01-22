class Sdl3 < Formula
  desc "Low-level access to audio, keyboard, mouse, joystick, and graphics"
  homepage "https://libsdl.org/"
  url "https://github.com/libsdl-org/SDL/releases/download/release-3.4.0/SDL3-3.4.0.tar.gz"
  sha256 "082cbf5f429e0d80820f68dc2b507a94d4cc1b4e70817b119bbb8ec6a69584b8"
  license "Zlib"
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
    depends_on "libice"
    depends_on "libxcursor"
    depends_on "libxscrnsaver"
    depends_on "libxxf86vm"
    depends_on "pulseaudio"
    depends_on "xinput"
  end

  patch :DATA
  def install
    inreplace "CMakeLists.txt", "sdl_link_dependency(uniformtypeidentifiers", "#sdl_link_dependency(uniformtypeidentifiers"
    inreplace "cmake/sdl3.pc.in", "@SDL_PKGCONFIG_PREFIX@", HOMEBREW_PREFIX

    args = [
      "-DSDL_HIDAPI=ON",
      "-DSDL_WAYLAND=OFF",
      "-DSDL_CAMERA=OFF",
      "-DSDL_JOYSTICK=OFF",
      "-DSDL_HAPTIC=OFF",
      "-DSDL_DIALOG=OFF",
      "-DSDL_GPU=OFF",
      "-DSDL_METAL=OFF",
      "-DSDL_RENDER_METAL=OFF",
      "-DSDL_COCOA=OFF",
    ]

    args += if OS.mac?
      ["-DSDL_X11=OFF"]
    else
      ["-DSDL_X11=ON", "-DSDL_PULSEAUDIO=ON"]
    end

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
