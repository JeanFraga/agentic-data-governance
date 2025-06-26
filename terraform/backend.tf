# Production backend configuration
# Use this for production deployment to GCP
terraform {
  backend "local" {
    path = "terraform-production.tfstate"
  }
}
