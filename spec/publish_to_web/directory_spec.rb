require 'spec_helper'

describe PublishToWeb::Directory do
  let(:directory) do 
    PublishToWeb::Directory.new(
      host: 'https://example.com',
      config: PublishToWeb::Config.new,
      logger: Logger.new(STDOUT).tap {|l| l.level = Logger::ERROR }
    )
  end
  let(:config) { directory.config }

  describe "SSH Tunnel Directory Info" do
    def stub_info!
      config.license_key = 'license'

      expect(HTTP).to receive(:get).
        with('https://example.com/info',
          params: { license_key: config.license_key }).
        and_return(
          OpenStruct.new(
            status: 200, 
            body: JSON.dump(port: 1234, pubkey_sha1: 'foobar', node_name: 'thename')
          )
        )
    end

    describe "#remote_port" do
      it "corresponds to info fetched from directory" do
        stub_info!
        expect(directory.remote_port).to be == 1234
      end
    end

    describe "#directory_public_key_sha1" do
      it "corresponds to info fetched from directory" do
        stub_info!
        expect(directory.directory_public_key_sha1).to be == 'foobar'
      end
    end

    describe "#node_name" do
      it "corresponds to info fetched from directory" do
        stub_info!
        expect(directory.node_name).to be == 'thename'
      end
    end

    it "raises an HttpResponseError on failure" do
      config.license_key = 'license'

      expect(HTTP).to receive(:get).
        with('https://example.com/info', kind_of(Hash)).
        and_return(OpenStruct.new(status: 403))

      expect {
        directory.node_name
      }.to raise_error PublishToWeb::Directory::HttpResponseError, /Failed to get connection info from directory/
    end
  end

  describe "SSH Identity" do
    it "uses the configured key pair if the pubkey_sha1 matches the directory" do
      SSHKey.generate(type: 'rsa', bits: 1024).tap do |key|
        config.private_key = key.private_key
        config.public_key  = key.ssh_public_key
      end

      allow(directory).to receive(:directory_public_key_sha1).
        and_return(Digest::SHA1.hexdigest(config.public_key))

      expect(directory.private_key).to be == config.private_key
      expect(directory.public_key).to be == config.public_key
    end

    describe "re-keying" do
      def expect_rekeying!
        config.license_key = 'license'

        key = SSHKey.generate(type: 'rsa', bits: 1024)

        allow(SSHKey).to receive(:generate).
          and_return(key)

        expect(HTTP).to receive(:post).
          with('https://example.com/set_public_key',
            form: { license_key: directory.license_key, public_key: key.ssh_public_key }).
          and_return(
            OpenStruct.new(status: 200)
          )

        expect(HTTP).to receive(:get).
          with('https://example.com/info',
            params: { license_key: directory.license_key }).
          and_return(
            OpenStruct.new(
              status: 200, 
              body: JSON.dump(port: 1234, pubkey_sha1: Digest::SHA1.hexdigest(key.ssh_public_key), node_name: 'thename')
            )
          )

        expect(directory.public_key).to be == key.ssh_public_key.strip
        expect(directory.private_key).to be == key.private_key.strip
      end

      it "re-issues a new key pair if none is stored" do
        expect_rekeying!
      end

      it "re-issues a new key pair if the pubkey_sha1 does not match" do
        expect_rekeying!

        # Break the keypair wie just issued by forging an invalid sha1 on the local pubkey
        allow(Digest::SHA1).to receive(:hexdigest).
          with(config.public_key).
          and_return('really wrong')

        expect_rekeying!
      end

      it "re-issues a new key pair if the pubkey does not match the private one" do
        # Gotta generate this one *before* we stub the generate method ^^
        fake_key = SSHKey.generate(type: 'rsa', bits: 1024).private_key

        expect_rekeying!

        # Break the keypair we just issued by fabricating a local key mismatch
        config.private_key = fake_key

        expect_rekeying!
      end

      it "raises an HttpResponseError on failure" do
        config.license_key = 'license'

        expect(HTTP).to receive(:post).
          with('https://example.com/set_public_key', kind_of(Hash)).
          and_return(OpenStruct.new(status: 403))

        expect {
          directory.public_key
        }.to raise_error PublishToWeb::Directory::HttpResponseError, /Failed to register identity with directory/
      end
    end
  end

  describe "Hardware ID and Licensing" do
    describe "#hardware_id" do
      it "returns the hardware_id from config if present" do
        config.hardware_id = 'foobar'
        expect(directory.hardware_id).to be == 'foobar'
      end

      it "generates and stores a new hardware_id if not configured" do
        expect(SecureRandom).to receive(:uuid).and_return("exceptionally-unique")
        expect(directory.hardware_id).to be == 'aal-exceptionally-unique'
        expect(config.hardware_id).to be == 'aal-exceptionally-unique'
      end
    end

    describe "#license_key" do
      it "returns the license_key from config if present" do
        config.license_key = 'my_key'
        expect(directory.license_key).to be == 'my_key'
      end

      it "requests a new license_key from the directory if missing and stores it" do
        expect(HTTP).to receive(:get).
          with('https://example.com/create_license',
            params: { hardware_id: directory.hardware_id }).
          and_return(
            OpenStruct.new(status: 200, body: JSON.dump(license_key: 'datlicense'))
          )

        expect(directory.license_key).to be == 'datlicense'
        expect(config.license_key).to be == 'datlicense'
      end

      it "raises an HttpResponseError on failure" do
        expect(HTTP).to receive(:get).
          with('https://example.com/create_license', kind_of(Hash)).
          and_return(OpenStruct.new(status: 403))

        expect {
          directory.license_key
        }.to raise_error PublishToWeb::Directory::HttpResponseError, /Failed to create license in directory/
      end
    end
  end

  describe "#set_node_name" do
    it "sends the given node name to the directory and refreshes info" do
      config.license_key = 'license'

      expect(HTTP).to receive(:post).
        with('https://example.com/set_node_name',
          form: { license_key: directory.license_key, node_name: 'newname' }).
        and_return(
          OpenStruct.new(status: 200)
        )

      expect(HTTP).to receive(:get).
        with('https://example.com/info',
          params: { license_key: config.license_key }).
        and_return(
          OpenStruct.new(
            status: 200, 
            body: JSON.dump(port: 1234, pubkey_sha1: 'foobar', node_name: 'thename')
          )
        )

      directory.set_node_name 'newname'
    end

    it "raises an HttpResponseError on failure" do
      config.license_key = 'license'

      expect(HTTP).to receive(:post).
        with('https://example.com/set_node_name', kind_of(Hash)).
        and_return(OpenStruct.new(status: 403))

      expect {
        directory.set_node_name 'newname'
      }.to raise_error PublishToWeb::Directory::HttpResponseError, /Failed to set new node name in directory/
    end
  end

  describe "Version" do
    describe "#version" do
      it "is hard-coded" do
        expect(directory.version).to be == "platform-alpha"
      end
    end

    describe "#set_version" do
      it "sends the version to the directory" do
        config.license_key = 'license'

        expect(HTTP).to receive(:post).
          with('https://example.com/set_version',
            form: { license_key: directory.license_key, version: directory.version }).
          and_return(
            OpenStruct.new(status: 200)
          )

        directory.set_version
      end

      it "raises an HttpResponseError on failure" do
        config.license_key = 'license'

        expect(HTTP).to receive(:post).
          with('https://example.com/set_version', kind_of(Hash)).
          and_return(OpenStruct.new(status: 403))

        expect {
          directory.set_version
        }.to raise_error PublishToWeb::Directory::HttpResponseError, /Failed to set version in directory/
      end
    end
  end

end
