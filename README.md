# Kukkubukku Infra

## Prerequisites

Add an aws access key id and secret key in the file terraform.tfvars

##

```
terraform init
terraform workspace new Development
terraform plan -out development.tfplan
terraform apply "development.tfplan"

terraform destroy
```