class Pulseaudio < Formula
  desc "Sound system for POSIX OSes"
  homepage "https://wiki.freedesktop.org/www/Software/PulseAudio/"
  url "https://www.freedesktop.org/software/pulseaudio/releases/pulseaudio-13.0.tar.xz"
  sha256 "961b23ca1acfd28f2bc87414c27bb40e12436efcf2158d29721b1e89f3f28057"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.1-or-later", "BSD-3-Clause"]
  head "https://gitlab.freedesktop.org/pulseaudio/pulseaudio.git", branch: "master"

  # The regex here avoids x.99 releases, as they're pre-release versions.
  livecheck do
    url :stable
    regex(/href=["']?pulseaudio[._-]v?((?!\d+\.9\d+)\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 high_sierra: "a5c5442b2118b9e3e3b2cbd8a8a700a121e9264b11c7096a3b3c42ce780a7a0b"
  end

  depends_on "pkg-config" => :build
  depends_on "json-c"
  depends_on "libsndfile"
  depends_on "libsoxr"
  depends_on "libtool"
  depends_on "openssl@1.1"
  depends_on "speexdsp"

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-coreaudio-output
      --disable-neon-opt
      --disable-nls
      --disable-x11
      --with-mac-sysroot=#{MacOS.sdk_path}
      --with-mac-version-min=#{MacOS.version}
    ]

    if build.head?
      # autogen.sh runs bootstrap.sh then ./configure
      system "./autogen.sh", *args
    else
      system "./configure", *args
    end
    system "make", "install"
  end

  service do
    run [opt_bin/"pulseaudio", "--exit-idle-time=-1", "--verbose"]
    keep_alive true
    log_path var/"log/pulseaudio.log"
    error_log_path var/"log/pulseaudio.log"
  end

  test do
    assert_match "module-sine", shell_output("#{bin}/pulseaudio --dump-modules")
  end
end
