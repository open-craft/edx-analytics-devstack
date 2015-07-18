VAGRANTFILE_API_VERSION = "2"

# Clone repositories first, if needed:
if ARGV[0] == "up"
  base_dir = File.dirname(__FILE__)
  for proj in ["edx-analytics-pipeline", "edx-analytics-data-api", "edx-analytics-data-api-client", "edx-analytics-dashboard"]
    path = File.join(base_dir, proj)
    if not Dir.exists?(path)
      puts "Cloning " + proj
      system "git clone https://github.com/edx/" + proj + ".git '" + path + "'"
      if proj == "edx-analytics-pipeline"
        system "cd edx-analytics-pipeline && git checkout bradenm/devstack"
      end
    end
  end
  misc_dir = File.join(base_dir, "misc")
  if not Dir.exists?(misc_dir)
    Dir.mkdir misc_dir
  end
end


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.33.11"

  # Synced folders
  config.vm.synced_folder  ".", "/vagrant", disabled: true
  config.vm.synced_folder "edx-analytics-pipeline", "/home/analytics/apps/pipeline", nfs: true
  config.vm.synced_folder "edx-analytics-data-api", "/home/analytics/apps/data-api", nfs: true
  config.vm.synced_folder "edx-analytics-data-api-client", "/home/analytics/apps/data-api-client", nfs: true
  config.vm.synced_folder "edx-analytics-dashboard", "/home/analytics/apps/dashboard", nfs: true
  # For easy transferring of log files, editing other python projects, etc:
  config.vm.synced_folder "misc", "/home/analytics/misc", nfs: true

  # Virtualbox config:
  config.vm.provider "virtualbox" do |v|
    v.memory = 1536
  end

  # Ansible Playbook
  config.vm.provision :ansible do |ansible|
    ansible.playbook = "ansible/analytics-devstack.yml"
  end

end
