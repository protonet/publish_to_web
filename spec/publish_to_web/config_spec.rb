require 'spec_helper'

describe PublishToWeb::Config do
  let(:store)  { double 'store' }
  let(:config) { PublishToWeb::Config.new store: store }

  {
    hardware_id: 'hardware_id',
    license_key: 'license',
    hostname:    'hostname',
    node_name:   'nodenames/publish_to_web',
    private_key: 'publish_to_web_key',
    public_key:  'publish_to_web_key.pub'
  }.each do |method_name, store_key_fragment|
    store_key = File.join 'ptw', store_key_fragment

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
end
