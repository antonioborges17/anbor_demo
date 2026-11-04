# AI Disclosure

This document lists files in this repository that were created or modified with AI assistance and the approximate 
degree of AI involvement in each.


## Teleport Deployment

Files added or changed to deploy Teleport (Helm chart teleport-cluster) with a script. AI was used to quicly generate Teleport yaml file as customization was necessary to workaround some of the defaults in the helm chart. AI tool: Claude Code.

| File                           | AI Involvement | Change                                                                          |
|--------------------------------|----------------|---------------------------------------------------------------------------------|
| scripts/deploy_teleport.sh     |       100%     | Added: installs local-path-provisioner and the Teleport Helm chart              |
| scripts/teleport-values.yaml   |       100%     | Added: chart values                                                             |
| scripts/run_all.sh             |       1%       | Updated: added deploy_teleport.sh to the script list (rest of file unchanged)   |
| AI_DISCLOSURE.md               |       100%     | Added: this file                                                                |

## Design and Deployment Guide

Files added or changed while writing the guide. AI tool: Claude Code.

| File                                     | AI Involvement | Change                                                  |
|------------------------------------------|----------------|---------------------------------------------------------|
| docs/Design_and_Deployment_Guide.docx    |       40%      | Added: some sample commands text and architecture figure|

## Terraform Configuration

| File                            | AI Involvement      | Change
|---------------------------------|---------------------|-------------------------------------------|
| main.tf                         |        15%          | Optimize cloud-init code within user_data |

## Deployment Script Files

| File                            | AI Involvement      | Change                                                                      |
|---------------------------------|---------------------|-----------------------------------------------------------------------------|
| scripts/config_rbac_usercert.sh |        5%           | Validate syntax and added error checking.                                   |
| scripts/enable_tls.sh           |       15%           | Added: Timeout/wait logic as certificates are created.                      |
| scripts/nginx-deployment.yaml   |       10%           | Added: Implement custom default web page for Nginx.                         |
| scripts/run_all.sh              |       10%           | Added logic to wait for confirmation that worker nodes have been onboarded. |
| scripts/web-portal/index.html   |       50%           | Added: Template for custom web page to be used by Nginx.                    | 
