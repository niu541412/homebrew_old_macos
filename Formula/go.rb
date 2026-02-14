class Go < Formula
  desc "Open source programming language to build simple/reliable/efficient software"
  homepage "https://go.dev/"
  license "BSD-3-Clause"
  compatibility_version 2
  head "https://go.googlesource.com/go.git", branch: "master"

  stable do
    url "https://go.dev/dl/go1.26.0.src.tar.gz"
    mirror "https://fossies.org/linux/misc/go1.26.0.src.tar.gz"
    sha256 "c9132a8a1f6bd2aa4aad1d74b8231d95274950483a4950657ee6c56e6e817790"

    # patch to fix pkg-config flag sanitization
    # Backport issue https://golang.org/issue/77474, should be included in 1.26.1+.
    patch do
      url "https://github.com/golang/go/commit/28fbdf7acb4146b5bc3d88128e407d1344691839.patch?full_index=1"
      sha256 "2e05f7e16f2320685547a7ebb240163a8b7f1c7bf9d2f6dc4872ff8b27707a35"
    end
  end

  livecheck do
    url "https://go.dev/dl/?mode=json"
    regex(/^go[._-]?v?(\d+(?:\.\d+)+)[._-]src\.t.+$/i)
    strategy :json do |json, regex|
      json.map do |release|
        next if release["stable"] != true
        next if release["files"].none? { |file| file["filename"].match?(regex) }

        release["version"][/(\d+(?:\.\d+)+)/, 1]
      end
    end
  end

  bottle do
  end

  # Don't update this unless this version cannot bootstrap the new version.
  resource "gobootstrap" do
    checksums = {
      "darwin-arm64" => "f282d882c3353485e2fc6c634606d85caf36e855167d59b996dbeae19fa7629a",
      "darwin-amd64" => "6cc6549b06725220b342b740497ffd24e0ebdcef75781a77931ca199f46ad781",
      "linux-arm64"  => "74d97be1cc3a474129590c67ebf748a96e72d9f3a2b6fef3ed3275de591d49b3",
      "linux-amd64"  => "1fc94b57134d51669c72173ad5d49fd62afb0f1db9bf3f798fd98ee423f8d730",
    }

    version "1.24.13"

    on_arm do
      on_macos do
        url "https://go.dev/dl/go#{version}.darwin-arm64.tar.gz"
        sha256 checksums["darwin-arm64"]
      end
      on_linux do
        url "https://go.dev/dl/go#{version}.linux-arm64.tar.gz"
        sha256 checksums["linux-arm64"]
      end
    end
    on_intel do
      on_macos do
        url "https://go.dev/dl/go#{version}.darwin-amd64.tar.gz"
        sha256 checksums["darwin-amd64"]
      end
      on_linux do
        url "https://go.dev/dl/go#{version}.linux-amd64.tar.gz"
        sha256 checksums["linux-amd64"]
      end
    end
  end

  patch :DATA
  def install
    libexec.install Dir["*"]
    (buildpath/"gobootstrap").install resource("gobootstrap")
    ENV["GOROOT_BOOTSTRAP"] = buildpath/"gobootstrap"

    cd libexec/"src" do
      # Set portable defaults for CC/CXX to be used by cgo
      with_env(CC: "cc", CXX: "c++") { system "./make.bash" }
    end

    bin.install_symlink Dir[libexec/"bin/go*"]

    # Remove useless files.
    # Breaks patchelf because folder contains weird debug/test files
    rm_r(libexec/"src/debug/elf/testdata")
    # Binaries built for an incompatible architecture
    rm_r(libexec/"src/runtime/pprof/testdata")
    # Remove testdata with binaries for non-native architectures.
    rm_r(libexec/"src/debug/dwarf/testdata")
  end

  test do
    (testpath/"hello.go").write <<~GO
      package main

      import "fmt"

      func main() {
          fmt.Println("Hello World")
      }
    GO

    # Run go fmt check for no errors then run the program.
    # This is a a bare minimum of go working as it uses fmt, build, and run.
    system bin/"go", "fmt", "hello.go"
    assert_equal "Hello World\n", shell_output("#{bin}/go run hello.go")

    with_env(GOOS: "freebsd", GOARCH: "amd64") do
      system bin/"go", "build", "hello.go"
    end

    (testpath/"hello_cgo.go").write <<~GO
      package main

      /*
      #include <stdlib.h>
      #include <stdio.h>
      void hello() { printf("%s\\n", "Hello from cgo!"); fflush(stdout); }
      */
      import "C"

      func main() {
          C.hello()
      }
    GO

    # Try running a sample using cgo without CC or CXX set to ensure that the
    # toolchain's default choice of compilers work
    with_env(CC: nil, CXX: nil, CGO_ENABLED: "1") do
      assert_equal "Hello from cgo!\n", shell_output("#{bin}/go run hello_cgo.go")
    end
  end
