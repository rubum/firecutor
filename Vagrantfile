# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
    # Use Ubuntu 20.04 as the base box
    config.vm.box = "ubuntu/focal64"
    config.vm.hostname = "firecutor"
  
    # Configure VM resources
    config.vm.provider "virtualbox" do |vb|
      vb.name = "firecutor-dev"
      vb.memory = "2048"  # 2GB RAM
      vb.cpus = 2         # 2 CPUs
    end

    # Provisioning script to install Docker
    config.vm.provision "shell", path: "scripts/1.install_docker.sh"

    # Provisioning script to set up Firecracker
    config.vm.provision "shell", path: "scripts/2.setup_firecracker.sh"
  
    # Provisioning script to build the custom container
    config.vm.provision "shell", path: "scripts/3.build_container.sh"

    # Provisioning script to prepare the root filesystem
    config.vm.provision "shell", path: "scripts/4.prepare_rootfs.sh"
  
    # Provisioning script to start Firecracker with the custom container
    config.vm.provision "shell", path: "scripts/5.start_firecracker.sh"
  end