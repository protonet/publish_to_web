require 'spec_helper'

describe PublishToWeb::Config do
  let(:store)  { double 'store' }
  let(:config) { PublishToWeb::Config.new store: store }

  {
    hardware_id: 'ptw/hardware_id',
    license_key: 'ptw/license',
    node_name:   'hostname',
    private_key: 'ptw/publish_to_web_key',
    public_key:  'ptw/publish_to_web_key.pub',
    success:     'ptw/success',
    error:       'ptw/error'
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
    end
  end

  describe "enabled?" do
    it "wraps a boolean query" do
      expect(store).to receive(:get).with("ptw/enabled").and_return('val')
      expect(config.enabled?).to be == true
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
