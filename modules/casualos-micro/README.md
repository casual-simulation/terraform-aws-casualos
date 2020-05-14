# CasualOS Micro

A Terraform module that deploys a micro instance of CasualOS to AWS.

## Usage

0. Make sure you have [Terraform][terraform] installed on your dev machine.

    -   `brew install terraform` or `choco install terraform`

1. Ensure that you have an [AMI][ami] with [Nomad][nomad], [Consul][consul], and [Docker][docker] installed. You can make one using the [nomad-consul-ami](../nomad-consul-ami) [Packer][] project.

2. Specify all the required variables via a `terraform.tfstate` file.
    - Most notably, you need to specify the `deployer_ssh_public_key` variable.
    - Additionally, you can specify a custom AWS profile to use by overriding the `aws_profile` variable.

3. Change directory to the `casualos-micro` folder.

    -   `cd path-to-project/casualos-micro`

4. Run `terraform apply`

5. If you specified the `zerotier_network` variable but did not specify an API key, go to your ZeroTier Network page and approve the new instance.
    -   You can validate that it is correct by the instance IP. The ZeroTier members list should show the IP that was assigned to the instance.
    -   You can also SSH into the instance and validate the node ID by running the following command: `sudo zerotier-cli status`

[terraform]: https://www.terraform.io/
[ami]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html
[nomad]: https://www.nomadproject.io/
[consul]: https://www.consul.io/
[docker]: https://www.docker.com/
[packer]: https://www.packer.io/