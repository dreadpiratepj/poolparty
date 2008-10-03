require File.dirname(__FILE__) + '/../spec_helper'
require "ftools"

module Hype
  def hyper
    "beatnick"
  end
  def instances_list
    []
  end
  register_remote_base :Hype
end
class TestClass
  include Remote
end

describe "Remote" do
  before(:each) do
    @tc = TestClass.new
  end
  it "should have the method 'using'" do
    @tc.respond_to?(:using).should == true
  end
  it "should include the module with using" do
    @tc.should_receive(:extend).with("Hype".preserved_module_constant).once
    @tc.using :hype
  end
  it "should keep a list of the remote_bases" do
    @tc.stub!(:remote_bases).and_return [:ec2, :hype]
    @tc.available_bases.should == [:ec2, :hype]
  end
  it "should be able to register a new base" do
    @tc.remote_bases.should_receive(:<<).with(:hockey).and_return true
    @tc.register_remote_base("Hockey")
  end
  it "should not extend the module if the remote base isn't found" do
    @tc.should_not_receive(:extend)
    hide_output do
      @tc.using :paper
    end    
  end
  describe "when including" do
    it "should be able to say if it is using a remote base with using_remoter?" do
      @tc.using :hype
      @tc.using_remoter?.should_not == nil
    end
    it "should ask if it is using_remoter? when calling using" do
      @tc.should_receive(:using_remoter?).once
      @tc.using :hype
    end
    it "should only include the remote class once" do
      @tc.should_receive(:extend).with(Hype).once
      @tc.using :hype
      @tc.using :hype
      @tc.using :hype
    end
  end
  describe "after using" do
    before(:each) do
      @tc = TestClass.new
      stub_list_from_remote_for(@tc)
      @tc.using :hype
    end
    it "should now have the methods available from the module" do
      @tc.respond_to?(:hyper).should == true
    end
    it "should raise an exception because the launch_new_instance! is not defined" do
      lambda {
        @tc.launch_new_instance!
      }.should raise_error
    end
    it "should not raise an exception because instances_list is defined" do
      lambda {
        @tc.remote_instances_list
      }.should_not raise_error
    end
    it "should run hyper" do
      @tc.hyper.should == "beatnick"
    end
  end
  describe "methods" do
    before(:each) do
      @tc = TestClass.new
      @tc.using :ec2
      
      @tc.reset!
      @tc.stub!(:minimum_instances).and_return 3
      @tc.stub!(:maximum_instances).and_return 5
      
      stub_list_from_remote_for(@tc)
      stub_list_of_instances_for(@tc)
    end
    describe "minimum_number_of_instances_are_running?" do
      it "should be false if there aren't" do
        @tc.minimum_number_of_instances_are_running?.should == false
      end
      it "should be true if there are" do
        add_stub_instance_to(@tc, 8)
        @tc.minimum_number_of_instances_are_running?.should == true
      end
    end
    describe "can_shutdown_an_instance?" do
      it "should say false because minimum instances are not running" do
        @tc.can_shutdown_an_instance?.should == false
      end
      it "should say we false if only the minimum instances are running" do
        add_stub_instance_to(@tc, 8)
        @tc.can_shutdown_an_instance?.should == false
      end
      it "should say true because the minimum instances + 1 are running" do
        add_stub_instance_to(@tc, 8)
        add_stub_instance_to(@tc, 9)
        @tc.can_shutdown_an_instance?.should == true
      end
    end
    describe "request_launch_new_instances" do
      it "should requiest to launch a new instance 3 times" do
        @tc.should_receive(:launch_new_instance!).exactly(3).and_return "launched"
        @tc.request_launch_new_instances(3)
      end
      it "should return a list of hashes" do
        @tc.should_receive(:launch_new_instance!).exactly(3).and_return({:instance_id => "i-dasfasdf"})
        @tc.request_launch_new_instances(3).first.class.should == Hash
      end
    end
    describe "can_start_a_new_instance?" do
      it "should be true because the maximum instances are not running" do
        @tc.can_start_a_new_instance?.should == true
      end
      it "should say that we cannot start a new instance because we are at the maximum instances" do
        add_stub_instance_to(@tc, 5)
        add_stub_instance_to(@tc, 6)
        add_stub_instance_to(@tc, 7)
        @tc.can_start_a_new_instance?.should == false
      end
    end
    describe "maximum_number_of_instances_are_not_running?" do
      it "should be true because the maximum are not running" do
        @tc.maximum_number_of_instances_are_not_running?.should == true
      end
      it "should be false because the maximum are running" do
        add_stub_instance_to(@tc, 5)
        add_stub_instance_to(@tc, 6)
        add_stub_instance_to(@tc, 7)
        @tc.maximum_number_of_instances_are_not_running?.should == false
      end
    end
    describe "request_launch_one_instance_at_a_time" do
      before(:each) do
        Kernel.stub!(:sleep).and_return true
        remove_stub_instance_from(@tc, 4)
        remove_stub_instance_from(@tc, 6)
        @tc.stub!(:launch_new_instance!).and_return {}
      end
      it "should call reset! once" do        
        @tc.should_receive(:reset!).once
        @tc.request_launch_one_instance_at_a_time
      end
      it "should not call wait if there are no pending instances" do
        Kernel.should_not_receive(:sleep)
        @tc.request_launch_one_instance_at_a_time
      end
      # TODO: Stub methods with wait
    end
    describe "launch_minimum_number_of_instances" do
      it "should not call minimum_number_of_instances_are_running? if if cannot start a new instance" do
        @tc.stub!(:can_start_a_new_instance?).and_return false
        @tc.should_not_receive(:minimum_number_of_instances_are_running?)
        @tc.launch_minimum_number_of_instances
      end
      # TODO: Stub methods with wait
    end
    describe "request_termination_of_non_master_instance" do
      it "should reject the master instance from the list of instances (we should never shut down the master unless shutting down the cloud)" do
        @master = @tc.list_of_running_instances.select {|a| a.master? }.first
        @tc.should_not_receive(:terminate_instance!).with(@master).and_return true
        @tc.should_receive(:terminate_instance!).once
        @tc.request_termination_of_non_master_instance
      end
    end
    describe "should_expand_cloud?" do
    end
    describe "should_contract_cloud?" do
    end
    describe "expand_cloud_if_necessary" do
      before(:each) do
        @tc.stub!(:request_launch_new_instances).and_return true
        @tc.stub!(:can_start_a_new_instance).and_return true
      end
      it "should receive can_start_a_new_instance?" do
        @tc.should_receive(:can_start_a_new_instance?).once
      end
      it "should see if we should expand the cloud" do
        @tc.should_receive(:should_expand_cloud?).once.and_return false
      end
      it "should call request_launch_new_instances if we should_expand_cloud?" do
        @tc.should_receive(:should_expand_cloud?).once.and_return true
        @tc.should_receive(:request_launch_new_instances).once.and_return true        
      end
      after(:each) do
        @tc.expand_cloud_if_necessary
      end
    end
    describe "contract_cloud_if_necessary" do
      before(:each) do
        @tc.stub!(:request_termination_of_non_master_instance).and_return true
        @tc.stub!(:can_shutdown_an_instance?).and_return true
      end
      it "should receive can_shutdown_an_instance?" do
        @tc.should_receive(:can_shutdown_an_instance?).once
      end
      it "should see if we should contract the cloud" do
        @tc.should_receive(:should_contract_cloud?).once.and_return false
      end
      it "should call request_termination_of_non_master_instance if we should_contract_cloud?" do
        @tc.should_receive(:should_contract_cloud?).once.and_return true
        @tc.should_receive(:request_termination_of_non_master_instance).once.and_return true        
      end
      after(:each) do
        @tc.contract_cloud_if_necessary
      end
    end
    describe "rsync_storage_files_to" do
      before(:each) do
        Kernel.stub!(:system).and_return true
        @tc.extend CloudResourcer
        @tc.stub!(:keypair).and_return "funky"
      end
      it "should raise an exception if it cannot find the keypair" do
        lambda {
          @tc.rsync_storage_files_to(@tc.master)
        }.should raise_error
      end
      it "should call exec on the kernel" do
        ::File.stub!(:exists?).with("#{File.expand_path(Base.base_keypair_path)}/id_rsa-funky").and_return true
        lambda {
          @tc.rsync_storage_files_to(@tc.master)
        }.should_not raise_error
      end
    end
  end
end