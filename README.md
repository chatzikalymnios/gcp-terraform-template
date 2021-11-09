# Environment infrastructure template

This template repository sets up the bare minimum needed to define an environment on GCP as Terraform code. A Github Actions workflow is configured to generate Terraform plans on Pull Requests and provision infrastructure as needed when the state of the `main` branch changes.

We make use of workload identity federation to _temporarily_ authenticate to GCP from Github Actions. This makes it so that we do not need to generate and permanently store powerful service account keys in Github.

## Project setup

Click on "Use this template" to create a new repository based on this template. After cloning the new repository to your local machine, `cd` into it and run the `init.sh` bash script to set everything up. I encourage you to inspect the script to understand what is going to be done. It's required that you have installed and are logged in with `gcloud`.

The script will prompt you for some settings (repo owner and name, desired GCP project name and regions, etc) and will

- create a GCP project and link it to the billing account you provided
- enable the Google APIs needed for Github Actions to be able to run Terraform
- configure a workload identity pool
- create a Service Acount for Github Actions
- create a Cloud Storage bucket for the Terraform state with the lifecycle policy seen in [`tfstate-lifecycle.json`](tfstate-lifecycle.json)
- print instructions on which secrets to create in the Github repository 

## References

- [Authenticate to Google Cloud](https://github.com/marketplace/actions/authenticate-to-google-cloud)
- [Workload identity federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Automate Terraform with Github Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions)
