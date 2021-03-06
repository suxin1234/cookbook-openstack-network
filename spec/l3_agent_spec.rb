# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do

  describe 'ubuntu' do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
        n.set['openstack']['network']['l3']['external_network_bridge_interface'] = 'eth1'
      end
      @chef_run.converge 'openstack-network::l3_agent'
    end

    it 'does not install neutron l3 package when nova networking' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      chef_run.converge 'openstack-network::l3_agent'
      expect(chef_run).to_not install_package 'neutron-l3-agent'
    end

    it 'installs quamtum l3 package' do
      expect(@chef_run).to install_package 'neutron-l3-agent'
    end

    describe 'l3_agent.ini' do

      before do
        @file = @chef_run.template '/etc/neutron/l3_agent.ini'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'it has ovs driver' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver')
      end

      it 'sets fuzzy delay to default' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'periodic_fuzzy_delay = 5')
      end

      it 'it does not set a nil router_id' do
        expect(@chef_run).not_to render_file(@file.name).with_content(/^router_id =/)
      end

      it 'it does not set a nil router_id' do
        expect(@chef_run).not_to render_file(@file.name).with_content(
          /^gateway_external_network_id =/)
      end
    end

    describe 'create ovs bridges' do
      before do
        neutron_stubs
        @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
          n.set['openstack']['compute']['network']['service_type'] = 'neutron'
        end
      end

      cmd = 'ovs-vsctl add-br br-ex && ovs-vsctl add-port br-ex eth1'

      it "doesn't add the external bridge if it already exists" do
        stub_command(/ovs-vsctl show/).and_return(true)
        stub_command(/ip link show eth1/).and_return(true)
        @chef_run.converge 'openstack-network::l3_agent'
        expect(@chef_run).not_to run_execute(cmd)
      end

      it "doesn't add the external bridge if the physical interface doesn't exist" do
        stub_command(/ovs-vsctl show/).and_return(true)
        stub_command(/ip link show eth1/).and_return(false)
        @chef_run.converge 'openstack-network::l3_agent'
        expect(@chef_run).not_to run_execute(cmd)
      end

      it 'adds the external bridge if it does not yet exist' do
        stub_command(/ovs-vsctl show/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)
        @chef_run.converge 'openstack-network::l3_agent'
        expect(@chef_run).to run_execute(cmd)
      end

      it 'adds the external bridge if the physical interface exists' do
        stub_command(/ovs-vsctl show/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)
        @chef_run.converge 'openstack-network::l3_agent'
        expect(@chef_run).to run_execute(cmd)
      end
    end
  end
end
