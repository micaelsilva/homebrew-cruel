class CaCertificates < Formula
  desc "Mozilla CA certificate store"
  homepage "https://curl.se/docs/caextract.html"
  url "https://curl.se/ca/cacert-2024-09-24.pem"
  sha256 "189d3cf6d103185fba06d76c1af915263c6d42225481a1759e853b33ac857540"

  bottle do
    sha256 "212f2576348d5f5797d8d3905eb70d0d9bf8829345bce9e20e2fd0336f344648" => :all
  end

  def install
    pkgshare.install "cacert-#{version}.pem" => "cacert.pem"
  end

  def post_install
    ohai "Regenerating CA certificate bundle from keychain, this may take a while..."

    keychains = %w[
      /Library/Keychains/System.keychain
      /System/Library/Keychains/SystemRootCertificates.keychain
    ]

    certs_list = Utils.safe_popen_read("/usr/bin/security", "find-certificate", "-a", "-p", *keychains)
    certs = certs_list.scan(
      /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m,
    )

    # Check that the certificate has not expired
    valid_certs = certs.select do |cert|
      begin
        Utils.safe_popen_write("/usr/bin/openssl", "x509", "-inform", "pem", "-checkend", "0", "-noout") do |openssl_io|
          openssl_io.write(cert)
        end
      rescue ErrorDuringExecution
        # Expired likely.
        next
      end

      # Only include certs that have are designed to act as a SSL root.
      purpose = Utils.safe_popen_write("/usr/bin/openssl", "x509", "-inform", "pem",
                                                                   "-purpose",
                                                                   "-noout") do |openssl_io|
        openssl_io.write(cert)

      end
      purpose.include?("SSL server CA : Yes")
    end

    # Check that the certificate is trusted in keychain
    trusted_certs = begin
      tmpfile = Tempfile.new

      verify_args = %W[
        -l -L
        -c #{tmpfile.path}
        -p ssl
      ]

      valid_certs.select do |cert|
        tmpfile.rewind
        tmpfile.write cert
        tmpfile.truncate cert.size
        tmpfile.flush
        Utils.safe_popen_read("/usr/bin/security", "verify-cert", *verify_args)
        true
      rescue ErrorDuringExecution
        # Invalid.
        false
      end
    ensure
      tmpfile&.close!
    end

    # Get SHA256 fingerprints for all trusted certs
    fingerprints = trusted_certs.to_set do |cert|
      Utils.safe_popen_write("/usr/bin/openssl", "x509", "-inform", "pem",
                                                         "-fingerprint",
                                                         "-sha256",
                                                         "-noout") do |openssl_io|
        openssl_io.write(cert)
      end
    end

    # Now process Mozilla certs we downloaded.
    pem_certs_list = File.read(pkgshare/"cacert.pem")
    pem_certs = pem_certs_list.scan(
      /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m,
    )

    # Append anything new.
    trusted_certs += pem_certs.select do |cert|
      fingerprint = Utils.safe_popen_write("/usr/bin/openssl", "x509", "-inform", "pem",
                                                                       "-fingerprint",
                                                                       "-sha256",
                                                                       "-noout") do |openssl_io|
        openssl_io.write(cert)
      end
      fingerprints.add?(fingerprint)
    end

    pkgetc.mkpath
    (pkgetc/"cert.pem").atomic_write(trusted_certs.join("\n") << "\n")
  end

  test do
    assert_path_exists pkgshare/"cacert.pem"
    assert_path_exists pkgetc/"cert.pem"
    assert compare_file(pkgshare/"cacert.pem", pkgetc/"cert.pem") if OS.linux?
  end
end

