require 'spec_helper'

describe PublishToWeb::Config do
  let(:store)  { double 'store' }
  let(:config) { PublishToWeb::Config.new store: store }

  {
    hardware_id: 'ptw/hardware_id',
    license_key: 'ptw/license',
    node_name:   'ptw/node_name',
    private_key: 'ptw/publish_to_web_key_private',
    public_key:  'ptw/publish_to_web_key_public',
    success:     'ptw/success',
    error:       'ptw/error',
    smtp_host:   'smtp/host',
    smtp_sender: 'smtp/sender',
    smtp_user:   'smtp/username',
    smtp_pass:   'smtp/password',
    account_limit: 'soul/account_limit'
  }.each do |method_name, store_key|
    describe "##{method_name}" do
      it "has a getter" do
        expect(store).to receive(:get).with(store_key).and_return('val')
        expect(config.send(method_name)).to be == 'val'
      end

      it "has a setter" do
        expect(store).to receive(:set).with(store_key, 'val').and_return(true)
        expect(config.send("#{method_name}=", 'val')).to be_truthy
      end

      it "deletes keys if value is nil" do
        expect(store).to receive(:del).with(store_key).and_return(true)
        expect(config.send("#{method_name}=", nil)).to be_truthy
      end
    end
  end

  describe "support_identifier" do
    it "pulls 'system/support_identifier' from SKVS" do
      expect(store).to receive(:get).with('system/support_identifier').and_return("MAYA-1234")
      expect(config.support_identifier).to be == "MAYA-1234"
    end

    it "returns nil if support identifier is blank" do
      expect(store).to receive(:get).with('system/support_identifier').and_return(" ")
      expect(config.support_identifier).to be_nil
    end

    it "returns nil if support identifier is nil" do
      expect(store).to receive(:get).with('system/support_identifier').and_return(nil)
      expect(config.support_identifier).to be_nil
    end
  end

  describe "system_version" do
    it "composes the current system version from SKVS" do
      expect(store).to receive(:get).with('system/channel').and_return("stable")
      expect(store).to receive(:get).with('system/release_number').and_return("12345")
      expect(config.system_version).to be == "stable/12345"
    end

    it "falls back to 'unknown' when system/channel is blank" do
      expect(store).to receive(:get).with('system/channel').and_return(" ")
      expect(store).to receive(:get).with('system/release_number').and_return("12345")
      expect(config.system_version).to be == "unknown"
    end

    it "falls back to 'unknown' when system/channel is nil" do
      expect(store).to receive(:get).with('system/channel').and_return(nil)
      expect(store).to receive(:get).with('system/release_number').and_return("12345")
      expect(config.system_version).to be == "unknown"
    end

    it "falls back to 'unknown' when system/release_number is blank" do
      expect(store).to receive(:get).with('system/channel').and_return("stable")
      expect(store).to receive(:get).with('system/release_number').and_return(" ")
      expect(config.system_version).to be == "unknown"
    end

    it "falls back to 'unknown' when system/release_number is nil" do
      expect(store).to receive(:get).with('system/channel').and_return("stable")
      expect(store).to receive(:get).with('system/release_number').and_return(nil)
      expect(config.system_version).to be == "unknown"
    end    
  end

  describe "enabled?" do
    it "returns true if ptw is enabled" do
      expect(store).to receive(:get).with("ptw/control/enabled").and_return('val')
      expect(config.enabled?).to be == true
    end

    it "returns false if ptw is disabled" do
      expect(store).to receive(:get).with("ptw/control/enabled").and_return(nil)
      expect(config.enabled?).to be == false
    end
  end

  it "allows conditional setting of defaults" do
    expect(store).to receive(:get).with("ptw/license").and_return('configured')
    expect(store).not_to receive(:set).with("ptw/license", 'default')
    expect(config.license_key ||= 'default').to be == 'configured'

    expect(store).to receive(:get).with("ptw/hardware_id").and_return(nil)
    expect(store).to receive(:set).with("ptw/hardware_id", 'default').and_return('default')
    expect(config.hardware_id ||= 'default').to be == 'default' 
  end
end
