# What's Next

Document to maintain notes on what is next for the project and current development status.

## First Class Environment Setup

Vessel is very useful for a few things:

1. Creating a development environment for jails that mimics a deployment environment.

2. Running software in production and integrating with the production environment.

3. Creating the production environment.  Creating datasets and jail files.

### Generating the Production Environment

To date we have focused mainly on using vessel for development and running containers in production.  However, perhaps the most useful feature of vessel is setting up the production environment.  This lowers the barrier to entry for vessel so that you don't need long running instances and vessel can just get you started.  

#### Example of Generating Production Environment

Vessel already creates jail files, populates datasets and mounts volumes.  It should have commands for each of these steps.  Thus we should have commands for each of:

1. Generating jail files that could be committed to source control.  These jail files will:

    a. Have startup and shutdown commands that can mount directories and datasets.
    b. Setup resource limits and cpu sets 

2. Creating datasets
3. Populate datasets

Each of these commands should be idempotent and integrate well with ansible.