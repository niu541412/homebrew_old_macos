class Fswatch < Formula
  desc "Monitor a directory for changes and run a shell command"
  homepage "https://emcrisostomo.github.io/fswatch/"
  url "https://github.com/emcrisostomo/fswatch/releases/download/1.22.0/fswatch-1.22.0.tar.gz"
  sha256 "fa6e2becba0a629964b466b39c5997e72d8a6da40d82b88190aae7359065c758"
  license all_of: ["GPL-3.0-or-later", "Apache-2.0"]

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
  end

  depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100

  def install
    if OS.mac? && DevelopmentTools.clang_build_version <= 1100
      ENV.llvm_clang
      ENV.append "LDFLAGS", "#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}"
    end
    system "./configure", *std_configure_args
    system "make", "install"
  end

  test do
    system bin/"fswatch", "-h"
  end
end
