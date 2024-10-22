# Scalable and secure NixOS deploys on AWS

---

## NixOS at Mercury

* Hundreds of engineers deploying changes to production multiple times per day.
* Stateless application servers running behind load-balancer
* Stateful supporting infrastructure (Grafana, Prometheus, Vault, etc)
* Fleet of Github Actions runners

---

## Status Quo a year ago

* Engineers using Github Actions for CI
* Infra team using Hydra for CD
* Hydra continously builds NixOS configurations and pushes them out with `nix-copy-closure`
* Similar to NixOps, Colemna, deploy-rs etc
* Some hooks to drain from load-balancer before nixos-rebuild switch

---

## Issues

* Artifacts built twice in GHA and Hydra
* Hard to track deploy status
* Kernel updates and NixOS upgrades 
* Bastion host and key distribution for ssh access 
* No recent NixOS AMIs available on AWS

---

## Goals

* Unify CI and CD to give developers insight in the deploy process
* No long-lived credentials. Rely on zero-trust principles and native AWS auth mechanisms
* Automated roll-out of new machine images for kernel upgrades without manual steps
* More flexible deploy model to allow for more advanced deploy strategies

---

## Proposed solution - pipeline

* Github actions for both CI and CD
* Regular and automated updates to NixOS AMIs
* Use Github Actions ID Tokens and AWS IAM roles for strong cryptographic authentication
* Tightly restrict access to AWS resources using Github Environments and AWS IAM Policies
  * Developers can stage pull requests to staging environments
  * Only main branch can access production environments

---

## Proposed solution - deploy primitives

* Auto Scaling Groups using instance refresh, for stateless services
  * Allow for rolling releases, blue-green, canary, rollbacks etc.
* AWS Systems Manager State Manager for stateful services
  * Reconcile in-place NixOS upgrades
  * Authenticate using IAM roles instead of SSH.
  * No bastion host
  * No keys to manage

---

## Projects

* Image Build and Upload Automation pipeline
* Auto scaling group support for NixOS
* AWS Systems Manager State Manager support for NixOS
* Github actions workflow for nix builds with S3 binary cache

---

## Image Build and Upload Automation

* AMIs were only uploaded once per release. Manual process
* Outdated kernels and security vulnerabilities on first boot
* NixOS release managers had no interest in maintaining AWS support. too much toil.

---

## Image build and Upload Automation

* Took over maintance of AWS support in NixOS
* Built a github actions pipeline to build and upload NixOS AMIs regularly
* Uses IAM roles for authentication (Will talk more about this later)
* AMIs now uploaded for every channel bump since 24.05
* Open sourced at https://github.com/nixos/amis
* Can use tooling to build your own custom AMIs

---


## Autoscaling groups

* Define fleet of instances using a common configuration called a **Launch Template**
* instances scaled up and down on demand, created according to launch template
* Balanced across availability zones for high availability
* Associated with a load balancer to distribute traffic
* Automatically drain instances from load balancer before termination

---

## Autoscaling groups


```terraform
resource "aws_auto_scaling_group" "webserver" {
  name     = "webserver"
  min_size = 1
  max_size = 10
  vpc_zone_identifier = var.private_subnet_ids
  launch_template {
    id      = aws_launch_template.webserver.id
  }
  target_group_arns = [aws_lb_target_group.webserver.arn]
  health_check_type = "ELB"
  instance_refresh {
    strategy = "Rolling"
  }
}
```
---

## Launch Template

```
resource "aws_launch_template" "webserver" {
  name          = "webserver"
  image_id      = var.image_id
  instance_type = "t4g.small"
  user_data     = base64(file("${path.module}/provision.sh"))
}
```

---

## Instance refresh

* Updating a launch template creates an immutable **Launch Template Version**
  * Think nix profiles but for EC2 instances
* Instance Refresh rolls out new instances according to the new launch template version
  * Think `nixos-rebuild switch` but for EC2 instances


---

## Instance Refresh

1. Create new instances according to new launch template version
1. Drain old instances from load balancer
1. Terminate instances
1. Rollback to old version if new version fails health checks


