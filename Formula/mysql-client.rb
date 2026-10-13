class MysqlClient < Formula
  desc "Open source relational database management system"
  homepage "https://github.com/mysql/mysql-server"
  url "https://cdn.mysql.com/Downloads/MySQL-26.7/mysql-26.7.0.tar.gz"
  mirror "https://repo.mysql.com/apt/ubuntu/pool/mysql-innovation/m/mysql-community/mysql-community_26.7.0.orig.tar.gz"
  sha256 "95e949183b94bbe39e70c6355e6c90d2a640a62ede996ca5f7a6a3e0827a3260"
  license "GPL-2.0-only" => { with: "Universal-FOSS-exception-1.0" }
  revision 1
  compatibility_version 1

  livecheck do
    formula "mysql"
  end

  bottle do
  end

  keg_only "it conflicts with mysql (which contains client libraries)"

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "pkgconf" => :build
  depends_on "libfido2"
  depends_on "openssl@4"
  depends_on "zlib-ng-compat" # Zlib 1.2.13+
  depends_on "zstd"

  uses_from_macos "curl"
  uses_from_macos "cyrus-sasl"
  uses_from_macos "libedit"

  on_ventura :or_older do
    depends_on "llvm" => :build
    fails_with :clang do
      cause <<~EOS
        std::string_view is not fully compatible with the libc++ shipped
        with ventura, so we need to use the LLVM libc++ instead.
      EOS
    end
  end

  on_linux do
    depends_on "libtirpc" => :build
    depends_on "krb5"
  end

  fails_with :gcc do
    version "9"
    cause "Requires C++20"
  end

  # Backports to support OpenSSL 4
  patch do
    url  "https://raw.githubusercontent.com/Homebrew/homebrew-core/refs/heads/main/Patches/mysql/26.7.0.diff"
    type :backport # https://github.com/mysql/mysql-server/commit/04ba58a223afc1339c75b080825042ad17a85b43
  end
  patch do
    url "https://github.com/mysql/mysql-server/commit/a045c23214ec225c49d9bc4caeea78d3d1f99ba9.patch?full_index=1"
    sha256 "b597781554b7fbcf4e13402dc8dca97bea59e059ed6e40e4eb71cd5c26a91ad9"
    type :backport
  end

  deny_network_access!
  patch :DATA

  def install
    # Disable ABI checking
    inreplace "cmake/abi_check.cmake", "RUN_ABI_CHECK 1", "RUN_ABI_CHECK 0" if OS.linux?

    if OS.mac? && MacOS.version <= :ventura
      ENV.append "LDFLAGS", "-L#{formula_opt_lib("llvm")}/unwind -lunwind"
      ENV.append "CXXFLAGS", "-include new"
      ENV.prepend_path "HOMEBREW_LIBRARY_PATHS", formula_opt_lib("llvm")/"c++"
    end

    # -DINSTALL_* are relative to `CMAKE_INSTALL_PREFIX` (`prefix`)
    args = %W[
      -DCOMPILATION_COMMENT=Homebrew
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MANDIR=share/man
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_AUTHENTICATION_CLIENT_PLUGINS=yes
      -DWITH_EDITLINE=system
      -DWITH_FIDO=system
      -DWITH_ZLIB=system
      -DWITH_ZSTD=system
      -DWITH_SSL=yes
      -DWITH_UNIT_TESTS=OFF
      -DWITHOUT_SERVER=ON
      -DWITH_MYSQL_CLIENT_TELEMETRY=OFF
    ]

    if OS.linux?
      args << "-DCURL_LIBRARY=#{formula_opt_lib("curl")}"
      args << "-DCURL_INCLUDE_DIR=#{formula_opt_include("curl")}"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mysql --version")
  end
end
__END__
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 438dff720c5..47863c17e23 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -1948,31 +1948,6 @@ MYSQL_CHECK_RAPIDJSON()
 MYSQL_CHECK_FIDO()
 MYSQL_CHECK_FIDO_DLLS()

