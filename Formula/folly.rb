class Folly < Formula
  desc "Collection of reusable C++ library artifacts developed at Facebook"
  homepage "https://github.com/facebook/folly"
  url "https://github.com/facebook/folly/archive/refs/tags/v2026.07.27.00.tar.gz"
  sha256 "dcb373984e571468659be8a74c0a43a1cb6548fbe5579a806674db43d7261c4e"
  license "Apache-2.0"
  compatibility_version 1
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

  on_macos do
    depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  end

  on_linux do
    depends_on "zlib-ng-compat"
  end

  # Workaround for arm64 Linux error "Missing variable is: CMAKE_ASM_CREATE_SHARED_LIBRARY"
  # Ref: https://github.com/facebook/folly/pull/2562#issuecomment-3988207056
  patch :DATA

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    args = %W[
      -DFOLLY_USE_JEMALLOC=OFF
    ]

    system "cmake", "-S", ".", "-B", "build/shared",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    *args, *std_cmake_args,
                    "-DCMAKE_SHARED_LINKER_FLAGS=#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"
    system "cmake", "--build", "build/shared"
    system "cmake", "--install", "build/shared"

    system "cmake", "-S", ".", "-B", "build/static",
                    "-DBUILD_SHARED_LIBS=OFF",
                    *args, *std_cmake_args,
                    "-DCMAKE_STATIC_LINKER_FLAGS=#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}",
                    "-DCMAKE_EXE_LINKER_FLAGS=#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"
    system "cmake", "--build", "build/static"
    lib.install "build/static/libfolly.a", "build/static/folly/libfollybenchmark.a"
  end

  test do
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
    system ENV.cxx, "-std=c++20", "test.cc", "-I#{include}", "-L#{lib}", "-lfolly", "-o", "test"
    system "./test"
  end
end

__END__
diff --git a/folly/external/aor/CMakeLists.txt b/folly/external/aor/CMakeLists.txt
index e07e58745..1429f54e9 100644
--- a/folly/external/aor/CMakeLists.txt
+++ b/folly/external/aor/CMakeLists.txt
@@ -20,6 +20,10 @@
 # Linux ELF directives (.size, etc.) that Darwin's assembler doesn't support
 if(IS_AARCH64_ARCH)
 
+if(BUILD_SHARED_LIBS)
+  set(CMAKE_ASM_CREATE_SHARED_LIBRARY ${CMAKE_C_CREATE_SHARED_LIBRARY})
+endif()
+
 folly_add_library(
   NAME memcpy_aarch64
   SRCS

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

--- a/folly/hash/UniqueHashKey.cpp
+++ b/folly/hash/UniqueHashKey.cpp
@@ -23,9 +23,11 @@
 #include <sys/auxv.h>
 #endif
 
+#if 0
 #if __has_include(<blake3.h>)
 #include <blake3.h>
 #endif
+#endif
 
 #if __has_include(<xxh3.h>)
 #include <xxh3.h>
@@ -84,6 +86,7 @@ unique_hash_key_algo_strong_sha256_init(
   return object;
 }
 
+#if 0
 #if __has_include(<blake3.h>)
 
 /// unique_hash_key_init_process_key_blake3
@@ -168,6 +171,7 @@ struct unique_hash_key_algo_fast_xxh3_op
 #endif // __has_include(<xxh3.h>)
 
 #endif // __has_include(<blake3.h>)
+#endif
 
 template <typename Hash, typename Update>
 FOLLY_ALWAYS_INLINE static void unique_hash_key_hash_items(
@@ -218,6 +222,7 @@ template std::array<uint8_t, 32> //
 unique_hash_key_algo_strong_sha256_fn<32>::operator()(
     span<detail::unique_hash_key_item const> in) const noexcept;
 
+#if 0
 #if __has_include(<blake3.h>)
 
 template <size_t Size>
@@ -278,5 +283,6 @@ unique_hash_key_algo_fast_xxh3_fn<16>::o
 #endif // __has_include(<xxh3.h>)
 
 #endif // __has_include(<blake3.h>)
+#endif
 
 } // namespace folly
