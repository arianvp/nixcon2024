# AWS 

# NixOS at Mercury
* Hundreds of engineers deploying changes to production multiple times per day.
* Stateless application servers running NixOS
* Fleet of Github Actions runners running NixOS
* Stateful supporting infrastructure (Grafana, Prometheus, etc) also running NixOS

## Status Quo a year ago

* USed Github Actions for CI
* Up until recently traditional "push based deploy" (NixOps, Colemna, etc) for everything.
* Used Hydra for CD to build our nixos configurations and pushing them out
  with `nix-copy-closure` as soon as a build is finished.

## Issues
* Deploy with SSH means network access between a "Deploy instance" and target
  instances is required. And keys and SSH certificates need to be provisioned.
* Coordinating kernel upgrades tricky and manual process (take machines out of
  rotation, reboot, etc). A lot of toil.
* Backend team uses Github Actions for CI, but we use Hydra for CD. Leading to
  unneeded rebuilds and long change lead times
* Developers not familiar with Hydra and tricky to know when their commit is
  deployed to production.


## What we wanted to achieve

* Unified CI/CD with to give developers insight in the deploy process
* Secure, authenticated, deploy process with no long-lived credentials. Relying
  on zero-trust principles and native authentication and authorization mechanisms of AWS.
* Automated roll-out of new machine images for kernel upgrades without manual
  toily processes.


# What we chose

* Use Github Actions for both CI and CD
* For stateless services:
    * Use autoscaling groups with instance refresh to do rolling releases of new images with zero downtime.
* For stateful services:
    * Use AWS Systems Manager State Manager to reconcile nixos-rebuild switch across fleet
* Authenticate to AWS using AWS IAM Roles instead of long-lived credentials
* Use Github Actions ID Tokens as root-of-trust. Exchange them for temporary AWS IAM Role credentials
* Tightly restrict access to AWS resources using Github Environments and AWS IAM Policies
  * Staging pipeline can only change staging resources. Production pipeline only production resources
* Restrict Github Environments to protected branches ussing branch protection rules
  * Can't deploy to production without running on main branch
  * Developers can stage deploys to staging environments from pull requests to test changes

# Project 1: Image Build and Upload Automation

## Problem
* AWS Images (AMIs) were only uploaded once per release. So outdated kernels and
  security vulnerabilities on first boot.
* NixOS AMI upload process was manual and a burden on NixOS release managers which had no
  interest in maintaining AWS support due to too much on their plate.

## Solution
* Built new upload automation in Python that uploads AMIs and replicates them to all supported regions.
* We now upload AMIs on every channel bump automatically.
* Open sourced at https://github.com/NixOS/amis

# Tools we had to build

* Github Action pipeline and tooling to build and upload NixOS AMIs to get up-to-date images
  * open sourced and used for the offical NixOS AMIs since 24.05
  * https://github.com/nixos/amis
* Github Action workflow for doing nix builds with S3 cache
* Github Action workflow for deploying to auto scaling groups
* Github Action workflow for deploying to stateful services using AWS SSM State Manager

# Web servers

* Stateless
* Deployed using autoscaling groups

# Autoscaling Groups

* Define a fleet of instances using a common configuration called a **Launch Template**
* Instances can be scaled up and down on demand, created according to launch template
* Instances can be terminated and replaced with new instances according to launch template
* Associated with a **Load Balancer** to distribute traffic across instances
* Auto scaling group coordinates with load balancer to drain connections from instances before terminating them


# Autoscaling Groups

TODO: Screenshot

```terraform
resource "aws_lb_target_group" "webserver" {
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = 80
  health_check { path = "/" }
}

resource "aws_auto_scaling_group" "webserver" {
  name                = "webserver"
  min_size            = 1
  max_size            = 10
  vpc_zone_identifier = [ "eu-central-1a", "eu-central-1b" ]

  launch_template {
    id      = aws_launch_template.webserver.id
    version = 1
  }

  target_group_arns = [aws_lb_target_group.webserver.arn]
  health_check_type = "ELB"
  instance_maintenance_policy {
    max_healthy_percentage = 200
    min_healthy_percentage = 100
  }
  instance_refresh {
    strategy = "Rolling"
  }
}
```

# Launch Template

