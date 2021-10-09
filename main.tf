terraform {
  required_providers {
    google = {
      source  = "google"
      version = "~> 3.87.0"
    }
  }
}

provider "google" {
  project      = var.project
  region       = var.region
  zone         = var.zone
  access_token = var.access_token
}
