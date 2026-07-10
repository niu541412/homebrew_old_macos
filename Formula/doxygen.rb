class Doxygen < Formula
  desc "Generate documentation for several programming languages"
  homepage "https://www.doxygen.nl/"
  url "https://doxygen.nl/files/doxygen-1.17.0.src.tar.gz"
  mirror "https://downloads.sourceforge.net/project/doxygen/rel-1.17.0/doxygen-1.17.0.src.tar.gz"
  sha256 "fa4c3dd78785abc11ccc992bc9c01e7a8c3120fe14b8a8dfd7cefa7014530814"
  license "GPL-2.0-only"
  compatibility_version 1
  head "https://github.com/doxygen/doxygen.git", branch: "master"

  livecheck do
    url "https://www.doxygen.nl/download.html"
    regex(/href=.*?doxygen[._-]v?(\d+(?:\.\d+)+)[._-]src\.t/i)
  end

  bottle do
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "llvm" => :build

  uses_from_macos "flex" => :build, since: :big_sur
  uses_from_macos "python" => :build, since: :catalina

  patch :DATA
  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)
    system "cmake", "-S", ".", "-B", "build",
                    "-DPython_EXECUTABLE=#{which("python3")}",
                    "-DCMAKE_EXE_LINKER_FLAGS=#{formula_opt_lib("llvm")}/c++/#{shared_library("libc++")}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    system "cmake", "-S", ".", "-B", "build", "-Dbuild_doc=1", *std_cmake_args
    man1.install buildpath.glob("build/man/*.1")
  end

  test do
    system bin/"doxygen", "-g"
    system bin/"doxygen", "Doxyfile"
  end
end
__END__
--- a/src/dotrunner.cpp
+++ b/src/dotrunner.cpp
@@ -397,14 +397,15 @@ bool DotRunner::run(const DotJobs &dotJobs)
         {
           if (cmd.numDotFiles>0)
           {
-            auto process = [this,cmd,dirStr]() -> size_t
+            std::string tmpDirStr = dirStr;
+            auto process = [this,cmd,tmpDirStr]() -> size_t
             {
               int exitCode;
               if ((exitCode = Portable::system(m_dotExe, cmd.arguments, FALSE)) != 0)
               {
                 err_full(cmd.firstJob->srcFile, 1,
                     "Problems running dot: exit code={}, command='{}', dir='{}', arguments='{}'",
-                    exitCode, m_dotExe, dirStr, cmd.arguments);
+                    exitCode, m_dotExe, tmpDirStr, cmd.arguments);
               }
               return cmd.numDotFiles;
             };
