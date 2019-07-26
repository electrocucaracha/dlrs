# -*- mode: ruby -*-
# vi: set ft=ruby :

box = {
  :gpu => { :name => 'elastic/ubuntu-16.04-x86_64', :version=> '20180210.0.0' },
  :cpu => { :name => 'AntonioMeireles/ClearLinux', :version=> '30260' }
}

dlrs_compute = (ENV['DLRS_COMPUTE'] || :cpu).to_sym
if ENV['no_proxy'] != nil or ENV['NO_PROXY']
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  # NOTE: This range is based on dlrs-mgmt-net network definition CIDR 192.168.124.16/28
  (17..31).each do |i|
    $no_proxy += ",192.168.124.#{i}"
  end
end
socks_proxy = ENV['socks_proxy'] || ENV['SOCKS_PROXY'] || ""
if dlrs_compute == :cpu
  File.exists?("/usr/share/qemu/OVMF.fd") ? loader = "/usr/share/qemu/OVMF.fd" : loader = File.join(File.dirname(__FILE__), "OVMF.fd")
  if not File.exists?(loader)
    system('curl -O https://download.clearlinux.org/image/OVMF.fd')
  end
end

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox
  config.vm.box = box[dlrs_compute][:name]
  config.vm.box_version = box[dlrs_compute][:version]
  config.vm.synced_folder './', '/vagrant',
    rsync__args: ["--verbose", "--archive", "--delete", "-z"]

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if not Vagrant.has_plugin?('vagrant-proxyconf')
      system 'vagrant plugin install vagrant-proxyconf'
      raise 'vagrant-proxyconf was installed but it requires to execute again'
    end
    config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
    config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
    config.proxy.no_proxy = $no_proxy	
    config.proxy.enabled = { docker: false }
  end

  [:virtualbox, :libvirt].each do |provider|
    config.vm.provider provider do |p, override|
      p.cpus = 8
      p.memory = 8192
    end
  end
  config.vm.provider 'libvirt' do |v, override|
    v.nested = true
    v.cpu_mode = 'host-passthrough'
    v.management_network_address = "192.168.124.16/28"
    v.management_network_name = "dlrs-mgmt-net"
    v.random_hostname = true
    v.loader = loader
  end
  ["dlrs-oss", "dlrs-mkl", "pytorch-oss", "pytorch-mkl"].each do |dlrs_type|
    config.vm.define "#{dlrs_compute}_#{dlrs_type}" do |nodeconfig|
      nodeconfig.vm.provision 'shell', privileged: false do |sh|
        sh.env = {
          'SOCKS_PROXY': "#{socks_proxy}",
          'DLRS_TYPE': "#{dlrs_type}"
        }
        sh.inline = <<-SHELL
          cd /vagrant/
          DLRS_DEBUG=true ./postinstall.sh | tee "#{dlrs_type}_postinstall.log"
        SHELL
      end
    end
  end
end
