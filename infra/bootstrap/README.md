# Bootstrap

This manages IAM roles and policies that can be assumed by Github Actions
and configures various Github Repository settings.

It creates a Github Environment for each environment in the project.

It creates terraform state buckets for each environment.

This has to be run manualy. We store the terraform state in the repo.

## State bootstrap

This is a one-time operation that creates the S3 buckets for storing the terraform state.
The module will write a file `backend.tf.json` in each environment. After it's created
you can migrate the `bootstrap` state to S3.

```bash
tofu init
tofu apply
tofu init -migrate-state
```