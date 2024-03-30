terraform {
    backend "s3" {
        bucket  = "manage.org.tfstate"
        key     = "aws-multi-account-management"
        region  = "us-east-1"
        encrypt = true
    }
}
