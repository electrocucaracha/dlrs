#cloud-config
package_upgrade: false
hostname: "${hostname}"
packages:
  - curl
runcmd:
  - su ${user} -c "curl -fsSL https://raw.githubusercontent.com/electrocucaracha/dlrs/master/start.sh | DLRS_DEBUG=true DLRS_TYPE=${type} bash"
