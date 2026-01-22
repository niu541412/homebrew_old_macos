class Folly < Formula
  desc "Collection of reusable C++ library artifacts developed at Facebook"
  homepage "https://github.com/facebook/folly"
  url "https://github.com/facebook/folly/archive/refs/tags/v2026.01.12.00.tar.gz"
  sha256 "4b694698c773a3236d6379316f67872db77070d56ea256bec5759964712f9c34"
  license "Apache-2.0"
  revision 1
  head "https://github.com/facebook/folly.git", branch: "main"

  bottle do
  end

  depends_on "cmake" => :build
  depends_on "fast_float" => :build
  depends_on "pkgconf" => :build
  depends_on "boost"
  depends_on "double-conversion"
  depends_on "fmt"
  depends_on "gflags"
  depends_on "glog"
  depends_on "libevent"
  depends_on "libsodium"
  depends_on "lz4"
  depends_on "openssl@3"
  depends_on "snappy"
  depends_on "xz"
  depends_on "zstd"

  uses_from_macos "bzip2"
  uses_from_macos "zlib"

  on_macos do
    if Formula["blake3"].linked_keg.exist?
      odie "blake3 is linked and might interfere with the build!"
    end
    depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  end

  fails_with :clang do
    build 1100
    # https://github.com/facebook/folly/issues/1545
    cause <<~EOS
      Undefined symbols for architecture x86_64:
        "std::__1::__fs::filesystem::path::lexically_normal() const"
    EOS
  end

  # Workaround to build with glog >= 0.7
  # ref: https://github.com/facebook/folly/issues/2171
  # ref: https://github.com/facebook/folly/pull/2320
  # ref: https://github.com/facebook/folly/pull/2474
  patch :DATA

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)

    args = %W[
      -DCMAKE_LIBRARY_ARCHITECTURE=#{Hardware::CPU.arch}
      -DFOLLY_USE_JEMALLOC=OFF
    ]

    system "cmake", "-S", ".", "-B", "build/shared",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    *args, *std_cmake_args,
                    "-DCMAKE_SHARED_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"
    system "cmake", "--build", "build/shared"
    system "cmake", "--install", "build/shared"

    system "cmake", "-S", ".", "-B", "build/static",
                    "-DBUILD_SHARED_LIBS=OFF",
                    *args, *std_cmake_args,
                    "-DCMAKE_STATIC_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}",
                    "-DCMAKE_EXE_LINKER_FLAGS=#{Formula["llvm"].opt_lib}/c++/#{shared_library("libc++")}"
    system "cmake", "--build", "build/static"
    lib.install "build/static/libfolly.a", "build/static/folly/libfollybenchmark.a"
  end

  test do
    # Force use of Clang rather than LLVM Clang
    ENV.clang if OS.mac?

    (testpath/"test.cc").write <<~CPP
      #include <folly/FBVector.h>
      int main() {
        folly::fbvector<int> numbers({0, 1, 2, 3});
        numbers.reserve(10);
        for (int i = 4; i < 10; i++) {
          numbers.push_back(i * 2);
        }
        assert(numbers[6] == 12);
        return 0;
      }
    CPP
    system ENV.cxx, "-std=c++17", "test.cc", "-I#{include}", "-L#{lib}",
                    "-lfolly", "-o", "test"
    system "./test"
  end
end

__END__
diff --git a/CMake/folly-config.cmake.in b/CMake/folly-config.cmake.in
index 957ae5c56..fe811d7d9 100644
--- a/CMake/folly-config.cmake.in
+++ b/CMake/folly-config.cmake.in
@@ -30,6 +30,7 @@ set(FOLLY_LIBRARIES Folly::folly)
 
 # Find folly's dependencies
 find_dependency(fmt)
+find_dependency(glog CONFIG)
 
 set(Boost_USE_STATIC_LIBS "@FOLLY_BOOST_LINK_STATIC@")
 find_package(Boost 1.69.0 REQUIRED
diff --git a/CMake/folly-deps.cmake b/CMake/folly-deps.cmake
index 2ca5cfec7..a284a91fe 100644
--- a/CMake/folly-deps.cmake
+++ b/CMake/folly-deps.cmake
@@ -62,7 +62,8 @@ if(LIBGFLAGS_FOUND)
   set(FOLLY_LIBGFLAGS_INCLUDE ${LIBGFLAGS_INCLUDE_DIR})
 endif()
 
-find_package(Glog MODULE)
+find_package(GLOG NAMES glog CONFIG REQUIRED)
+set(GLOG_LIBRARY glog::glog)
 set(FOLLY_HAVE_LIBGLOG ${GLOG_FOUND})
 list(APPEND FOLLY_LINK_LIBRARIES ${GLOG_LIBRARY})
 list(APPEND FOLLY_INCLUDE_DIRECTORIES ${GLOG_INCLUDE_DIR})

--- a/folly/io/async/fdsock/AsyncFdSocket.h
+++ b/folly/io/async/fdsock/AsyncFdSocket.h
@@ -20,6 +20,16 @@
 #include <folly/io/async/fdsock/SocketFds.h>
 #include <folly/portability/GTestProd.h>
 
+#ifdef __APPLE__
+#include <AvailabilityMacros.h>
+#if MAC_OS_X_VERSION_MIN_REQUIRED < 110000
+#ifdef __DARWIN_ALIGN32
+#undef __DARWIN_ALIGN32
+#define __DARWIN_ALIGN32(p) ((__darwin_size_t)((__darwin_size_t)(p) + __DARWIN_ALIGNBYTES32) &~ __DARWIN_ALIGNBYTES32)
+#endif
+#endif
+#endif
+
 namespace folly {
 
 /**
--- a/folly/io/FsUtil.h
+++ b/folly/io/FsUtil.h
@@ -16,13 +16,26 @@

 #pragma once

+#if defined(__APPLE__)
+#include <Availability.h>
+#endif
+
+#if defined(__cpp_lib_filesystem) && __cpp_lib_filesystem >= 201703 && \
+    (!defined(__APPLE__) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 101500)
+#define FOLLY_HAS_STD_FILESYSTEM 1
 #include <filesystem>
+#else
+#define FOLLY_HAS_STD_FILESYSTEM 0
+#endif
+
 #include <boost/filesystem.hpp>

 namespace folly {
 namespace fs {

+#if FOLLY_HAS_STD_FILESYSTEM
 namespace std_fs = std::filesystem;
+#endif

 // Functions defined in this file are meant to extend the
 // boost::filesystem library; functions will be named according to boost's
@@ -68,12 +81,14 @@
  */
 path executable_path();

+#if FOLLY_HAS_STD_FILESYSTEM
 struct unique_path_fn {
   std_fs::path operator()(
       std_fs::path const& model = "%%%%-%%%%-%%%%-%%%%") const;
 };
 using std_fs_unique_path_fn = unique_path_fn;
 inline constexpr std_fs_unique_path_fn std_fs_unique_path;
+#endif

 } // namespace fs
 } // namespace folly
--- a/folly/io/FsUtil.cpp
+++ b/folly/io/FsUtil.cpp
@@ -103,6 +103,7 @@
   return L"0123456789abcdef";
 }
 
+#if FOLLY_HAS_STD_FILESYSTEM
 std_fs::path unique_path_fn::operator()(std_fs::path const& model) const {
   constexpr auto pin = std_fs::path::value_type('%');
   constexpr auto hex = hex_(pin);
@@ -120,6 +121,7 @@
   }
   return std::move(result);
 }
+#endif
 
 } // namespace fs
 } // namespace folly
