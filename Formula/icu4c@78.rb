class Icu4cAT78 < Formula
  desc "C/C++ and Java libraries for Unicode and globalization"
  homepage "https://icu.unicode.org/home"
  url "https://github.com/unicode-org/icu/releases/download/release-78.2/icu4c-78.2-sources.tgz"
  sha256 "3e99687b5c435d4b209630e2d2ebb79906c984685e78635078b672e03c89df35"
  license "ICU"

  # We allow the livecheck to detect new `icu4c` major versions in order to
  # automate version bumps. To make sure PRs are created correctly, we output
  # an error during installation to notify when a new formula is needed.
  livecheck do
    url :stable
    regex(/^release[._-]v?(\d+(?:[.-]\d+)+)$/i)
    strategy :git do |tags, regex|
      tags.filter_map { |tag| tag[regex, 1]&.tr("-", ".") }
    end
  end

  bottle do
  end

  keg_only :shadowed_by_macos, "macOS provides libicucore.dylib (but nothing else)"

  patch :DATA
  def install
    odie "Major version bumps need a new formula!" if version.major.to_s != name[/@(\d+)$/, 1]

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
