terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.43.0"
    }
  }
}

locals {
  defaults          = var.defaults
  projects          = var.projects
}

locals {
  environment_data = flatten([
    for env in local.defaults.environments : [
      for project in local.projects : {
        name     = "${project} (${env})"
        email    = "${local.defaults.admin_root_email_name}.${env}-${project}@${local.defaults.admin_root_email_domain}"
        project  = "${project}"
      }
    ]
  ])
}


provider "aws" {
  region = local.defaults.aws_sso_region
}


data "aws_ssoadmin_instances" "org" {}
data "aws_organizations_organization" "org" {}

# This creates a new organizational unit within your organization
resource "aws_organizations_organizational_unit" "project" {
  for_each  = toset(local.projects)
  name      = each.value
  parent_id = data.aws_organizations_organization.org.roots[0].id
}


resource "aws_organizations_account" "account" {
  count             = length(local.projects) * length(local.defaults.environments)
  name              = local.environment_data[(count.index % length(local.environment_data))].name
  email             = local.environment_data[count.index].email
  close_on_deletion = true

  parent_id         = aws_organizations_organizational_unit.project[local.environment_data[count.index].project].id

  tags = {
    Project = local.environment_data[count.index].project
  }

  lifecycle {
    ignore_changes = [role_name]
  }
}


resource "aws_ssoadmin_permission_set" "project_admin" {

  for_each         = toset(local.projects)
  name             = "${each.value}AccountAdmin"
  description      = "make a simple account admin for project ${each.value}."
  instance_arn     = tolist(data.aws_ssoadmin_instances.org.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=${local.defaults.aws_region}#"
  session_duration = "PT12H"

  depends_on = [ aws_organizations_account.account ]

}

resource "aws_ssoadmin_managed_policy_attachment" "project_admin_policy" {
  for_each             = aws_ssoadmin_permission_set.project_admin
  instance_arn         = tolist(data.aws_ssoadmin_instances.org.arns)[0]
  permission_set_arn   = each.value.arn
  managed_policy_arn   = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_identitystore_user" "project" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.org.identity_store_ids)[0]
  for_each          = toset(local.projects)

  display_name = each.value
  user_name    = "${each.value}_admin"

  name {
    given_name  = local.defaults.admin_root_email_name
    family_name = "admin"
  }

  emails {
    value = "${local.defaults.admin_root_email_name}.${each.value}-admin@${local.defaults.admin_root_email_domain}"
  }
}

resource "aws_identitystore_group" "project" {
  for_each          = toset(local.projects)
  display_name      = "${each.value}_admin"
  description       = "Admin group no a per project basis."
  identity_store_id = tolist(data.aws_ssoadmin_instances.org.identity_store_ids)[0]
}

resource "aws_identitystore_group_membership" "project" {
  for_each = toset(local.projects)

  identity_store_id = tolist(data.aws_ssoadmin_instances.org.identity_store_ids)[0]
  group_id          = aws_identitystore_group.project[each.key].group_id
  member_id         = aws_identitystore_user.project[each.key].user_id
}


resource "aws_ssoadmin_account_assignment" "account_assignment" {
  for_each = { for account in aws_organizations_account.account : account.name => {
    project = account.tags["Project"]
    account_id = account.id
  }}

  instance_arn       = tolist(data.aws_ssoadmin_instances.org.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.project_admin[each.value.project].arn
  principal_id       = aws_identitystore_group.project[each.value.project].group_id
  principal_type     = "GROUP"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}



# Running On-Demand G and VT instances: L-DB2E81BA
