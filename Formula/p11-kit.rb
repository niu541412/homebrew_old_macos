class P11Kit < Formula
  desc "Library to load and enumerate PKCS#11 modules"
  homepage "https://p11-glue.github.io/p11-glue/p11-kit.html"
  url "https://github.com/p11-glue/p11-kit/releases/download/0.26.5/p11-kit-0.26.5.tar.xz"
  sha256 "f2cc09111e44bf3fea58f023180b33acea90aa82d042d6fbb623fbc5ba033bb7"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/p11-glue/p11-kit.git", branch: "master"

  bottle do
  end

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "ca-certificates"
  depends_on "libtasn1"

  uses_from_macos "libffi", since: :catalina

  def install
    # https://bugs.freedesktop.org/show_bug.cgi?id=91602#c1
    ENV["FAKED_MODE"] = "1"

    args = %W[
      -Dsystem_config=#{etc}
      -Dmodule_config=#{etc}/pkcs11/modules
      -Dtrust_paths=#{etc}/ca-certificates/cert.pem
      -Dsystemd=disabled
    ]

    system "meson", "setup", "_build", *args, *std_meson_args
    system "meson", "compile", "-C", "_build", "--verbose"
    # This formula is used with crypto libraries, so let's run the test suite.
    system "meson", "test", "-C", "_build", "--timeout-multiplier=2"
    system "meson", "install", "-C", "_build"

    # HACK: Work around p11-kit: couldn't load module: .../lib/pkcs11/p11-kit-trust.so
    # Issue ref: https://github.com/p11-glue/p11-kit/issues/612
    (lib/"pkcs11").install_symlink "p11-kit-trust.dylib" => "p11-kit-trust.so" if OS.mac?
  end

  test do
    assert_match "library-manufacturer: PKCS#11 Kit", shell_output("#{bin}/p11-kit list-modules --verbose")
  end
end
