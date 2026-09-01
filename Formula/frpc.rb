class Frpc < Formula
  desc "Client app of fast reverse proxy to expose a local server to the internet"
  homepage "https://github.com/fatedier/frp"
  url "https://github.com/fatedier/frp/archive/refs/tags/v0.71.0.tar.gz"
  sha256 "1dd367d6d822a7fce1d3012fce0a6e778bc90c454e2c7baa0eb1e6de6054c61b"
  license "Apache-2.0"
  head "https://github.com/fatedier/frp.git", branch: "dev"

  resource "esbuild" do
    url "https://github.com/evanw/esbuild/archive/refs/tags/v0.28.1.tar.gz"
    sha256 "65c756fa87d43178ac4a5242454c2bd0fde325f8ecf77997f8fa4b88f94d5cd2"
  end

  bottle do
  end

  depends_on "go" => :build
  depends_on "node" => :build

  def install
    resource("esbuild").stage do
      system "go", "build", "-o", buildpath/"esbuild", "./cmd/esbuild"
    end

    cd "web/frpc" do
      system "npm", "install", *std_npm_args(prefix: false)
      with_env(ESBUILD_BINARY_PATH: buildpath/"esbuild") do
        system "npm", "run", "build-only"
      end
    end

    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(tags: "frpc"), "./cmd/frpc"
    (etc/"frp").install "conf/frpc.toml"

    generate_completions_from_executable(bin/"frpc", "completion")
  end

  service do
    run [opt_bin/"frpc", "-c", etc/"frp/frpc.toml"]
    keep_alive true
    error_log_path var/"log/frpc.log"
    log_path var/"log/frpc.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/frpc -v")
    assert_match "Commands", shell_output("#{bin}/frpc help")
    assert_match "name should not be empty", shell_output("#{bin}/frpc http", 1)
  end
end
