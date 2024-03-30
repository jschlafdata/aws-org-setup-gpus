locals {
  project_settings  = yamldecode(file("${path.module}/configs/aws_accounts.yml"))
  aws_org_defaults = local.project_settings.defaults
  aws_org_projects = local.project_settings.projects
}


module "aws-org-accounts" {
  source   = "./modules/aws_org_accounts"
  defaults = local.aws_org_defaults
  projects = local.aws_org_projects
}
