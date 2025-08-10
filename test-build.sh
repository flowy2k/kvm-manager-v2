#!/bin/bash
# Quick test script to verify Docker build setup

echo "🔍 Verifying Docker build setup..."

# Check if required files exist
echo "📁 Checking required files:"

files_to_check=(
    "Dockerfile"
    "docker-compose.yml"
    "docker-entrypoint.sh"
    "pyproject.toml"
    "uv.lock"
    "kvm-mgr-ui/package.json"
    "kvm-mgr-service/main.py"
)

all_files_exist=true

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo ""
    echo "❌ Some required files are missing. Please ensure all files are present."
    exit 1
fi

echo ""
echo "📦 Project structure:"
echo "$(tree -L 2 2>/dev/null || find . -maxdepth 2 -type d | head -10)"

echo ""
echo "🐍 Python project info:"
if [ -f "pyproject.toml" ]; then
    echo "Project name: $(grep 'name = ' pyproject.toml | head -1)"
    echo "Version: $(grep 'version = ' pyproject.toml | head -1)"
fi

echo ""
echo "📝 Node.js project info:"
if [ -f "kvm-mgr-ui/package.json" ]; then
    echo "Frontend name: $(grep '"name"' kvm-mgr-ui/package.json | head -1)"
    echo "Version: $(grep '"version"' kvm-mgr-ui/package.json | head -1)"
fi

echo ""
echo "✅ Docker build setup verification complete!"
echo ""
echo "🚀 Ready to run: ./deploy.sh"
