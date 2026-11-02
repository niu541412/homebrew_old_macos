class Icu4cAT78 < Formula
  desc "C/C++ and Java libraries for Unicode and globalization"
  homepage "https://icu.unicode.org/home"
  url "https://github.com/unicode-org/icu/releases/download/release-78.3/icu4c-78.3-sources.tgz"
  sha256 "3a2e7a47604ba702f345878308e6fefeca612ee895cf4a5f222e7955fabfe0c0"
  license "Unicode-3.0"
  revision 1
  compatibility_version 1

  livecheck do
    url :stable
    regex(/^release[._-]v?(78(?:[.-]\d+)+)$/i)
    strategy :git do |tags, regex|
      tags.filter_map { |tag| tag[regex, 1]&.tr("-", ".") }
    end
  end

  bottle do
  end

  keg_only :versioned_formula

  deny_network_access!

  patch :DATA

  def install
    args = %w[
      --disable-samples
      --disable-tests
      --enable-static
      --with-library-bits=64
    ]

    cd "source" do
      system "./configure", *args, *std_configure_args
      system "make"
      system "make", "install"
    end

    inreplace [bin/"icu-config", *lib.glob("pkgconfig/icu-*.pc")], prefix, opt_prefix
  end

  test do
    if File.exist? "/usr/share/dict/words"
      system bin/"gendict", "--uchars", "/usr/share/dict/words", "dict"
    else
      (testpath/"hello").write "hello\nworld\n"
      system bin/"gendict", "--uchars", "hello", "dict"
    end
  end
end

__END__
--- a/source/i18n/measunit_extra.cpp
+++ b/source/i18n/measunit_extra.cpp
@@ -33,6 +33,7 @@
 #include "util.h"
 #include <limits.h>
 #include <cstdlib>
+#include <cmath>
 U_NAMESPACE_BEGIN


@@ -574,7 +575,7 @@
         // Check if the value is integer.
         uint64_t int_result = static_cast<uint64_t>(double_result);
         const double kTolerance = 1e-9;
-        if (abs(double_result - int_result) > kTolerance) {
+        if (std::fabs(double_result - int_result) > kTolerance) {
             status = kUnitIdentifierSyntaxError;
             return 0;
         }
