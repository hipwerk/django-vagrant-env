#!/bin/bash

VAGRANT_CORE_FOLDER=$(echo "$1")

OS=$(/bin/bash "${VAGRANT_CORE_FOLDER}/shell/os-detect.sh" ID)
CODENAME=$(/bin/bash "${VAGRANT_CORE_FOLDER}/shell/os-detect.sh" CODENAME)

if [[ ! -d /.hip-stuff ]]; then
    mkdir /.hip-stuff

    echo "${VAGRANT_CORE_FOLDER}" > "/.hip-stuff/vagrant-core-folder.txt"

    echo "Created directory /.hip-stuff"
fi

if [[ ! -f /.hip-stuff/initial-setup-repo-update ]]; then
    if [ "${OS}" == 'debian' ] || [ "${OS}" == 'ubuntu' ]; then
        echo "Running initial-setup apt-get update"
        apt-get update >/dev/null
        touch /.hip-stuff/initial-setup-repo-update
        echo "Finished running initial-setup apt-get update"
    elif [[ "${OS}" == 'centos' ]]; then
        echo "Running initial-setup yum update"
        yum update -y >/dev/null
        echo "Finished running initial-setup yum update"

        echo "Updating to Ruby 1.9.3"
        yum install centos-release-SCL >/dev/null
        yum remove ruby >/dev/null
        yum install ruby193 facter hiera ruby193-ruby-irb ruby193-ruby-doc ruby193-rubygem-json ruby193-libyaml >/dev/null
        gem update --system >/dev/null
        gem install haml >/dev/null
        echo "Finished updating to Ruby 1.9.3"

        echo "Installing basic development tools (CentOS)"
        yum -y groupinstall "Development Tools" >/dev/null
        echo "Finished installing basic development tools (CentOS)"
        touch /.hip-stuff/initial-setup-repo-update
    fi
fi

if [[ "${OS}" == 'ubuntu' && ("${CODENAME}" == 'lucid' || "${CODENAME}" == 'precise') && ! -f /.hip-stuff/ubuntu-required-libraries ]]; then
    echo 'Installing basic curl packages (Ubuntu only)'
    apt-get install -y libcurl3 libcurl4-gnutls-dev >/dev/null
    echo 'Finished installing basic curl packages (Ubuntu only)'

    touch /.hip-stuff/ubuntu-required-libraries
fi
