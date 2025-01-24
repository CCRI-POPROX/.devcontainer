#!/bin/bash
set -xeo pipefail

# Set up Python environment
uv venv
source .venv/bin/activate

uv pip install -r poprox-web/requirements.txt
uv pip install -r poprox-platform/requirements.txt
uv pip install -e ./poprox-storage[dev]
uv pip install -e ./poprox-concepts

# Set up platform Serverless environment
pushd poprox-platform

# install NPM-based tools like Serverless
npm ci

# get pre-commit wired up and ready
pre-commit install
pre-commit install-hooks
popd

# Set up pre-commit hooks for web and shared libraries
pushd poprox-web
pre-commit install
pre-commit install-hooks
popd

pushd poprox-storage
pre-commit install
pre-commit install-hooks
popd

pushd poprox-concepts
pre-commit install
pre-commit install-hooks
popd

# Set up and start Postgres
sudo service postgresql start 
sleep 5

# Create POPROX data and load schema
createdb poprox
psql poprox < poprox-storage/dev/dump.sql
pushd poprox-storage/poprox-db
alembic upgrade heads
popd
