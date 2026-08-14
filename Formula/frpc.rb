class Frpc < Formula
  desc "Client app of fast reverse proxy to expose a local server to the internet"
  homepage "https://github.com/fatedier/frp"
  url "https://github.com/fatedier/frp/archive/refs/tags/v0.70.1.tar.gz"
  sha256 "67246606f504cb15df72193f1a83911259e92b6a87838cff8850031efd406dc8"
  license "Apache-2.0"
  head "https://github.com/fatedier/frp.git", branch: "dev"

  bottle do
  end

  depends_on "go" => :build
  depends_on "node" => :build

  def install
    package_json = JSON.parse(File.read("web/package-lock.json"))
    target = package_json["packages"]["node_modules/esbuild"]
    if target
        target["version"] = "0.26.0"
        target.delete("resolved")
        target.delete("integrity")
    end
    
    target = package_json["packages"]["node_modules/@esbuild/darwin-x64"]
    if target
        target["version"] = "0.26.0"
        target.delete("resolved")
        target.delete("integrity")
    end

    File.write("web/package-lock.json", JSON.pretty_generate(package_json))

    cd "web/frpc" do
      system "npm", "install", *std_npm_args(prefix: false)
      system "npm", "run", "build"
    end

    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(ldflags: "-s -w", tags: "frpc"), "./cmd/frpc"
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