end

__END__
--- a/src/crypto/x509/internal/macos/security.go
+++ b/src/crypto/x509/internal/macos/security.go
@@ -122,6 +122,25 @@
 }
 func x509_SecTrustEvaluateWithError_trampoline()
 
+//go:cgo_import_dynamic x509_SecTrustGetCertificateCount SecTrustGetCertificateCount "/System/Library/Frameworks/Security.framework/Versions/A/Security"
+
+func SecTrustGetCertificateCount(trustObj CFRef) int {
+	ret := syscall(abi.FuncPCABI0(x509_SecTrustGetCertificateCount_trampoline), uintptr(trustObj), 0, 0, 0, 0, 0)
+	return int(ret)
+}
+func x509_SecTrustGetCertificateCount_trampoline()
+
+//go:cgo_import_dynamic x509_SecTrustGetCertificateAtIndex SecTrustGetCertificateAtIndex "/System/Library/Frameworks/Security.framework/Versions/A/Security"
+
+func SecTrustGetCertificateAtIndex(trustObj CFRef, i int) (CFRef, error) {
+	ret := syscall(abi.FuncPCABI0(x509_SecTrustGetCertificateAtIndex_trampoline), uintptr(trustObj), uintptr(i), 0, 0, 0, 0)
+	if ret == 0 {
+		return 0, OSStatus{"SecTrustGetCertificateAtIndex", int32(ret)}
+	}
+	return CFRef(ret), nil
+}
+func x509_SecTrustGetCertificateAtIndex_trampoline()
+
 //go:cgo_import_dynamic x509_SecCertificateCopyData SecCertificateCopyData "/System/Library/Frameworks/Security.framework/Versions/A/Security"
 
 func SecCertificateCopyData(cert CFRef) ([]byte, error) {
@@ -134,14 +153,3 @@
 	return b, nil
 }
 func x509_SecCertificateCopyData_trampoline()
-
-//go:cgo_import_dynamic x509_SecTrustCopyCertificateChain SecTrustCopyCertificateChain "/System/Library/Frameworks/Security.framework/Versions/A/Security"
-
-func SecTrustCopyCertificateChain(trustObj CFRef) (CFRef, error) {
-	ret := syscall(abi.FuncPCABI0(x509_SecTrustCopyCertificateChain_trampoline), uintptr(trustObj), 0, 0, 0, 0, 0)
-	if ret == 0 {
-		return 0, OSStatus{"SecTrustCopyCertificateChain", int32(ret)}
-	}
-	return CFRef(ret), nil
-}
-func x509_SecTrustCopyCertificateChain_trampoline()

--- a/src/crypto/x509/internal/macos/security.s
+++ b/src/crypto/x509/internal/macos/security.s
@@ -21,7 +21,9 @@
 	JMP x509_SecTrustEvaluate(SB)
 TEXT ·x509_SecTrustEvaluateWithError_trampoline(SB),NOSPLIT,$0-0
 	JMP x509_SecTrustEvaluateWithError(SB)
+TEXT ·x509_SecTrustGetCertificateCount_trampoline(SB),NOSPLIT,$0-0
+	JMP x509_SecTrustGetCertificateCount(SB)
+TEXT ·x509_SecTrustGetCertificateAtIndex_trampoline(SB),NOSPLIT,$0-0
+	JMP x509_SecTrustGetCertificateAtIndex(SB)
 TEXT ·x509_SecCertificateCopyData_trampoline(SB),NOSPLIT,$0-0
 	JMP x509_SecCertificateCopyData(SB)
-TEXT ·x509_SecTrustCopyCertificateChain_trampoline(SB),NOSPLIT,$0-0
-	JMP x509_SecTrustCopyCertificateChain(SB)

--- a/src/crypto/x509/root_darwin.go
+++ b/src/crypto/x509/root_darwin.go
@@ -73,13 +73,12 @@
 	}
 
 	chain := [][]*Certificate{{}}
-	chainRef, err := macos.SecTrustCopyCertificateChain(trustObj)
-	if err != nil {
-		return nil, err
-	}
-	defer macos.CFRelease(chainRef)
-	for i := 0; i < macos.CFArrayGetCount(chainRef); i++ {
-		certRef := macos.CFArrayGetValueAtIndex(chainRef, i)
+	numCerts := macos.SecTrustGetCertificateCount(trustObj)
+	for i := 0; i < numCerts; i++ {
+		certRef, err := macos.SecTrustGetCertificateAtIndex(trustObj, i)
+		if err != nil {
+			return nil, err
+		}
 		cert, err := exportCertificate(certRef)
 		if err != nil {
 			return nil, err
