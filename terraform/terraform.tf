terraform {
  backend "s3" {
    encrypt = true
    bucket = "linuxadept-terraform"
    region = "eu-west-2"
    key = "linuxadept/state"
  }
}
