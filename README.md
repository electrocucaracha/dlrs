# Deep Learning Reference Stack

[![Build Status](https://travis-ci.org/electrocucaracha/dlrs.png)](https://travis-ci.org/electrocucaracha/dlrs)

The Deep Learning Reference Stack (DLRS) project is used to automate
steps described in the [ClearLinux official documentation][1] for
running the benchmarks locally or in a Public Cloud Provider as AWS.

## Deployment

### Virtual Machine

This project provides a [Vagrant file](Vagrantfile) for automate the 
provisioning process in a Virtual Machines. The setup bash script
contains the Linux instructions for installing its dependencies 
required for its usage. This script supports two Virtualization
technologies (Libvirt and VirtualBox). The following instruction 
installs and configures the Libvirt provider.

    $ ./setup.sh -p libvirt

Once Vagrant is installed, it's possible to provision several Virtual
Machines which run benchmarks in parallel with the following
instruction:

    $ vagrant up

### Terraform

The Terraform configuration files provided for this project launch a
single AWS EC2 instance. They require to install the `terraform`
client previously, for more information visit the [official site][2].

    $ terraform init
    $ terraform apply -auto-approve

## License

Apache-2.0

[1]: https://clearlinux.org/documentation/clear-linux/tutorials/dlrs
[2]: https://learn.hashicorp.com/terraform/getting-started/install#installing-terraform
