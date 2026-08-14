class Openjph < Formula
  desc "Open-source implementation of JPEG2000 Part-15 (or JPH or HTJ2K)"
  homepage "https://github.com/aous72/OpenJPH"
  url "https://github.com/aous72/OpenJPH/archive/refs/tags/0.31.0.tar.gz"
  sha256 "fe169dbbaae71a169a0a6a68dccb346616193252c1ca044217afa0d5d1dc436f"
  license "BSD-2-Clause"
  compatibility_version 6
  head "https://github.com/aous72/OpenJPH.git", branch: "master"

  bottle do
  end

  depends_on "cmake" => :build
  depends_on "libtiff"

  on_macos do
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100
  end
  
  patch :DATA
  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    ENV["DYLD_LIBRARY_PATH"] = lib.to_s

    args = %W[
      -DCMAKE_INSTALL_RPATH=#{rpath}
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    resource "homebrew-test.ppm" do
      url "https://raw.githubusercontent.com/aous72/jp2k_test_codestreams/ca2d370/openjph/references/Malamute.ppm"
      sha256 "e4e36966d68a473a7f5f5719d9e41c8061f2d817f70a7de1c78d7e510a6391ff"
    end
    resource("homebrew-test.ppm").stage testpath

    system bin/"ojph_compress", "-i", "Malamute.ppm", "-o", "homebrew.j2c"
    system bin/"ojph_expand", "-i", "homebrew.j2c", "-o", "homebrew.ppm"
    assert_path_exists testpath/"homebrew.ppm"
  end
end

__END__
--- a/src/core/others/ojph_mem_c.c
+++ b/src/core/others/ojph_mem_c.c
@@ -77,7 +77,14 @@
   void* ojph_aligned_malloc(size_t alignment, size_t size)
   {
     assert(alignment != 0 && (alignment & (alignment - 1)) == 0);
+   #if defined(__APPLE__) || defined(__MACH__)
+    void* ptr = NULL;
+    if (posix_memalign(&ptr, alignment, size) != 0)
+      return NULL;
+    return ptr;
+  #else
     return aligned_alloc(alignment, size);
+  #endif
   }

   void ojph_aligned_free(void* pointer)