-IF(APPLE)
-  GET_FILENAME_COMPONENT(HOMEBREW_BASE ${HOMEBREW_HOME} DIRECTORY)
-  IF(EXISTS ${HOMEBREW_BASE}/include/boost)
-    FOREACH(SYSTEM_LIB ICU LZ4 PROTOBUF ZSTD FIDO)
-      IF(WITH_${SYSTEM_LIB} STREQUAL "system")
-        MESSAGE(FATAL_ERROR
-          "WITH_${SYSTEM_LIB}=system is not compatible with Homebrew boost\n"
-          "MySQL depends on ${BOOST_PACKAGE_NAME} with a set of patches.\n"
-          "Including headers from ${HOMEBREW_BASE}/include "
-          "will break the build.\n"
-          "Please use WITH_${SYSTEM_LIB}=bundled\n"
-          "or do 'brew uninstall boost' or 'brew unlink boost'"
-          )
-      ENDIF()
-    ENDFOREACH()
-  ENDIF()
-  # Ensure that we look in /usr/local/include or /opt/homebrew/include
-  FOREACH(SYSTEM_LIB ICU LZ4 PROTOBUF ZSTD FIDO)
-    IF(WITH_${SYSTEM_LIB} STREQUAL "system")
-      INCLUDE_DIRECTORIES(SYSTEM ${HOMEBREW_BASE}/include)
-      BREAK()
-    ENDIF()
-  ENDFOREACH()
-ENDIF()
-
 IF(WITH_AUTHENTICATION_WEBAUTHN OR
   WITH_AUTHENTICATION_CLIENT_PLUGINS)
   IF(WITH_FIDO STREQUAL "system" AND
--- a/cmake/component.cmake
+++ b/cmake/component.cmake
@@ -98,10 +98,6 @@ MACRO(MYSQL_ADD_COMPONENT component_arg)
     # For APPLE: adjust path dependecy for SSL shared libraries.
     SET_PATH_TO_CUSTOM_SSL_FOR_APPLE(${target})
 
-    IF(APPLE)
-      TARGET_LINK_OPTIONS(${target} PRIVATE LINKER:-no_warn_duplicate_libraries)
-    ENDIF()
-
     IF(WIN32_CLANG AND WITH_ASAN)
       TARGET_LINK_LIBRARIES(${target}
         "${ASAN_LIB_DIR}/clang_rt.asan_dll_thunk-x86_64.lib")
--- a/cmake/plugin.cmake
+++ b/cmake/plugin.cmake
@@ -323,10 +323,6 @@ MACRO(MYSQL_ADD_PLUGIN plugin_arg)
       DEPENDS ${target})
   ENDIF()
 
-  IF(BUILD_PLUGIN AND ARG_MODULE_ONLY AND APPLE)
-    TARGET_LINK_OPTIONS(${target} PRIVATE LINKER:-no_warn_duplicate_libraries)
-  ENDIF()
-
   IF(BUILD_PLUGIN)
     ADD_DEPENDENCIES(plugin_all ${target})
     TARGET_COMPILE_FEATURES(${target} PUBLIC cxx_std_20)
--- a/cmake/libutils.cmake
+++ b/cmake/libutils.cmake
@@ -358,7 +358,6 @@ MACRO(MERGE_LIBRARIES_SHARED TARGET_ARG)
 
   IF(APPLE)
     SET_TARGET_PROPERTIES(${TARGET} PROPERTIES MACOSX_RPATH ON)
-    TARGET_LINK_OPTIONS(${TARGET} PRIVATE LINKER:-no_warn_duplicate_libraries)
   ENDIF()
 
   TARGET_LINK_OPTIONS(${TARGET} PRIVATE ${export_link_flags})
@@ -710,10 +709,6 @@ FUNCTION(ADD_SHARED_LIBRARY TARGET_ARG)
     ENDIF()
   ENDIF()
 
-  IF(APPLE)
-    TARGET_LINK_OPTIONS(${TARGET} PRIVATE LINKER:-no_warn_duplicate_libraries)
-  ENDIF()
-
   ADD_OBJDUMP_TARGET(show_${TARGET} "$<TARGET_FILE:${TARGET}>"
     DEPENDS ${TARGET})
 
--- a/cmake/mysql_add_executable.cmake
+++ b/cmake/mysql_add_executable.cmake
@@ -224,10 +224,6 @@ FUNCTION(MYSQL_ADD_EXECUTABLE target_arg)
     MACOS_ADD_DEVELOPER_ENTITLEMENTS(${target})
   ENDIF()
 
-  IF(APPLE)
-    TARGET_LINK_OPTIONS(${target} PRIVATE LINKER:-no_warn_duplicate_libraries)
-  ENDIF()
-
   IF(WIN32_CLANG AND WITH_ASAN)
     TARGET_LINK_LIBRARIES(${target}
       "${ASAN_LIB_DIR}/clang_rt.asan-x86_64.lib"
--- a/router/cmake/Plugin.cmake
+++ b/router/cmake/Plugin.cmake
@@ -89,10 +89,6 @@ FUNCTION(add_harness_plugin NAME)
   # .dylib, which we do not want, so we reset it here.
   ADD_LIBRARY(${NAME} SHARED ${_option_SOURCES})
   TARGET_COMPILE_FEATURES(${NAME} PUBLIC cxx_std_20)
-  IF(APPLE)
-    TARGET_LINK_OPTIONS(${NAME} PRIVATE LINKER:-no_warn_duplicate_libraries)
-  ENDIF()
-
   # add plugin to build-all target
   ADD_DEPENDENCIES(mysqlrouter_all ${NAME})
   IF(_option_OUTPUT_NAME)
--- a/storage/ndb/src/common/portlib/NdbTimestamp.cpp
+++ b/storage/ndb/src/common/portlib/NdbTimestamp.cpp
@@ -168,7 +168,11 @@ void NdbTimestamp_Reset() {
 
 std::timespec NdbTimestamp_GetCurrentTime() {
   std::timespec ts;
+#ifdef HAVE_CLOCK_GETTIME
+  require(clock_gettime(CLOCK_REALTIME, &ts) == 0);
+#else
   require(std::timespec_get(&ts, TIME_UTC) == TIME_UTC);
+#endif
   return ts;
 }
 
