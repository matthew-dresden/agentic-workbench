# Root terragrunt.hcl. Every leaf inherits remote_state, the AWS provider config,
# and shared inputs from _env/. Operator-specific values come from instance leaf
# folders under instances/<owner-slug>/.
#
# Required env vars per Make targets / direct invocation:
#   AWS_REGION              -- AWS region (required)
#   AWS_ACCOUNT_ID          -- AWS account id (required)
#   WORKBENCH_STATE_BUCKET   -- S3 bucket holding remote state (e.g. workbench-remote-state-${AWS_ACCOUNT_ID})
#   WORKBENCH_OWNER_EMAIL    -- operator email (used as state-key prefix and resource owner tag)

locals {
  # Resolve the _env/ dir from WORKBENCH_WORKBENCH_REPO when set (out-of-repo leaves);
  # otherwise fall back to walking up from the calling leaf (in-repo leaves).
  env_dir     = get_env("WORKBENCH_WORKBENCH_REPO", "") != "" ? "${get_env("WORKBENCH_WORKBENCH_REPO")}/infra/terragrunt/_env" : dirname(find_in_parent_folders("_env/account.hcl"))
  account_hcl = read_terragrunt_config("${local.env_dir}/account.hcl")
  common_hcl  = read_terragrunt_config("${local.env_dir}/common.hcl")

  state_bucket = get_env("WORKBENCH_STATE_BUCKET", "workbench-remote-state-${local.account_hcl.locals.account_id}")
  owner_email  = get_env("WORKBENCH_OWNER_EMAIL", local.account_hcl.locals.default_owner_email)
  region       = get_env("AWS_REGION", local.account_hcl.locals.default_region)
}

remote_state {
  backend = "s3"
  config = {
    bucket  = local.state_bucket
    key     = "workbench-remote/${local.owner_email}/${basename(get_terragrunt_dir())}/terraform.tfstate"
    region  = local.region
    encrypt = true
    # Terraform 1.10+ S3-native locking. No DynamoDB table required.
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = {
          Project   = "workbench-remote"
          ManagedBy = "terragrunt"
        }
      }
    }
  EOF
}

inputs = merge(
  local.account_hcl.locals,
  local.common_hcl.locals,
  {
    owner_email = local.owner_email
    region      = local.region
  },
)
