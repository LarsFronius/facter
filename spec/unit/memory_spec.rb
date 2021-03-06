#!/usr/bin/env rspec

require 'spec_helper'

describe "Memory facts" do
  after do
    Facter.clear
  end

  describe "on Darwin" do
    before(:each) do
      Facter.fact(:kernel).stubs(:value).returns("Darwin")
      Facter::Util::Resolution.stubs(:exec).with('sysctl -n hw.memsize').returns('8589934592')
      sample_vm_stat = <<VMSTAT
Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                          28430.
Pages active:                      1152576.
Pages inactive:                     489054.
Pages speculative:                    7076.
Pages wired down:                   418217.
"Translation faults":           1340091228.
Pages copy-on-write:              16851357.
Pages zero filled:               665168768.
Pages reactivated:                 3082708.
Pageins:                          13862917.
Pageouts:                          1384383.
Object cache: 14 hits of 2619925 lookups (0% hit rate)
VMSTAT
      Facter::Util::Resolution.stubs(:exec).with('vm_stat').returns(sample_vm_stat)
      Facter::Util::Resolution.stubs(:exec).with('sysctl vm.swapusage').returns("vm.swapusage: total = 64.00M  used = 1.00M  free = 63.00M  (encrypted)")

      Facter.collection.loader.load(:memory)
    end

    it "should return the current swap size" do
      Facter.fact(:swapsize).value.should == "64.00 MB"
    end

    it "should return the current swap free" do
      Facter.fact(:swapfree).value.should == "63.00 MB"
    end

    it "should return whether swap is encrypted" do
      Facter.fact(:swapencrypted).value.should == true
    end
    
    it "should return the memorysize" do
      Facter.fact(:memorysize).value.should == "8.00 GB"
    end
    
    it "should return the memoryfree" do
      Facter.fact(:memoryfree).value.should == "138.70 MB"
    end
    
    after(:each) do
      Facter.clear
    end
  end

  describe "on OpenBSD" do
    before :each do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("OpenBSD")

      swapusage = "total: 148342k bytes allocated = 0k used, 148342k available"
      Facter::Util::Resolution.stubs(:exec).with('swapctl -s').returns(swapusage)

      vmstat = <<EOS
 procs  memory     page          disks  traps      cpu
 r b w  avm   fre  flt  re  pi  po  fr  sr cd0 sd0  int   sys   cs us sy id
 0 0 0  11048  181028   39   0   0   0   0   0   0   1  3  90   17  0  0 100
EOS
      Facter::Util::Resolution.stubs(:exec).with('vmstat').returns(vmstat)

      Facter::Util::Resolution.stubs(:exec).with("sysctl hw.physmem | cut -d'=' -f2").returns('267321344')

      Facter.collection.loader.load(:memory)
    end

    after :each do
      Facter.clear
    end

    it "should return the current swap free" do
      Facter.fact(:swapfree).value.should == "144.87 MB"
    end

    it "should return the current swap size" do
      Facter.fact(:swapsize).value.should == "144.87 MB"
    end

    it "should return the current memorysize" do
      Facter.fact(:memorysize).value.should == "254.94 MB"
    end
  end
  
  describe "on Solaris" do
    before(:each) do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("SunOS")
      sample_prtconf = <<PRTCONF
System Configuration:  Sun Microsystems  sun4u
Memory size: 2048 Megabytes
System Peripherals (Software Nodes):

PRTCONF
      Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/prtconf 2>/dev/null').returns sample_prtconf
      
      vmstat_lines = <<VMSTAT
 kthr      memory            page            disk          faults      cpu
 r b w   swap  free  re  mf pi po fr de sr s0 s3 -- --   in   sy   cs us sy id
 0 0 0 1154552 476224 8  19  0  0  0  0  0  0  0  0  0  460  294  236  1  2 97
VMSTAT
      Facter::Util::Resolution.stubs(:exec).with('vmstat').returns(vmstat_lines)
    end
    
    after(:each) do
      Facter.clear
    end    
    
    describe "when single swap exists" do
      before(:each) do
        sample_swap_line = <<SWAP
