# Path to pyblic key
variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.
Example: ~/.ssh/terraform.pub
DESCRIPTION
}

variable "key_name" {
  description = "Desired name of AWS key pair"
}

# TODO: Change AMI's
variable "aws_amis" {
  default = {
    cpu = "ami-674cbc1e"
    gpu = "ami-1d4e7a66"
  }
}