---

## Iteration 1: Build AMI per release

```nix
# ./nix/hosts/webserver.nix
{ config, pkgs, ... }: {
  imports = [
    "${pkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
  ];
  amazonImage.sizeMB = "auto";
  system.name = "webserver";
  system.stateVersion = "24.11";
  nixpkgs.hostPlatform.system = "aarch64-linux";
  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 ];
}
```

```bash
$ nix build '.#hydraJobs.webserver.amazonImage'
$ image_id=$(nix run 'github:NixOS/amis#upload-ami' -- \
    --image-info ./result/nix-support/image-info.json)
$ TF_VAR_image_id=$image_id terraform apply
```

---

## Iteration 1: Build AMI per release

```text
# aws_autoscaling_group.webserver will be updated in-place
~ resource "aws_autoscaling_group" "webserver" {
    ~ launch_template {
          id      = "lt-0945d5011bf2bb1d7"
        ~ version = "4" -> (known after apply)
      }
  }
# aws_launch_template.webserver will be updated in-place
~ resource "aws_launch_template" "webserver" {
      id                      = "lt-0945d5011bf2bb1d7"
    ~ latest_version          = 4 -> (known after apply)
    ~ image_id                = "ami-1234567890abcdef0" -> 
        "ami-7654321098abcdef0"
  }
```
---

## Problems

* Uploading AMIs is quite slow (5-10 minutes)
  * Could be improved with e.g. https://github.com/awslabs/coldsnap
* Uses a lot of storage space. No deduplication of common dependencies between AMIs

---

## Iteration 2: Use user-data to provision instances

* Use the official NixOS AMI
* Pass `user_data` to Launch Template. Bash script that instance runs on first boot
* Fetch NixOS closure from binary cache
* Run `switch-to-configuration boot && kexec` to boot into new configuration

---

## Iteration 2: Use user-data to provision instances

* Upside: Deduplication of common dependencies in binary cache
* Downside: Boot times slower as instance needs to fetch closure from binary cache on startup

---

## Iteration 2: Use user-data to provision instances

* Attach nix store path to deploy as tag on instance

<pre><code data-trim data-line-numbers="5,11">
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
      Substituters      = "s3://nixcon2024-cache"
    }
  }
}
</code></pre>

---

## Iteration 2: Use user-data to provision instances

<pre><code data-trim data-line-numbers="">
#!/bin/sh
meta=169.254.169.254
get_tag() {
  curl "http://$meta/latest/meta-data/tags/instance/$1"
}
profile=/nix/var/nix/profiles/system
nix build \
  --trusted-public-keys "$(get_tag TrustedPublicKeys)" \
  --substituters "$(get_tag Substituters)" \
  --profile "$profile" \
  "$(get_tag NixStorePath)"

"$profile/bin/switch-to-configuration" boot
systemctl start kexec.target
</code></pre>

---

## Iteration 2: Use user-data to provision instances

* Pattern abstracted into a Terraform module


<pre><code data-trim data-line-numbers="8">
module "nix_cache_bucket" {
  source = "./modules/nix_cache_bucket"
}
module "webserver_launch_template" {
  source         = "./modules/nixos_launch_template"
  name           = "webserver"
  nix_cache      = module.nix_cache_bucket
  installable    = var.nix_store_path
}
</code></pre>

<pre><code data-trim data-line-numbers="4,6-8">
resource "aws_auto_scaling_group" "webserver" {
  launch_template {
    id      = module.webserver_launch_template.id
    version = module.webserver_launch_template.latest_version
  }
  instance_refresh {
    strategy = "Rolling"
  }
}
</code></pre>
---

## Iteration 2: Deploy using terraform