```terraform
resource "aws_launch_template" "webserver" {
  name          = "webserver"
  image_id      = "ami-1234567890abcdef0"
  instance_type = "t4g.small"
  user_data     = base64(file("${path.module}/provision.sh"))
}
```

# Launch template and Instance Refresh

* Updating a launch template creates a new immutable **Launch Template Version**
  * Think nix profiles but for EC2 instances
* Launch template versions can be rolled out without downtime using **Instance Refresh**
  * Creates new instances with new launch template version and adds them to load balancer
  * Drains connections from old instances
  * Terminates old instances
  * Auto rollback to old version if new instances fail to start
  * Think nixos-rebuild switch/rollback but for entire EC2 instances

# Iteration 1: Build AMI per release

```nix
# ./nix/hosts/webserver.nix
{ config, pkgs, ... }: {
  imports = ["${nixpkgs}/nixos/maintainers/scritps/ec2/amazon-image.nix" ];
  amazonImage.sizeMB = "auto";
  system.name = "webserver";
  system.stateVersion = "24.11";
  nixpkgs.hostPlatform.system = "aarch64-linux";
  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 ];
}
```

```bash
$ nix build '.#nixosConfigurations.webserver.config.system.build.amazonImage'
$ nix copy --to s3://nixcon2024-cache ./result
$ image_id=$(nix run 'github:NixOS/amis#upload-ami' -- --image-info ./result/nix-support/image-info.json)
$ TF_VAR_image_id=$image_id terraform apply
```
```
# aws_autoscaling_group.webserver will be updated in-place
~ resource "aws_autoscaling_group" "webserver" {
    ~ launch_template {
          id      = "lt-0945d5011bf2bb1d7"
        ~ version = "4" -> (known after apply)
      }
  }

# module.launch_template.aws_launch_template.this will be updated in-place
~ resource "aws_launch_template" "this" {
      id                      = "lt-0945d5011bf2bb1d7"
    ~ latest_version          = 4 -> (known after apply)
    ~ image_id                = "ami-1234567890abcdef0" -> "ami-7654321098abcdef0"
  }

```

# Iteration 1: Build AMI per release

