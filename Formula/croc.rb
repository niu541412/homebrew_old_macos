class Croc < Formula
  desc "Securely send things from one computer to another"
  homepage "https://github.com/schollz/croc"
  url "https://github.com/schollz/croc/archive/refs/tags/v11.5.4.tar.gz"
  sha256 "16910b594704b40e9df35eb3bc637db675fe3d770a4588bd32b5a12c5ff174ff"
  license "MIT"
  head "https://github.com/schollz/croc.git", branch: "main"

  bottle do
  end

  depends_on "go" => :build

  # `test do` block runs a local relay
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

    system "go", "build", *std_go_args
  end

  test do
    # As of https://github.com/schollz/croc/pull/701 an alternate method is used to provide the secret code
    ENV["CROC_SECRET"] = "homebrew-test"

    ports = [free_port, free_port]

    require "pty"
    pid = PTY.spawn(bin/"croc", "relay", "--ports", ports.join(",")).last
    sleep 3

    pid_send = PTY.spawn(bin/"croc", "--relay=localhost:#{ports.first}", "send",
                                     "--no-local", "--text=mytext", "--transfers=1").last
    sleep 3

    output = shell_output("#{bin}/croc --relay localhost:#{ports.first} --overwrite --yes")
    assert_match "mytext", output
  ensure
    Process.kill("TERM", pid_send)
    Process.kill("TERM", pid)
    Process.wait(pid_send)
    Process.wait(pid)
  end
end
