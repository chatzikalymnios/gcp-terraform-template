#!/bin/bash

set -e # Exit on first error

###############################################################################
##########                    Check Prerequisites                    ##########
###############################################################################

check_prerequisite() {
    CMD=$1
    command -v $CMD >/dev/null 2>&1 || { echo >&2 "I require $CMD but it's not installed. Aborting."; exit 1; }
}

check_prerequisite gcloud

# gh cli doesn't mix well with private org repository secret management, so do not require it for now
# check_prerequisite gh

###############################################################################
##########                  Collect project details                  ##########
###############################################################################

GIT_REMOTE=$(git remote show -n origin | grep "Fetch URL:" | awk -F ':' '{print $3}')
GH_REPO_OWNER_SUGGESTION=$(echo $GIT_REMOTE | awk -F '/' '{print $1}')
GH_REPO_SUGGESTION=$(echo $GIT_REMOTE | awk -F '/' '{print $2}' | sed 's/\.git$//')

read -e -p "Enter the Github repository owner: " -i $GH_REPO_OWNER_SUGGESTION GH_REPO_OWNER
read -e -p "Enter the Github repository name: " -i $GH_REPO_SUGGESTION GH_REPO
read -e -p "Enter a new GCP project id: " PROJECT_ID
read -e -p "Enter the desired GCP project display name: " PROJECT_NAME
read -e -p "Enter the GCP billing account id to link: " BILLING_ACCOUNT
read -e -p "Enter the GCP region to deploy to: " -i "europe-west4" REGION
read -e -p "Enter the GCP zone to deploy to: " -i "europe-west4-a" ZONE

###############################################################################
##########                     GCP project setup                     ##########
###############################################################################

echo
echo "Setting up GCP..."

gcloud projects create "$PROJECT_ID" --name "$PROJECT_NAME"
gcloud beta billing projects link "$PROJECT_ID" --billing-account "$BILLING_ACCOUNT"

gcloud --project "$PROJECT_ID" services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    cloudresourcemanager.googleapis.com \
    sts.googleapis.com

# Allow the GCP APIs to be enabled before continuing
sleep 120

gcloud --project "$PROJECT_ID" iam workload-identity-pools create "github" \
    --location "global" \
    --description "Identity pool for Github Actions workflows" \
    --display-name "Github"

# See https://token.actions.githubusercontent.com/.well-known/openid-configuration
# for all supported claims/assertions.
#
# Only workflows in this org can get a token (see --attribute-condition)

gcloud --project "$PROJECT_ID" iam workload-identity-pools providers create-oidc "github" \
    --location "global" \
    --workload-identity-pool "github" \
    --display-name "Github" \
    --attribute-mapping "google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.aud=assertion.aud,attribute.repository=assertion.repository" \
    --attribute-condition "attribute.repository.startsWith(\"${GH_REPO_OWNER}\")" \
    --issuer-uri "https://token.actions.githubusercontent.com"

# Create a service account for Github Actions to impersonate and run terraform

gcloud --project "$PROJECT_ID" iam service-accounts create "github-tf" \
    --display-name "Github - Terraform service account"

SERVICE_ACCOUNT="github-tf@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role roles/owner

# Only workflows in this repo can impersonate the github-tf service account

WORKLOAD_IDENTITY_POOL_ID=$(gcloud --project="$PROJECT_ID" iam workload-identity-pools describe "github" \
    --location "global" --format="value(name)")

gcloud --project "$PROJECT_ID" iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${GH_REPO_OWNER}/${GH_REPO}"

WORKLOAD_IDENTITY_PROVIDER=$(gcloud --project "$PROJECT_ID" iam workload-identity-pools providers describe "github" \
    --location "global" --workload-identity-pool "github" --format "value(name)")

# Create a bucket for terraform to store the state

TF_BACKEND_GCS_BUCKET="${PROJECT_ID}-tfstate"
gsutil mb -c STANDARD -p "$PROJECT_ID" -l "$REGION" "gs://${TF_BACKEND_GCS_BUCKET}"
gsutil versioning set on "gs://${TF_BACKEND_GCS_BUCKET}"
gsutil lifecycle set tfstate-lifecycle.json "gs://${TF_BACKEND_GCS_BUCKET}"

echo "Done!"

###############################################################################
##########                        Github setup                       ##########
###############################################################################

echo
echo "Setting up Github..."

# This doesn't seem to work because of gh cli not having admin rights to private org repos.
# It would probably work with on personal repos, but show manual instructions for now to avoid confusion.

# gh secret set TF_BACKEND_GCS_BUCKET -b "$TF_BACKEND_GCS_BUCKET" --org "$GH_REPO_OWNER" --repos "$GH_REPO"
# gh secret set TF_VAR_PROJECT -b "$PROJECT_ID" --org "$GH_REPO_OWNER" --repos "$GH_REPO"
# gh secret set WORKLOAD_IDENTITY_PROVIDER -b "$WORKLOAD_IDENTITY_PROVIDER" --org "$GH_REPO_OWNER" --repos "$GH_REPO"
# gh secret set SERVICE_ACCOUNT -b "$SERVICE_ACCOUNT" --org "$GH_REPO_OWNER" --repos "$GH_REPO"

# echo "Done!"
# echo
# echo "Visit your new repository at https://github.com/${GH_REPO_OWNER}/${GH_REPO}"

cat <<EOF

Go to https://github.com/${GH_REPO_OWNER}/${GH_REPO}/settings/secrets/actions to create the following secrets:

TF_BACKEND_GCS_BUCKET      = $TF_BACKEND_GCS_BUCKET
TF_VAR_PROJECT             = $PROJECT_ID
WORKLOAD_IDENTITY_PROVIDER = $WORKLOAD_IDENTITY_PROVIDER
SERVICE_ACCOUNT            = $SERVICE_ACCOUNT
EOF
