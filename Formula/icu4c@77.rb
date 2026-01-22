class Icu4cAT77 < Formula
  desc "C/C++ and Java libraries for Unicode and globalization"
  homepage "https://icu.unicode.org/home"
  url "https://github.com/unicode-org/icu/releases/download/release-77-1/icu4c-77_1-src.tgz"
  version "77.1"
  sha256 "588e431f77327c39031ffbb8843c0e3bc122c211374485fa87dc5f3faff24061"
  license "ICU"
  revision 1

  bottle do
  end

  keg_only :versioned_formula

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
