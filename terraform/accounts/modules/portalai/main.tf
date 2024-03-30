

resource "aws_servicequotas_service_quota" "example" {
  quota_code   = "L-DB2E81BA"
  service_code = "ec2"
  value        = 32
}
