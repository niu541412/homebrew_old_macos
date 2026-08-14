class Tesseract < Formula
  desc "OCR (Optical Character Recognition) engine"
  homepage "https://tesseract-ocr.github.io/"
  url "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.5.3.tar.gz"
  sha256 "9218e62793116d42a9f6d14cd9348518b27f382096eea3d0f2d1a24616bb5884"
  license "Apache-2.0"
  compatibility_version 1
  head "https://github.com/tesseract-ocr/tesseract.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkgconf" => :build
  depends_on "cairo"
  depends_on "fontconfig"
  depends_on "glib"
  depends_on "harfbuzz"
  depends_on "icu4c@78"
  depends_on "leptonica"
  depends_on "libarchive"
  depends_on "pango"

  on_macos do
    depends_on "freetype"
    depends_on "gettext"
    depends_on "libffi" if MacOS.version < :catalina
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100
  end

  resource "eng" do
    url "https://github.com/tesseract-ocr/tessdata_fast/raw/4.1.0/eng.traineddata"
    sha256 "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2"
  end

  resource "osd" do
    url "https://github.com/tesseract-ocr/tessdata_fast/raw/4.1.0/osd.traineddata"
    sha256 "9cf5d576fcc47564f11265841e5ca839001e7e6f38ff7f7aacf46d15a96b00ff"
  end

  resource "snum" do
    url "https://github.com/USCDataScience/counterfeit-electronics-tesseract/raw/319a6eeacff181dad5c02f3e7a3aff804eaadeca/Training%20Tesseract/snum.traineddata"
    sha256 "36f772980ff17c66a767f584a0d80bf2302a1afa585c01a226c1863afcea1392"
  end

  patch :DATA
  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    # explicitly state leptonica header location, as the makefile defaults to /usr/local/include,
    # which doesn't work for non-default homebrew location
    ENV["LIBLEPT_HEADERSDIR"] = HOMEBREW_PREFIX/"include"

    ENV.cxx11

    ENV.append "LDFLAGS", "#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"
    # The High Sierra pkg-config shims expose /usr/include explicitly.
    # Treat it as a system include path so pkgconf filters it without
    # disturbing Homebrew dependency paths under /usr/local.
    if OS.mac? && MacOS.version <= :high_sierra
      ENV.append_path "PKG_CONFIG_SYSTEM_INCLUDE_PATH", "/usr/include"
    end

    system "./autogen.sh"
    system "./configure", "--datarootdir=#{HOMEBREW_PREFIX}/share",
                          "--disable-silent-rules",
                          *std_configure_args
    system "make", "training"

    # make install in the local share folder to avoid permission errors
    system "make", "install", "training-install", "datarootdir=#{share}"

    resource("snum").stage { mv "snum.traineddata", share/"tessdata" }
    resource("eng").stage { mv "eng.traineddata", share/"tessdata" }
    resource("osd").stage { mv "osd.traineddata", share/"tessdata" }
  end

  def caveats
    <<~EOS
      This formula contains only the "eng", "osd", and "snum" language data files.
      If you need any other supported languages, run `brew install tesseract-lang`.
    EOS
  end

  test do
    resource "homebrew-test_resource" do
      url "https://raw.githubusercontent.com/tesseract-ocr/test/6dd816cdaf3e76153271daf773e562e24c928bf5/testing/eurotext.tif"
      sha256 "7b9bd14aba7d5e30df686fbb6f71782a97f48f81b32dc201a1b75afe6de747d6"
    end

    resource("homebrew-test_resource").stage do
      system bin/"tesseract", "./eurotext.tif", "./output", "-l", "eng"
      assert_match "The (quick) [brown] {fox} jumps!\n", File.read("output.txt")
    end
  end
end

__END__
--- a/src/training/unicharset_extractor.cpp
+++ b/src/training/unicharset_extractor.cpp
@@ -21,7 +21,6 @@
 // a unicharset.

 #include <cstdlib>
-#include <filesystem>
 #include "boxread.h"
 #include "commandlineflags.h"
 #include "commontraining.h" // CheckSharedLibraryVersion
@@ -65,13 +64,14 @@
   UNICHARSET unicharset;
   // Load input files
   for (int arg = 1; arg < argc; ++arg) {
-    std::filesystem::path filePath = argv[arg];
+    const char* filePath = argv[arg];
+    const char* dot = strrchr(filePath, '.');
     std::string file_data = tesseract::ReadFile(argv[arg]);
     if (file_data.empty()) {
       continue;
     }
     std::vector<std::string> texts;
-    if (filePath.extension() == ".box") {
+    if (dot && strcmp(dot, ".box") == 0) {
       tprintf("Extracting unicharset from box file %s\n", argv[arg]);
       bool res = ReadMemBoxes(-1, /*skip_blanks*/ true, &file_data[0],
                    /*continue_on_failure*/ false, /*boxes*/ nullptr, &texts,
