#!/bin/bash
set -xeo pipefail

# Set up AWS Session Manager
ARCH=$(uname -m)
if [ "$ARCH" == 'x86_64' ]; then
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
fi
if [ "$ARCH" == 'aarch64' ]; then
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb" -o "session-manager-plugin.deb"
fi

sudo dpkg -i session-manager-plugin.deb

# Set up Python environment
export UV_PROJECT_ENVIRONMENT=`pwd`/.venv
uv venv
source .venv/bin/activate

uv pip install -r poprox-web/requirements.txt
uv pip install -e ./poprox-platform

if [ -e "poprox-recommender/" ]; then
    cd poprox-recommender/;
    uv sync --extra cpu --active;
    cd ..;
fi


uv pip install -e ./poprox-platform
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

if [ -e "poprox-recommender/" ]; then
    pushd poprox-recommender;
    pre-commit install;
    pre-commit install-hooks;
    popd;
fi

# Set up and start Postgres
sudo service postgresql start 
sleep 5

# Create POPROX database and load schema if it doesn't exist
if ! $(psql -lqt | cut -d \| -f 1 | grep -qw poprox); then
    createdb poprox
    psql poprox < poprox-storage/dev/dump.sql
fi

pushd poprox-storage/poprox-db
alembic upgrade heads
popd

echo export UV_PROJECT_ENVIRONMENT=`pwd`/.venv >> ~/.bashrc 
echo source `pwd`/.venv/bin/activate >> ~/.bashrc 