swapfile             dev  swaplo blocks   free
/dev/swap           4294967295,4294967295     16 2097136 2097136
SWAP
        Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/swap -l').returns sample_swap_line

        Facter.collection.loader.load(:memory)
      end

      it "should return the current memory size" do      
        Facter.fact(:memorysize).value.should == "2.00 GB"
      end
      
      it "should return the current memory free" do
        Facter.fact(:memoryfree).value.should == "465.06 MB"
      end
      
      it "should return the current swap free" do
        Facter.fact(:swapfree).value.should == "1023.99 MB"
      end
      
      it "should return the current swap size" do
        Facter.fact(:swapsize).value.should == "1023.99 MB"
      end
    end

    describe "when multiple swaps exist" do
      before(:each) do
        sample_swap_line = <<SWAP
swapfile             dev  swaplo blocks   free
/dev/swap           4294967295,4294967295     16 2097136 2097136
/dev/swap2          4294967295,4294967295     16 2097136 2097136
SWAP
        Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/swap -l').returns sample_swap_line
        Facter.collection.loader.load(:memory)
      end
      
      it "should return the current memory size" do      
        Facter.fact(:memorysize).value.should == "2.00 GB"
      end
      
      it "should return the current memory free" do
        Facter.fact(:memoryfree).value.should == "465.06 MB"
      end
      
      it "should total the swap free" do
        Facter.fact(:swapfree).value.should == "2.00 GB"
      end
      
      it "should total the swap size" do
        Facter.fact(:swapsize).value.should == "2.00 GB"
      end
    end
    
    describe "when no swap exists" do
      before(:each) do
        Facter::Util::Resolution.stubs(:exec).with('/usr/sbin/swap -l').returns ""

        Facter.collection.loader.load(:memory)
      end
      
      it "should return the current memory size" do      
        Facter.fact(:memorysize).value.should == "2.00 GB"
      end
      
      it "should return the current memory free" do
        Facter.fact(:memoryfree).value.should == "465.06 MB"
      end
      
      it "should return 0 for the swap free" do
        Facter.fact(:swapfree).value.should == "0.00 kB"
      end
      
      it "should return 0 for the swap size" do
        Facter.fact(:swapsize).value.should == "0.00 kB"
      end
    end
  end

  describe "on DragonFly BSD" do
    before :each do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("dragonfly")

      swapusage = "total: 148342k bytes allocated = 0k used, 148342k available"
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n hw.pagesize').returns("4096")
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n vm.swap_size').returns("128461")
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n vm.swap_anon_use').returns("2635")
      Facter::Util::Resolution.stubs(:exec).with('/sbin/sysctl -n vm.swap_cache_use').returns("0")

      vmstat = <<EOS
 procs    memory    page          disks   faults    cpu
 r b w   avm  fre  flt  re  pi  po  fr  sr da0 sg1   in   sy  cs us sy id
 0 0 0   33152  13940 1902120 2198 53119 11642 6544597 5460994   0   0 6148243 7087927 3484264  0  1 9
EOS
      Facter::Util::Resolution.stubs(:exec).with('vmstat').returns(vmstat)

      Facter::Util::Resolution.stubs(:exec).with("sysctl -n hw.physmem").returns('248512512')

      Facter.collection.loader.load(:memory)
    end

    after :each do
      Facter.clear
    end

    it "should return the current swap free" do
      Facter.fact(:swapfree).value.should == "491.51 MB"
    end

    it "should return the current swap size" do
      Facter.fact(:swapsize).value.should == "501.80 MB"
    end

    it "should return the current memorysize" do
      Facter.fact(:memorysize).value.should == "237.00 MB"
    end
  end
  
  describe "on FreeBSD" do 
    before(:each) do 
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("FreeBSD")

      sample_vmstat = <<VM_STAT
 procs      memory      page                    disks     faults         cpu
 r b w     avm    fre   flt  re  pi  po    fr  sr da0 cd0   in   sy   cs us sy id
 1 0 0  207600  656640    10   0   0   0    13   0   0   0   51  164  257  0  1 99
