# Deep Learning Reference Stack

[![Build Status](https://travis-ci.org/electrocucaracha/dlrs.png)](https://travis-ci.org/electrocucaracha/dlrs)

The Deep Learning Reference Stack (DLRS) project is used to automate
steps described in the [ClearLinux official documentation][1] for
running the benchmarks locally or in a Public Cloud Provider as AWS.

## Deployment

### Virtual Machine

This project uses [Vagrant tool][2] for provisioning Virtual Machines
automatically. It's highly recommended to use the  *setup.sh* script
of the [bootstrap-vagrant project][3] for installing Vagrant
dependencies and plugins required for its project. The script
supports two Virtualization providers (Libvirt and VirtualBox).

    $ curl -fsSL https://raw.githubusercontent.com/electrocucaracha/bootstrap-vagrant/master/setup.sh | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to provision several Virtual
Machines which run benchmarks in parallel with the following
instruction:

    $ vagrant up

### Terraform

The Terraform configuration files provided for this project launch a
single AWS EC2 instance. They require to install the `terraform`
client previously, for more information visit the [official site][4].

    $ terraform init
    $ terraform apply -auto-approve

## License

Apache-2.0

[1]: https://clearlinux.org/documentation/clear-linux/tutorials/dlrs
[2]: https://www.vagrantup.com/
[3]: https://github.com/electrocucaracha/bootstrap-vagrant
[4]: https://learn.hashicorp.com/terraform/getting-started/install#installing-terraform
