#!/bin/bash
# Debug version of deploy script for troubleshooting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 KVM Manager Docker Debug Build${NC}"
echo -e "${BLUE}=================================${NC}"

# Print build context info
echo -e "${BLUE}ℹ️  Build context information:${NC}"
echo "Current directory: $(pwd)"
echo "Docker build context files:"
ls -la

echo ""
echo -e "${BLUE}ℹ️  Project structure:${NC}"
find . -name "*.py" -o -name "*.js" -o -name "*.json" -o -name "*.toml" | head -20

echo ""
echo -e "${BLUE}🐍 Python project details:${NC}"
echo "pyproject.toml content:"
head -10 pyproject.toml

echo ""
echo -e "${BLUE}📦 Node.js project details:${NC}"
echo "package.json content:"
head -10 kvm-mgr-ui/package.json

echo ""
echo -e "${BLUE}🏗️  Starting Docker build (verbose)...${NC}"

# Build with verbose output and no cache
docker build --no-cache --progress=plain -t kvm-manager-debug . 2>&1 | tee build.log

echo ""
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build completed successfully!${NC}"
    echo -e "${GREEN}🎉 Image kvm-manager-debug is ready${NC}"
else
    echo -e "${RED}❌ Build failed. Check build.log for details.${NC}"
    echo -e "${YELLOW}💡 Common fixes:${NC}"
    echo "  1. Check that pyproject.toml is in the root directory"
    echo "  2. Verify uv.lock file exists and is valid"
    echo "  3. Ensure all source files are present"
    echo ""
    echo -e "${YELLOW}📝 Last few lines of build log:${NC}"
    tail -20 build.log
fi