VM_STAT
      Facter::Util::Resolution.stubs(:exec).with('vmstat -H').returns sample_vmstat
      sample_physmem = <<PHYSMEM
1056276480
PHYSMEM
      Facter::Util::Resolution.stubs(:exec).with('sysctl -n hw.physmem').returns sample_physmem
    end
    
    after(:each) do 
      Facter.clear 
    end 
    
    describe "with no swap" do 
      before(:each) do 
        sample_swapinfo = <<SWAP
Device          1K-blocks     Used    Avail Capacity
SWAP
        Facter::Util::Resolution.stubs(:exec).with('swapinfo -k').returns sample_swapinfo

        Facter.collection.loader.load(:memory)
      end 

      it "should return the current swap free" do 
        Facter.fact(:swapfree).value.should == "0.00 kB"
      end
    
      it "should return the current swap size" do 
        Facter.fact(:swapsize).value.should == "0.00 kB"
      end 
    
      it "should return the current memory size" do 
        Facter.fact(:memorysize).value.should == "1007.34 MB"
      end 
    
      it "should return the current memory free" do 
        Facter.fact(:memoryfree).value.should == "641.25 MB"
      end 
    end 
    
    describe "with one swap" do 
      before(:each) do 
        sample_swapinfo = <<SWAP
Device          1K-blocks     Used    Avail Capacity
/dev/da0p3        2048540        0  1048540     0%
SWAP
        Facter::Util::Resolution.stubs(:exec).with('swapinfo -k').returns sample_swapinfo

        Facter.collection.loader.load(:memory)
      end 
      it "should return the current swap free" do 
        Facter.fact(:swapfree).value.should == "1023.96 MB"
      end
    
      it "should return the current swap size" do 
        Facter.fact(:swapsize).value.should == "1.95 GB"
      end 
    
      it "should return the current memory size" do 
        Facter.fact(:memorysize).value.should == "1007.34 MB"
      end 
    
      it "should return the current memory free" do 
        Facter.fact(:memoryfree).value.should == "641.25 MB"
      end 
    end 

    describe "with multiple swaps" do 
      before(:each) do 
        sample_swapinfo = <<SWAP
Device          1K-blocks     Used    Avail Capacity
/dev/da0p3        2048540        0  1048540     0%
/dev/da0p4        3048540        0  1048540     0%
SWAP
        Facter::Util::Resolution.stubs(:exec).with('swapinfo -k').returns sample_swapinfo

        Facter.collection.loader.load(:memory)
      end 
      it "should return the current swap free" do 
        Facter.fact(:swapfree).value.should == "2.00 GB"
      end
    
      it "should return the current swap size" do 
        Facter.fact(:swapsize).value.should == "4.86 GB"
      end 
    
      it "should return the current memory size" do 
        Facter.fact(:memorysize).value.should == "1007.34 MB"
      end 
    
      it "should return the current memory free" do 
        Facter.fact(:memoryfree).value.should == "641.25 MB"
      end 
    end 
  end 

  describe "on Windows" do
    before :each do
      Facter.clear
      Facter.fact(:kernel).stubs(:value).returns("windows")
      Facter.collection.loader.load(:memory)
      require 'facter/util/wmi'
    end

    it "should return free memory" do
      os = stubs 'os'
      os.stubs(:FreePhysicalMemory).returns("3415624")
      Facter::Util::WMI.stubs(:execquery).returns([os])

      Facter.fact(:MemoryFree).value.should == '3.26 GB'
    end

    it "should return total memory" do
      computer = stubs 'computer'
      computer.stubs(:TotalPhysicalMemory).returns("4193837056")
      Facter::Util::WMI.stubs(:execquery).returns([computer])

      Facter.fact(:MemorySize).value.should == '3.91 GB'
    end
  end
end
