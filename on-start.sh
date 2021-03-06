#!/bin/bash

set -ex

# OVERVIEW
# This script stops a SageMaker notebook once it's idle for more than 1 hour (default time)
# You can change the idle time for stop using the environment variable below.
# If you want the notebook the stop only if no browsers are open, remove the --ignore-connections flag
#
# Note that this script will fail if either condition is not met
#   1. Ensure the Notebook Instance has internet connectivity to fetch the example config
#   2. Ensure the Notebook Instance execution role permissions to SageMaker:StopNotebookInstance to stop the notebook
#       and SageMaker:DescribeNotebookInstance to describe the notebook.
#

# PARAMETERS
IDLE_TIME=14400

echo "Fetching the autostop script"
wget https://raw.githubusercontent.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/master/scripts/auto-stop-idle/autostop.py

#install git
yum -y install git
#Clone pyenv
git clone https://github.com/pyenv/pyenv.git ~/.pyenv
#Add to environment variable
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.zshrc
#exec "$SHELL"
#Install dependent software
yum -y install gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel
~/.pyenv install 3.8.0
~/.pyenv global 3.8.0

sudo -u ec2-user -i <<'EOF'

echo "Fetching poetry.lock and pyproject.toml files"
wget https://raw.githubusercontent.com/ellipsesynergie/isa-ml-prerequisites/main/poetry.lock
wget https://raw.githubusercontent.com/ellipsesynergie/isa-ml-prerequisites/main/pyproject.toml

# Install Poetry dependency manager
curl -sSL https://install.python-poetry.org | python3 -

# Add Poetry to PATH
export PATH="/home/ec2-user/.local/bin:$PATH"

# Create Virtual env with Poetry using preinstalled python 3.8
poetry env use /home/ec2-user/anaconda3/envs/python3/bin/python

# Install all dependencies
poetry install

# Create Kernel for ipython notebook
poetry run ipython kernel install --name "poetry-python3.8" --user

EOF

echo "Detecting Python install with boto3 install"

# Find which install has boto3 and use that to run the cron command. So will use default when available
# Redirect stderr as it is unneeded
if /usr/bin/python -c "import boto3" 2>/dev/null; then
    PYTHON_DIR='/usr/bin/python'
elif /usr/bin/python3 -c "import boto3" 2>/dev/null; then
    PYTHON_DIR='/usr/bin/python3'
else
    # If no boto3 just quit because the script won't work
    echo "No boto3 found in Python or Python3. Exiting..."
    exit 1
fi

echo "Found boto3 at $PYTHON_DIR"
echo "Starting the SageMaker autostop script in cron"
(crontab -l 2>/dev/null; echo "*/5 * * * * $PYTHON_DIR $PWD/autostop.py --time $IDLE_TIME --ignore-connections >> /var/log/jupyter.log") | crontab