```bash
$ store_path=$(nix build '.#hydraJobs.webserver')
$ nix copy --to s3://nixcon2024-cache-bucket
$ TF_VAR_nix_store_path=$store_path terraform apply
```
```
# module.launch_template.aws_launch_template.this will be updated in-place
~ resource "aws_launch_template" "this" {
      id                      = "lt-0945d5011bf2bb1d7"
    ~ latest_version          = 4 -> (known after apply)
    ~ tag_specifications {
        ~ tags          = {
            ~ "Installable" = "/nix/store/g1blfd8wjmwl050h08r2crmg8c1sfhd6-nixos-system-webserver-24.11.20240929.06cf0e1" 
            -> "/nix/store/p6b3p154bsc7w13w92jqpvgwk8xyci86-nixos-system-webserver-24.11.20240929.06cf0e1"
          }
      }
  }
```

```
# aws_autoscaling_group.webserver will be updated in-place
~ resource "aws_autoscaling_group" "webserver" {
    ~ launch_template {
          id      = "lt-0945d5011bf2bb1d7"
        ~ version = "4" -> (known after apply)
      }
  }
```

---

## Iteration 3: Deploy using AWS CLI directly

* Terraform support for instance refresh wonky (https://github.com/hashicorp/terraform-provider-aws/issues/34189)
* Rollbacks do not work
* Does not wait for instance refresh to complete

---

## Iteration 3: Deploy using AWS CLI directly

```bash
version=$(aws ec2 create-launch-template-version \
  --launch-template-name $name \
  --source-version \$latest \
  --launch-template-data \
    'TagSpecifications=[{ResourceType=instance,Tags=[{Key=Installable,Value=$store_path}]}]'
)
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$auto_scaling_group_name" \
  --desired-configuration "{Name=$name,Version=$version}" \
  --strategy Rolling
```

---

## Iteration 3: Wrapped in Github Workflow
```yaml
build:
  uses: ./.github/workflows/build-and-push.yml
  with:
    role-to-assume: arn:aws:iam::xxx:role/nix-build
    store-uri: s3://nix-cache-bucket
    installable: '#hydraJobs.webserver'
```
```yaml
deploy:
  uses: ./.github/workflows/instance-refresh.yml
  needs: build
  with:
    role-to-assume: arn:aws:iam::xxx:role/deploy-production
    environment: production
    auto-scaling-group-name: webserver
    launch-template-name: webserver
    installable: ${{ jobs.build.outputs.nix-store-path }}
```
---

## Auto Scaling Groups:  conclusion
* Zero-downtime roll-out of new NixOS Config
* Instance refresh allows for rolling releases, canary, automatic rollbacks
* Triggered from Github Actions pipeline

---


## Stateful services

* Stateful services like Prometheus, Grafana, Vault etc.
* Upgrade in place instead of destroying and recreating instances
* Use AWS Systems Manager State Manager to reconcile stateful services

---

## AWS Systems Manager 
* Agent shipped with NixOS since 24.05
* Authenticates securely to central server using instance's cryptographic identity (IAM Role)
* no ssh keys to manage
* no bastion host. No need to expose instances to the internet
* Can send "documents" to instances. Idempotent playbooks a la ansible.
* Associate document with group of instances using tags

---

## AWS Systems Manager

* Can also be used to get a shell into instances
* Even if they are not reachable from the internet
* Access restricted with IAM policies

---

## NixOS-Deploy document
* Basically the same as launch-template user-data script.
* Does `nixos-rebuild switch` instead.  Or optionally reboot.
* nixos-rebuild switch/boot is idempotent. So perfect fit.
* Reusable module available in our repo
```
module "nixos_deploy_ssm_document" {
  source = "modules/nixos_deploy_ssm_document"
}
```
---

## State Manager association

```terraform
resoure "aws_instance" "prometheus" {
  count    = 2
  image_id = data.aws_ami.nixos.id
  root_block_device { volume_size = 1000 }
  tags = { Role = "prometheus" }
}
```

```nix
{
  imports = ["${modulesPath}/virtualisation/amazon-image.nix"];
  system.name = "prometheus";
  services.prometheus.enable = true;
}
```

---

## State Manager association

<pre><code data-line-numbers="5,8-11" data-trim>
resource "aws_ssm_association" {
  name = module.nixos_deploy_ssm_document.name
  parameters = {
    substituters = module.nix_cache_bucket.store_uri
    installable  = var.nix_store_path
    action       = "switch" # or "reboot"
  }
  targets {
    key    = "tag:Role"
    values = ["prometheus"]
  }
  max_concurrency = "50%"
  max_errors      = "50%"
}
</code></pre>


```bash
#!/bin/sh

store_path=$(nix build '.#hydraJobs.prometheus')
nix copy --to s3://nix-cache-bucket
TF_VAR_nix_store_path=$store_path terraform apply
```

---

## How to authenticate our CD pipeline to AWS?

* Need credentials to talk to AWS APIs

---

## How to authenticate our instances to AWS?

* Fetch from cache
* Connect to AWS Systems Manager
* Application itself needs to authenticate to other AWS services
  * S3 buckets
  * RDS databases
  * Secrets Manager secrets
  * CloudWatch logs

---

## AWS IAM Roles and Policies

* Role is an identity that can be assumed by another entity
* Can by assumed by:
  * AWS Services (your EC2 instance, Lambda Functions)
  * SSO identities (your employees)
  * **Other federated identities (e.g. Github Actions)**
* Role has attached policies that define permisisons
* Role credentials are temporary and rotated automatically

---

## ID Tokens in Github Actions
* Github actions exposes ID token JWT signed by Github
* Scoped to specific repository, branch, or Github Environent
* Signed with well-known key

---

## ID Tokens in Github Actions

```yaml
on:
  push: { branches: [main] }
job:
 deploy:
   permissions: { id-token: write }
   environment: production
```

```
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:arianvp/nixcon2024:environment:production",
  "aud": "sts.amazonaws.com"
}
```

```yaml
on:
  pull_request:
job:
  build:
    permissions: { id-token: write }
```
```
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:arianvp/nixcon2024:pull_request",
  "aud": "sts.amazonaws.com"
}
```

---

## Trust policy for IAM Role

<pre><code data-trim data-line-numbers="2,4,11">
"Effect": "Allow",
"Action": "sts:AssumeRoleWithWebIdentity",
"Principal": {
  "Federated": "token.actions.githubusercontent.com"
},
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": 
      "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub":
      "repo:arianvp/nixcon2024:pull_request"
  }
}
</code></pre>

