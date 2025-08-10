# 🔧 Docker Build Troubleshooting Guide

## ❌ Issue: `Could not find root package 'kvm-mgr-service'`

**Problem:** The Docker build fails because `uv sync` can't find the Python package structure.

**Root Cause:** The `pyproject.toml` is in the root directory, but the Docker build was trying to run `uv sync` from a subdirectory.

## ✅ Fix Applied

I've updated the following files to fix the Docker build:

### 1. **Updated Dockerfile**

- Changed the build context to maintain the correct project structure
- Fixed the Python dependency installation to work with the root `pyproject.toml`
- Corrected file copy operations to preserve the directory structure

### 2. **Updated docker-entrypoint.sh**

- Fixed paths to match the new container structure
- Updated Python application startup command

### 3. **Created Test Scripts**

- `test-build.sh` - Verifies all required files are present
- `debug-build.sh` - Provides verbose Docker build output for troubleshooting

## 🚀 How to Use the Fixed Version

### Option 1: Quick Deploy (Recommended)

```bash
cd /workspaces/kvm-manager
./deploy.sh
```

### Option 2: Debug Build (If Issues Persist)

```bash
cd /workspaces/kvm-manager
./debug-build.sh
```

### Option 3: Manual Build

```bash
cd /workspaces/kvm-manager
docker build -t kvm-manager .
docker run -d --name kvm-manager -p 3000:3000 -p 8081:8081 --device /dev/ttyUSB0:/dev/ttyUSB0 --privileged kvm-manager
```

## 📁 Correct Project Structure

The Docker build now expects this structure:

```
/workspaces/kvm-manager-v2/
├── pyproject.toml          # Python project definition (ROOT)
├── uv.lock                 # Python dependencies lock file
├── Dockerfile              # Multi-stage Docker build
├── docker-compose.yml      # Container orchestration
├── docker-entrypoint.sh    # Container startup script
├── kvm-mgr-service/        # Python backend source
│   └── main.py            # FastAPI application
├── kvm-mgr-ui/            # Node.js frontend source
│   ├── package.json       # Node.js dependencies
│   ├── server.js          # Express server
│   └── ...                # Frontend files
└── deploy.sh              # Automated deployment
```

## 🔍 Verification Steps

1. **Check file structure:**

   ```bash
   ./test-build.sh
   ```

2. **Test Docker build:**

   ```bash
   docker build -t kvm-manager .
   ```

3. **Verify container starts:**
   ```bash
   docker run --rm -p 3000:3000 -p 8081:8081 kvm-manager
   ```

## 🐛 Additional Troubleshooting

### If Build Still Fails:

1. **Check Docker version:**

   ```bash
   docker --version
   docker-compose --version
   ```

2. **Clean Docker cache:**

   ```bash
   docker system prune -a
   ```

3. **Verify all files exist:**

   ```bash
   ls -la pyproject.toml uv.lock kvm-mgr-service/main.py kvm-mgr-ui/package.json
   ```

4. **Check uv.lock file:**
   ```bash
   head -10 uv.lock
   ```

### Common Solutions:

- **Missing uv.lock:** Run `uv lock` in the project root
- **Permission issues:** Check Docker daemon permissions
- **Port conflicts:** Ensure ports 3000 and 8081 are available
- **Device access:** Verify `/dev/ttyUSB0` exists and has proper permissions

## 📝 What Changed

### Dockerfile Changes:

- Fixed Python build stage working directory
- Corrected file copy operations
- Maintained proper project structure in container

### Entrypoint Changes:

- Updated paths to match container structure
- Fixed Python application startup command

### New Files Added:

- `test-build.sh` - Pre-build verification
- `debug-build.sh` - Verbose build for troubleshooting

## ✅ Expected Results

After the fix, you should see:

1. **Successful Docker build** without "Could not find root package" errors
2. **Container starts** with both services running
3. **Web interface** accessible at http://localhost:3000
4. **API backend** accessible at http://localhost:8081

The fixed Docker setup maintains the correct Python package structure while providing a robust containerized deployment.
