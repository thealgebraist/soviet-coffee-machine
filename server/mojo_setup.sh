#!/bin/bash
# setup-mojo.sh - install magic and initialize mojo

set -e

echo "Detected OS: $(uname)"

# 1. Install Magic package manager (Modular's modern way)
if ! command -v magic &> /dev/null
then
    echo "Installing Magic package manager..."
    if [[ "$(uname)" == "Darwin" ]]; then
        # Mac
        if ! command -v brew &> /dev/null; then
            echo "Error: Homebrew is required on Mac for Magic installation."
            exit 1
        fi
        brew install modularml/software/magic
    else
        # Linux
        curl -ssL https://magic.modular.com | sh
    fi
else
    echo "Magic package manager already installed."
fi

# 2. Add magic to PATH if just installed (Linux)
if [[ "$(uname)" == "Linux" ]]; then
    export PATH="$HOME/.modular/bin:$PATH"
fi

# 3. Create a project directory if it doesn't exist
# We'll use magic to manage the mojo environment
echo "Initializing Mojo environment..."
mkdir -p mojo_project
cd mojo_project

if [ ! -f "mojoproject.toml" ]; then
    magic init . --format pyproject
fi

# 4. Add Mojo to the environment
magic add mojo

echo "Mojo setup finished."
echo "To run mojo code: magic run mojo <file>.mojo"
