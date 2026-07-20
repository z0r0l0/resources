#!/bin/bash
# ============================================================================
# Node.js Development Environment Setup
# Managed by Hermes Agent
# ============================================================================

set -e

echo "🔧 Node.js Dev Environment Setup"
echo ""

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Check Node
node --version
npm --version

# Init package.json if not exists
if [ ! -f "$PROJECT_DIR/package.json" ]; then
    cd "$PROJECT_DIR"
    npm init -y
    echo "✅ package.json created"
fi

# Install common dev packages
cd "$PROJECT_DIR"
npm install --save-dev jest eslint prettier typescript @types/node

echo ""
echo "✅ Node.js dev environment ready in $PROJECT_DIR"
