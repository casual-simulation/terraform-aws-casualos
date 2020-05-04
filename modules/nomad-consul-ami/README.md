# Nomad + Consul Amazon Machine Image

This directory contains a `packer.json` file that builds a [AMI (Amazon Machine Image)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) which has [Nomad](https://www.nomadproject.io/), [Consul](https://www.consul.io/), and [Docker](https://www.docker.com/) pre-installed.

## Steps

1. Install [Packer](https://www.packer.io/).

On Mac:
```
$ brew install packer
```

On Windows:
```
$ choco install packer
```

On Linux, visit their [Downloads Page](https://releases.hashicorp.com/packer/1.5.6/packer_1.5.6_linux_amd64.zip).

2. Run Packer.

This assumes you installed Packer to your PATH.

```
$ cd ./modules/nomad-consul-ami
$ packer build packer.json
```