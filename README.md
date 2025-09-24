# terraform-aws-infrastructure

This repository provisions and destroys the AWS infrastructure for the Capstone project using Terraform Cloud and GitHub Actions.

## Usage
You don’t need to install Terraform or set credentials locally.  
Simply trigger the workflows from the GitHub Actions tab:

- [Run Create Infra](.github/workflows/terraform-create.yml)
- [Run Destroy Infra](.github/workflows/terraform-destroy.yml)

## Notes
- This repo is only meant to spin the infrastructure **when you are developing or testing something that depends on it**.  
- It is **not recommended to keep the infra always running**, since AWS costs accumulate.  
  - Estimated cost: **~$162/month**, which is around **$0.22/hour**.  

## How it Works
- The workflows use **Terraform Cloud (TFC)** to handle the remote state (`.tfstate`) and execution.  
- TFC ensures that:
  - Everyone on the team shares the **same source of truth** for the infrastructure state.  
  - You don’t risk two people applying changes at the same time — TFC manages **state locking** automatically.  
  - The state file is never stored locally or passed around manually, avoiding conflicts or mismatches.  
- In short, Terraform Cloud makes collaboration safe and consistent: any infra change always goes through a single, centralized pipeline (GitHub Actions + TFC).