Problems:
* Uploading AMIs is quite slow (5-10 minutes)
  * Could be improved with EBS-direct API (e.g. https://github.com/awslabs/coldsnap)
* Uses a lot of storage space. No duplication of common dependencies between AMIs even if 99% the same


# Iteration 2: Use user-data to provision instances

* Use official https://nixos.org/ AMI
* Pass `user_data` to Launch Template. Arbitrary bash script that AMI runs on first boot
* Script fetches nix store path from binary cache
* Runs `switch-to-configuration boot`
* Then runs `kexec` to boot into new configuration

# Iteration 2: Use user-data to provision instances

* Upside: No need to build AMIs per release.  Deduplication of common dependencies in binary cache
* Downside: Boot times slightly longer as instance needs to fetch closure from binary cache on startup

# Iteration 2: Use user-data to provision instances

```terraform
resource "aws_launch_template" "webserver" {
  name     = "webserver"
  image_id = data.aws_ami.nixos.id
  metadata_options {
    instance_metadata_tags = "enabled"
  }
  user_data = base64encode(file("${path.module}/provision.sh"))
  tag_specifications {
    resource_type = "instance"
    tags = {
      NixStorePath      = "${var.nix_store_path}"
      TrustedPublicKeys = "nixcon2024-0:aVznlahFAQbbjvhNriObT8ZpQEJ+kXwcDwTdlHM9pl4="
      Substituters      = "s3://nixcon2024-cache'
    }
  }
}
```


```bash
#!/bin/sh
get_tag() {
    curl -sSf "http://169.254.169.254/latest/meta-data/tags/instance/$1"
}
profile=/nix/var/nix/profiles/system
nix build \
  --extra-experimental-features 'nix-command flakes' \
  --extra-trusted-public-keys "$(get_tag TrustedPublicKeys)" \
  --extra-substituters "$(get_tag Substituters)" \
  --profile "$profile" \
  --refresh \
  "$(get_tag NixStorePath)"

"$profile/bin/switch-to-configuration" boot

if [ "$(readlink -f /run/current-system)" == "$(readlink -f /nix/var/nix/profiles/system)" ]; then
  echo "Already booted into desired configuration. exiting."
  exit 0
fi

systemctl start kexec.target --job-mode=replace-irreversibly --no-block
```

# Iteration 2: Use user-data to provision instances

* Patttern abstracted in Terraform Module

```terraform
module "nix_cache_bucket" {
  source = "github.com/arianvp/nixcon2024//infra/modules/nix_cache_bucket"
}
module "webserver_launch_template" {
  source         = "github.com/arianvp/nixcon2024//infra/modules/nixos_launch_template"
  name           = "webserver"
  nix_cache      = module.nix_cache_bucket
  installable    = var.nix_store_path
}

resource "aws_auto_scaling_group" "webserver" {
  launch_template {
    id      = module.webserver_launch_template.id
    version = module.webserver_launch_template.latest_version
  }
  instance_refresh {
    strategy = "Rolling"
  }
}
```

# Iteration 2: Deploy using terraform

```
$ store_path=$(nix build .#hydraJobs.webserver --print-out-paths)
$ nix copy --to s3://nixcon2024-cache-bucket
$ TF_VAR_nix_store_path=$store_path terraform apply
```
```
# aws_autoscaling_group.webserver will be updated in-place
~ resource "aws_autoscaling_group" "webserver" {
    ~ launch_template {
          id      = "lt-0945d5011bf2bb1d7"
        ~ version = "4" -> (known after apply)
      }
  }

# module.launch_template.aws_launch_template.this will be updated in-place
~ resource "aws_launch_template" "this" {
      id                      = "lt-0945d5011bf2bb1d7"
    ~ latest_version          = 4 -> (known after apply)
    ~ tag_specifications {
        ~ tags          = {
            ~ "Installable"       = "/nix/store/g1blfd8wjmwl050h08r2crmg8c1sfhd6-nixos-system-webserver-24.11.20240929.06cf0e1" -> "/nix/store/p6b3p154bsc7w13w92jqpvgwk8xyci86-nixos-system-webserver-24.11.20240929.06cf0e1"
          }
      }
  }
```
* Updating the launch template version triggers an instance refresh
* Zero-downtime roll-out of new NiXOS Config

# Iteration 3: Deploy using AWS CLI directly

* Terraform support for instance refrehs slightly broken (https://github.com/hashicorp/terraform-provider-aws/issues/34189)
* Rollbacks do not work
* Terraform doesn't wait for instance refresh to complete
* Wrote a Github Action Workflow that uses AWS CLI to create launch template version and trigger instance refresh instead

```yaml
jobs:
  build:
    uses: ./.github/workflows/build-and-push.yml
    with:
      role-to-assume: arn:aws:iam::640168443522:role/nix-build
      store-uri: s3://nix-cache-bucket
      installable: '#nixosConfigurations.webserver.config.system.build.toplevel'
  deploy:
    uses: ./.github/workflows/instance-refresh.yml
    with:
      role-to-assume: arn:aws:iam::640168443522:role/deploy-production
      environment: production
      auto-scaling-group-name: webserver
      launch-template-name: webserver
      installable: ${{ jobs.build.outputs.nix-store-path }}
```




# Stateful services

* Some of our services are stateful (e.g. Grafana, Prometheus, etc)
* Don't re-create the entire instance on every deploy as state needs to be preserved
* Use in-place `nixos-rebuild switch|boot` to apply changes
* Similar to Colmena, Nix-Deploy, NixOps, etc

# AWS Systems Manager

* Agent shipped with NixOS AMI that listens for commands from central AWS Systems Manager service
* Can be used to securely run commands on instances without needing SSH access
* Can send "Documents" to instances. Which are idempotent playbooks that can be executed on instances
* Similar to Ansible.
* Associate Documents with Instances using tags through AWS SSM State Manager.

# NixOS-Deploy document
* Basically the same as launch-template user-data script.
* nixos-rebuild switch/boot is idempotent. So perfect fit.
* Reusable module available in our repo
```
module "nixos_deploy_ssm_document" {
  source = "github.com/arianvp/nixcon2024//infra/modules/nixos_deploy_ssm_document"
}
```

# SSM State Manager association
* Continously applies the document to instances that match the target tags
* Updates instances in-place
* Can do phased rollouts and stop rollout on failure

```
resource "aws_instance" "prometheus" {
  count = 2
  image_id = data.aws_ami.nixos.id
  root_block_device {
    volume_size = 1000
    throughput  = 1000
    iops        = 16000
  }
  tags = {
    Name        = "prometheus"
    Environment = "production"
    Role        = "prometheus"
  }
}

resource "aws_ssm_association" {
  name = module.nixos_deploy_ssm_document.name
  parameters = {
    substituters      = module.nix_cache_bucket.store_uri
    trustedPublicKeys = module.nix_cache_bucket.trusted_public_key
    installable       = var.nix_store_path
    action            = "switch" # or "reboot"
  }
  targets {
    key    = "tag:Role"
    values = ["prometheus"]
  }
  max_concurrency = "50%"
  max_errors      = "50%"

}
```

# How to authenticate our CD pipeline to AWS?

* Need credentials to:
  * push to cache
  * trigger instance refresh
  * Modify SSM State Manager associations
* Deploys to staging and production environments need to be tightly seperated.
* Goal:
  * Only main branch can deploy to production
  * Developers need to be able to deploy to staging environments from pull requests but not to production
  * All of this without long-lived credentials

# How to authenticate our instances to AWS?
* Need credentials to:
  * Fetch from cache (S3 bucket)
  * Connect to AWS Systems Manager
  * Authenticate deployed applications to other AWS services
    * S3 buckets
    * RDS databases
    * Secrets Manager secrets
    * CloudWatch logs


# AWS IAM Roles and Policies

* IAM roles are identities that you assign specific permisions and can be *assumed* by other entities.
* Only gets permissions that you assign to the role through policies
* Credentials are temporary and rotated automatically.
* Can be assumed by:
  * AWS Services (e.g. EC2 instances or Lambda functions)
  * SSO identities (Your employees)
  * Other federated identities (e.g. Github Actions)


# Policies

* AWS Managed policies: Predefined policies that you can attach to roles
  * `AmazonEC2FullAccess`, `AmazonS3FullAccess`, etc
* Customer Managed policies: Policies that you create and manage yourself

# Customer Managed Policies

```terraform
resource "aws_iam_policy" "write_cache_bucket" {
  name        = "write-cache-bucket"
  description = "Allow read-write access to cache bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [ "s3:ListBucket", "s3:GetBucketLocation" ],
        Resource = "arn:aws:s3:::nix-cache-bucket"
      },
      {
        Effect   = "Allow",
        Action   = [ "s3:GetObject", "s3:PutObject" ],
        Resource = "arn:aws:s3:::nix-cache-bucket/*"
      }
    ]
  })
}
```


# Setting up a trust relationship between Github Actions and AWS

* Github Actions exposes an "OIDC ID Token" JWT signed by Github attesting providing
  a unique cryptographic identity for each workflow run. Scoped to a specific
  repository, branch, or github environment.
* Scoped to a specific audience.
* Signed with a well-known key provided at https://token.actions.githubusercontent.com/.well-known/openid-configuration
```
{ "alg": "RS256" }
.
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:arianvp/nixcon2024:environment:production",
  "aud": "sts.amazonaws.com",
  "exp": 1675123456,
  "nbf": 1675113456,
  "iat": 1675113456,
  "jti": "random-unique-identifier",
  "ref": "refs/heads/main",
  "sha": "abc1234567890abcdef1234567890abcdef1234",
  "repository": "username/repository-name",
  "repository_owner": "username",
  "environment": "Production",
  "run_id": "1234567890",
  "run_number": "42",
  "job_workflow_ref": "arianvp/nixcon2024/.github/workflows/deploy.yml@refs/heads/main",
  "actor": "arianvp",
  "workflow": "CI Workflow",
  "head_ref": "",
  "base_ref": "",
  "event_name": "push",
  "runner_environment": "github-hosted",
  "runner_os": "Linux",
  "runner_arch": "X64",
  "repository_visibility": "private",
  "repository_id": "987654321",
  "workflow_ref": "username/repository-name/.github/workflows/ci.yml@refs/heads/main",
  "workflow_sha": "abc1234567890abcdef1234567890abcdef1234"
}
.
SIGNATURE HERE
```


# Configure AWS to discover the Github Actions OIDC provider signing keys

AWS:
```terraform
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}
```

ID Token:
```
"aud": "sts.amazonaws.com",
```

* Trusts tokens signed with keys from `https://token.actions.githubusercontent.com/.well-known/openid-configuration`
* Only trusts ID Tokens whose audience is `sts.amazonaws.com`


# Create an IAM role that can be assumed using an ID Token

* Allow pull requests access to `nix-build` role (to access binary cache)
```
resource "aws_iam_role" "nix_build" {
  name = "nix-build"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRoleWithWebIdentity"
      Prinicipal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_owner}/${var.github_repository}:pull_request",
            "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main"
          ]
        }
      }
    }]
  })
}
```
* Give the role permissions to access the cache bucket
```
resource "aws_iam_role_policy_attachment" "nix_build_write_cache" {
  role       = aws_iam_role.nix_build.name
  policy_arn = module.nix_cache_bucket.write_policy_arn
}
```

* **Extremely important**: The `sub` condition **MUST** be scoped to your repository. Otherwise other
organisations could assume your role.
* Enterprise customers can get a unique issuer URL `https://token.actions.githubusercontent.com/<enterpriseSlug>` or their organisation to prevent this https://docs.github.com/en/enterprise-cloud@latest/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect#customizing-the-issuer-value-for-an-enterprise


# Using the IAM Role in Github Actions

```yaml
on:
  pull_request:
  push:
    branches: [main]
jobs:
  build:
    permissions:
      id-token: write # Give workflow permission to request an ID Token
    steps:
      ...
      # Assume the role using the ID Token
      - uses: aws-actions/configure-aws-credentials@v14
        aws-region: eu-central-1
        role-to-assume: arn:aws:iam:640168443522:role/nix-build
      - run: nix build
      # Push to cache using AWS credentials
      - run: nix copy --to s3://nix-cache-bucket
      ...
```

https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services


# Restricting deploys using Github Environments

* Only allow production deploys from main branch
* Allow staging deploys from pull requests

```terraform
resource "github_repository_environment" "production" {
  repository  = "nixcon2024"
  environment = "production"
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "production" {
  repository     = "nixcon"
  environment    = github_repository_environment.this.environment
  branch_pattern = "main"
}
```

## Restricting deploys using Github Environments

* Only allow access to production if workflow is using production environment
* Only allow access to staging if workflow is using staging environment

```yaml
jobs:
  deploy:
    permissions:
      id-token: write
    environment: production
    steps:
      ...
      - uses: aws-actions/configure-aws-credentials@v14
        aws-region: eu-central-1
        role-to-assume: arn:aws:iam:640168443522:role/deploy-production
      ...
```

```terraform
resource "aws_iam_role" "deploy" {
  for_each = set(["production", "staging"])
  name = "deploy-${each.value}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRoleWithWebIdentity"
      Prinicipal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub" = "repo:arianvp/nixcon2024:environment:${each.value}"
        }
      }
    }]
  })
  tags = { Environment = "${each.value}" }
}
```
```
resource "iam_policy" "deploy_environment" {
  name = "deploy-environment"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["ssm:UpdateAssociation", "autoscaling:StartInstanceRefresh"],
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Environment" = "$${aws:PrincipalTag/Environment}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "deploy_environment" {
  for_each   = aws_iam_role.deploy
  role       = each.value.name
  policy_arn = iam_policy.deploy_environment.arn
}
```


## What we did

* Built a new upload script in python that uploads AMIs and replicates them to all supported regions.

* Built automation that automatically uploads new AMIs on every channel bump.  https://github.com/NixOS/amis
    * Uses Github Actions in combination with OIDC to securely upload images to NixOS Foundation's AWS Account
      without using long-lived credentials
* Enabled AWS Systems Manager on the AMIs to allow for secure access and optional push-based deploys without
  long lived SSH keys.



# Roadmap of NixOS on AWS improvements
* Lots of stuff I couldn't cover today but we are working on

* Auto Scaling Group lifecycle hooks
  * Custom logic for termination and launch of instances
  * When standard load balancer draining is not enough
  * We use this for our Github Actions runner cluster to do instance refresh without disrupting running jobs

* Rewriting NixOS image builder to use systemd-repart for qemu-less cloud image building
* Reconfigure based on user-data in initrd instead of late boot
* Support repartitioning of root volume on first boot
* Want to explore NixOS Secure Boot on AWS using repart images
* Integrating EC2 Instance Connect for SSH access with short-lived SSH keys and no bastion host
