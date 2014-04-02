require 'yaml'

VAGRANTFILE_API_VERSION = "2"

dir = File.dirname(File.expand_path(__FILE__))

configValues = YAML.load_file("#{dir}/data/config.yaml")
data = configValues['local']

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "debian-74-x64-vbox43"
  config.vm.box_url = "https://googledrive.com/host/0B83ZToJ3fGtDVC1DeVVzc3lkc0U/debian-7.4.0-amd64_virtualbox.box"

  if data['vm']['hostname'].to_s != ''
    config.vm.hostname = "#{data['vm']['hostname']}"
  end

  if data['vm']['network']['private_network'].to_s != ''
    config.vm.network "private_network", ip: "#{data['vm']['network']['private_network']}"
  end

  data['vm']['network']['forwarded_port'].each do |i, port|
    if port['guest'] != '' && port['host'] != ''
      config.vm.network :forwarded_port, guest: port['guest'].to_i, host: port['host'].to_i
    end
  end

  data['vm']['synced_folder'].each do |i, folder|
    if folder['source'] != '' && folder['target'] != '' && folder['id'] != ''
      nfs = (folder['nfs'] == "true") ? "nfs" : nil
      config.vm.synced_folder "#{folder['source']}", "#{folder['target']}", id: "#{folder['id']}", type: nfs, owner: "#{folder['owner']}", group: "#{folder['group']}"
    end
  end

  config.vm.provision "shell" do |s|
    s.path = "data/shell/initial-setup.sh"
    s.args = "/vagrant/data"
  end

  config.vm.provision :shell, :path => "data/shell/update-puppet.sh"
  config.vm.provision :shell, :path => "data/shell/librarian-puppet-vagrant.sh"

  config.vm.provision :puppet do |puppet|
    ssh_username = !data['ssh']['username'].nil? ? data['ssh']['username'] : "vagrant"
    puppet.facter = {
      "ssh_username" => "#{ssh_username}"
    }
    puppet.manifests_path = "#{data['vm']['provision']['puppet']['manifests_path']}"
    puppet.manifest_file = "#{data['vm']['provision']['puppet']['manifest_file']}"

    if data['vm']['provision']['puppet']['options']
      puppet.options = data['vm']['provision']['puppet']['options']
    end
  end

  if !data['ssh']['host'].nil?
    config.ssh.host = "#{data['ssh']['host']}"
  end
  if !data['ssh']['port'].nil?
    config.ssh.port = "#{data['ssh']['port']}"
  end
  if !data['ssh']['private_key_path'].nil?
    config.ssh.private_key_path = "#{data['ssh']['private_key_path']}"
  end
  if !data['ssh']['username'].nil?
    config.ssh.username = "#{data['ssh']['username']}"
  end
  if !data['ssh']['guest_port'].nil?
    config.ssh.guest_port = data['ssh']['guest_port']
  end
  if !data['ssh']['shell'].nil?
    config.ssh.shell = "#{data['ssh']['shell']}"
  end
  if !data['ssh']['keep_alive'].nil?
    config.ssh.keep_alive = data['ssh']['keep_alive']
  end
  if !data['ssh']['forward_agent'].nil?
    config.ssh.forward_agent = data['ssh']['forward_agent']
  end
  if !data['ssh']['forward_x11'].nil?
    config.ssh.forward_x11 = data['ssh']['forward_x11']
  end
  if !data['vagrant']['host'].nil?
    config.vagrant.host = data['vagrant']['host'].gsub(":", "").intern
  end
end
