# CasualOS AWS Module

A [Terraform](https://www.terraform.io/) module to run [CasualOS](https://casualsimulation.com/) on [AWS](https://aws.amazon.com/).

### Sub-modules

#### [CasualOS Micro](./modules/casualos-micro)

A module that deploys a single server instance of CasualOS to AWS.


## Steps

1. Get your AWS account setup
    1.   Make an AWS account
    2.   Run `aws configure --profile=profileName`
2. Make your infrastructure.
    1.  Make a Git repo.
    2.  Make a `main.tf` that references the `casualos-micro` module.
    3.  Specifiy all the variables.
    4.  Run `terraform init`.
    5.  Run `terraform apply`.
3. Run CasualOS on it.
    1.  Grab the job file.
    2.  Run `nomad run -address="https://nomad_server_address:4646" job_file.hcl
