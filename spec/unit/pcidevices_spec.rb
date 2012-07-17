#!/usr/bin/env ruby

require 'spec_helper'

def pcidevices_fixtures(filename)
  File.read(fixtures('pcidevices', filename))
end

describe "pcidevice facts" do

  Facter.collection.loader.load(:pcidevices)

  describe "on linux" do
    Facter.fact(:kernel).stubs(:value).returns("Linux")

    test_cases = [
      #os,             #model,            #facts
      [ "debian_6_0_5", "dell_poweredge_r415", { "raid_bus_controller_0_vendor" => "LSI Logic / Symbios Logic",
                                                 "raid_bus_controller_0_device" => "LSI MegaSAS 9260",
                                                 "raid_bus_controller_0_driver" => "megaraid_sas",
                                                 "usb_controller_1_vendor"      => "ATI Technologies Inc" } ]
    ]

    test_cases.each do |os,model,facts|
      before :each do
        Facter.fact(:kernel).stubs(:value).returns('Linux')
        Facter::Util::Resolution.stubs(:exec).with("lspci -v -mm -k").returns(pcidevices_fixtures("lspci_#{os}_#{model}"))
        Facter.collection.loader.load(:pcidevices)
      end
      describe "on #{os} on machine #{model}" do
        facts.each do |fact,value|
          it "should report #{fact} with value #{value}" do
            Facter.fact(:"#{fact}").value.should == "#{value}"
          end
        end
      end
    end
  end
end
