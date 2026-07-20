#!/bin/bash
# ============================================================================
# Python Development Environment Setup
# Managed by Hermes Agent
# ============================================================================

set -e

echo "🔧 Python Dev Environment Setup"
echo ""

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Check Python
python3 --version

# Create venv
if [ ! -d "$PROJECT_DIR/.venv" ]; then
    python3 -m venv "$PROJECT_DIR/.venv"
    echo "✅ Virtual environment created"
fi

# Activate and install common packages
source "$PROJECT_DIR/.venv/bin/activate"
pip install --upgrade pip

# Install common dev packages
pip install pytest pytest-cov black ruff mypy pre-commit ipython

echo ""
echo "✅ Python dev environment ready in $PROJECT_DIR"
echo "   Activate: source .venv/bin/activate"
