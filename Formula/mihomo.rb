class Mihomo < Formula
  desc "Another rule-based tunnel in Go, formerly known as ClashMeta"
  homepage "https://wiki.metacubex.one"
  url "https://github.com/MetaCubeX/mihomo/archive/refs/tags/v1.19.33.tar.gz"
  sha256 "e7c596b37ff27ec487d19b1920f73e0c97a78067ea35766530ee9659ade72711"
  license "GPL-3.0-or-later"
  head "https://github.com/MetaCubeX/mihomo.git", branch: "main"

  bottle do
  end

  depends_on "go" => :build

  # `test do` block binds a local port
  allow_network_access! :test

  def fetch
    ENV["GOMODCACHE"] = buildpath/"go_mod_cache"
    system "go", "mod", "download"
  end

  def install
    ENV["GOMODCACHE"] = buildpath/"go_mod_cache"

    if OS.mac? && MacOS.version <= :high_sierra
      certstore = Pathname(Utils.safe_popen_read(
        "go", "list", "-m", "-f={{.Dir}}", "github.com/tailscale/certstore"
      ).strip)
      certstore_darwin = certstore/"certstore_darwin.go"
      chmod 0755, certstore
      chmod 0644, certstore_darwin

      inreplace certstore_darwin,
        /\tvar cfTrustErr C\.CFErrorRef.*?\tnchain := C\.CFArrayGetCount\(certChain\)\n/m,
        <<~GO
	      var trustResult C.SecTrustResultType
	      C.SecTrustEvaluate(trustRef, &trustResult)

	      nchain := C.SecTrustGetCertificateCount(trustRef)
        GO
      inreplace certstore_darwin,
                "C.SecCertificateRef(C.CFArrayGetValueAtIndex(certChain, j))",
                "C.SecTrustGetCertificateAtIndex(trustRef, j)"
    end

    ldflags = %W[
      -buildid=
      -X "github.com/metacubex/mihomo/constant.Version=#{version}"
      -X "github.com/metacubex/mihomo/constant.BuildTime=#{time.iso8601}"
    ]
    system "go", "build", *std_go_args(ldflags:, tags: "with_gvisor")

    (buildpath/"config.yaml").write <<~YAML
      # Document: https://wiki.metacubex.one/config/
      mixed-port: 7890
    YAML
    pkgetc.install "config.yaml"
  end

  def caveats
    <<~EOS
      You need to customize #{etc}/mihomo/config.yaml.
    EOS
  end

  service do
    run [opt_bin/"mihomo", "-d", etc/"mihomo"]
    keep_alive true
    working_dir etc/"mihomo"
    log_path var/"log/mihomo.log"
    error_log_path var/"log/mihomo.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mihomo -v")

    (testpath/"mihomo/config.yaml").write <<~YAML
      mixed-port: #{free_port}
    YAML
    system bin/"mihomo", "-t", "-d", testpath/"mihomo"
  end
end