* Allow assuming the role with an ID token
* If Signed by Github
* If request came from a pull request
---

## Define role, and use in Github Actions
```
resource "aws_iam_role" "nix_build" {
  name = "nix-build"
  assume_role_policy = file("trust-policy.json")
}

resource "aws_iam_role_policy_attachment" "write" {
  role       = aws_iam_role.nix_build.name
  policy_arn = module.nix_cache_bucket.write_policy_arn
}
```

```yaml
build:
  permissions:
    id-token: write 
  steps:
    - uses: aws-actions/configure-aws-credentials@v14
      aws-region: eu-central-1
      role-to-assume: arn:aws:iam:xxx:role/nix-build
    - run: nix build
    - run: nix copy --to s3://nix-cache-bucket
```

---

## ABAC

```nix
resource "iam_policy" "deploy_production" {
  policy = jsonencode({
    Statement = [{
      Effect = "Allow",
      Action = ["autoscaling:StartInstanceRefresh"],
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Environment" = "production"
        }
      }
    }]
  })
}
```

---

## AWS IAM Roles and Policies

![diagram](diagram.svg)


---

## Conclusion

* Unified CI and CD pipeline, visibility for developers
* rollout at scale using auto scaling groups and AWS SSM
* Strong cryptographic authentication using Github Actions ID tokens

----

## Show me the code

* https://github.com/arianvp/nixcon2024 contains WIP code
* https://github.com/nixos/amis
* Planning to open source the terraform modules:
  * NixOS Launch Template
  * NixOS SSM Document
  * S3 Binary cache + IAM policies
  * IAM roles for Github Actions

---

## Roadmap
* Want to bring more AWS improvements to NixOS
* Better image builder tooling using systemd-repart
* SecureBoot
* Repartitioning root volume
* Lifecycle hooks for autoscaling groups
* CloudWatch logging



---

## Questions ?