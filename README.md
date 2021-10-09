# Environment infrastructure template

This template repository sets up the bare minimum needed to define an environment on GCP as Terraform code. A Github Actions workflow is configured to generate Terraform plans on Pull Requests and provision infrastructure as needed when the state of the `main` branch changes.

We make use of workload identity federation to _temporarily_ authenticate to GCP from Github Actions. This makes it so that we do not need to generate and permanently store powerful service account keys in Github.

## Project setup

Click on "Use this template" to create a new repository based on this template. After cloning the new repository to your local machine, run the `init.sh` script to set everything up. It's required that you have installed `gcloud` and `gh` (Github CLI) and are logged into your respective accounts with both.

## References

- [Authenticate to Google Cloud](https://github.com/marketplace/actions/authenticate-to-google-cloud)
- [Workload identity federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Automate Terraform with Github Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions)
