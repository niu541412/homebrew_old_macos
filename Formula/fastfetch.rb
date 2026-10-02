class Fastfetch < Formula
  desc "Like neofetch, but much faster because written mostly in C"
  homepage "https://github.com/fastfetch-cli/fastfetch"
  url "https://github.com/fastfetch-cli/fastfetch/archive/refs/tags/2.69.0.tar.gz"
  sha256 "d0e42faf307e39e7b531d632745a56e4eb558a6545f557280099c622562355ee"
  license "MIT"
  head "https://github.com/fastfetch-cli/fastfetch.git", branch: "dev"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 arm64_golden_gate: "f04813a4392632b5196d7b0ebd35f887555c2c0fad13b085744867da4bc2931c"
    sha256 arm64_tahoe:       "932f519f9eae54ef60d47881e4d528b9381117299eee04d93e3bb4bf3541c3c3"
    sha256 arm64_sequoia:     "4a741bfaa50f253c1589ae9cedea662132fd4096c590630cf8c9f68db5843e0e"
    sha256 arm64_linux:       "21e7ff92f7b70a493c2c60c37569ec9c8bc5758e73b4c4ac744a66cb450e0b08"
    sha256 x86_64_linux:      "549311d6caabdaaf665783ab257e67afb8c3fa826956236e12313993412ccbd5"
  end

  depends_on "chafa" => :build
  depends_on "cmake" => :build
  depends_on "glib" => :build
  depends_on "imagemagick" => :build
  depends_on "lua" => :build
  depends_on "pkgconf" => :build
  depends_on "python@3.14" => :build
  depends_on "vulkan-loader" => :build
  depends_on "yyjson"

  uses_from_macos "sqlite" => :build

  on_macos do
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1700
  end

  on_linux do
    depends_on "dbus" => :build
    depends_on "ddcutil" => :build
    depends_on "elfutils" => :build
    depends_on "libdrm" => :build
    depends_on "libx11" => :build
    depends_on "libxcb" => :build
    depends_on "libxrandr" => :build
    depends_on "mesa" => :build
    depends_on "opencl-icd-loader" => :build
    depends_on "pulseaudio" => :build
    depends_on "rpm" => :build
    depends_on "wayland" => :build
    depends_on "zlib-ng-compat" => :build
  end

  fails_with :clang do
    build 1700
    cause "Requires C23 auto type inference"
  end

  deny_network_access!

  patch :DATA

  def install
    args = %W[
      -DCMAKE_INSTALL_SYSCONFDIR=#{etc}
      -DBUILD_FLASHFETCH=OFF
      -DENABLE_SYSTEM_YYJSON=ON
    ]
    if HOMEBREW_PREFIX.to_s != HOMEBREW_DEFAULT_PREFIX
      # CMake already adds default Homebrew prefixes to rpath.
      args << "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath,#{HOMEBREW_PREFIX}/lib"
    end
    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
    bash_completion.install share/"bash-completion/completions/fastfetch"
  end

  test do
    assert_match "fastfetch", shell_output("#{bin}/fastfetch --version")
    assert_match "OS", shell_output("#{bin}/fastfetch --structure OS --pipe")
  end
end

__END__
--- a/src/detection/bluetooth/bluetooth_apple.m
+++ b/src/detection/bluetooth/bluetooth_apple.m
@@ -289,10 +289,12 @@
 }
 
 static const char* detectLe(FFBluetoothOptions* options, FFlist* devices /* FFBluetoothResult */, NSDictionary<NSString*, NSString*>* classicAddressByIdentifier) {
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
     CBManagerAuthorization authorization = CBCentralManager.authorization;
     if (authorization == CBManagerAuthorizationDenied || authorization == CBManagerAuthorizationRestricted) {
         return nullptr; // The user said no. `NotDetermined` is left to the manager below, which asks.
     }
+#endif
 
     FFBluetoothLeCentral* delegate = [FFBluetoothLeCentral new];
     delegate.central = [[CBCentralManager alloc] initWithDelegate: delegate queue: dispatch_get_main_queue()];
--- a/src/detection/gamepad/gamepad_apple.m
+++ b/src/detection/gamepad/gamepad_apple.m
@@ -165,6 +165,7 @@
 // The GameController framework's own devices, and how many of them there were. `set` is the IOKit
 // side, used only to borrow the serial -- see `findHIDDeviceForController()`.
 static uint32_t findGameControllerDevices(FFlist* devices, NSSet* set) {
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
     if (@available(macOS 11.0, *)) {
         // See the note at the top: the list stays empty until the run loop has been pumped once, and
         // the timeout only bounds the case where the framework has nothing to report at all. The
@@ -222,6 +223,7 @@
         }
         return count;
     }
+#endif
     return 0;
 }
 
@@ -234,6 +236,7 @@
 // Apple's whitelist, fails this and skips the wait entirely instead of sitting through a timeout for
 // a list that will never contain it.
 static bool anyDeviceIsClaimedByGameController(NSSet* set) {
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
     if (@available(macOS 11.0, *)) {
         for (id value in set) {
             if ([GCController supportsHIDDevice: (__bridge IOHIDDeviceRef) value]) {
@@ -241,12 +244,14 @@
             }
         }
     }
+#endif
     return false;
 }
 
 static void enumSet(IOHIDDeviceRef value, FFFindGamepadContext* ctx) {
     // A device the framework owns is already in the list under its own name; see the note at the
     // top for why this is conditional on the framework having contributed anything at all.
+#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
     if (ctx->gameControllerCount > 0) {
         if (@available(macOS 11.0, *)) {
             if ([GCController supportsHIDDevice:value]) {
@@ -254,6 +259,7 @@
             }
         }
     }
+#endif
 
     FFGamepadDevice* device = FF_LIST_ADD(FFGamepadDevice, *ctx->devices);
     ffStrbufInit(&device->serial);
