
locals {
    project_settings  = yamldecode(file("${path.module}/configs/account_settings.yml"))
    aws_region = local.project_settings.aws_region
}

module "portalai-dev" {
    
    source = "./modules/portalai"
    profile = local.project_settings.sso.portalai.dev
    aws_region = local.aws_region
    environment = "dev"

}

module "portalai-prod" {
    
    source = "./modules/portalai"
    profile = local.project_settings.sso.portalai.prod
    aws_region = local.aws_region
    environment = "prod"

}
