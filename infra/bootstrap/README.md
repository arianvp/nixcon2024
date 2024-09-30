# Bootstrap

This manages IAM roles and policies that can be assumed by Github Actions
and configures various Github Repository settings.

It creates a Github Environment for each environment in the project.

It creates terraform state buckets for each environment.

This has to be run manualy. We store the terraform state in the repo.