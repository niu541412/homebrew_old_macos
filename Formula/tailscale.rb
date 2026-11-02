class Tailscale < Formula
  desc "Easiest, most secure way to use WireGuard and 2FA"
  homepage "https://tailscale.com"
  url "https://github.com/tailscale/tailscale.git",
      tag:      "v1.104.4",
      revision: "27047635f237d1f3e0b08c0f487674757f30d2f7"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  bottle do
  end

  depends_on "go" => :build

  # `test do` block runs tailscaled, which attempts network connections
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

    vars = Utils.safe_popen_read("./build_dist.sh", "shellvars")
    ldflags = %W[
      -X tailscale.com/version.longStamp=#{vars.match(/VERSION_LONG="(.*)"/)[1]}
      -X tailscale.com/version.shortStamp=#{vars.match(/VERSION_SHORT="(.*)"/)[1]}
      -X tailscale.com/version.gitCommitStamp=#{vars.match(/VERSION_GIT_HASH="(.*)"/)[1]}
    ]
    system "go", "build", *std_go_args(ldflags:), "./cmd/tailscale"
    system "go", "build", *std_go_args(ldflags:, output: bin/"tailscaled"), "./cmd/tailscaled"

    generate_completions_from_executable(bin/"tailscale", shell_parameter_format: :cobra)
  end

  def caveats
    on_linux do
      <<~EOS
        tailscaled needs root privileges to configure iptables/nftables and DNS.
        Start the root service with:
          sudo --preserve-env=HOME brew services start tailscale

        To run without root, use userspace-networking mode:
          tailscaled --tun=userspace-networking
      EOS
    end
  end

  service do
    run opt_bin/"tailscaled"
    # See the caveats for userspace/non-root mode
    require_root true
    keep_alive true
    log_path var/"log/tailscaled.log"
    error_log_path var/"log/tailscaled.log"
  end

  test do
    version_text = shell_output("#{bin}/tailscale version")
    assert_match version.to_s, version_text
    assert_match(/commit: [a-f0-9]{40}/, version_text)

    spawn bin/"tailscaled", "-tun=userspace-networking", "-socket=#{testpath}/tailscaled.socket"
    sleep 2
    assert_match "Logged out.", shell_output("#{bin}/tailscale --socket=#{testpath}/tailscaled.socket status", 1)
  end
end
