# Microsoft Fabric OTEL Deployment

This folder contains deployment scripts and artifacts for the Microsoft Fabric OTEL observability solution.

## 🎯 **Current Deployment Approach: Git Integration**

**As of September 2025, we use a Git-based deployment approach that eliminates complex API calls and provides reliable, version-controlled deployment.**

### How Git Integration Works

1. **Prepare**: Table definitions are stored in `fabric-artifacts/` folder
2. **Connect**: Fabric workspace is connected to this Git repository 
3. **Sync**: Fabric automatically syncs changes from Git to workspace
4. **Deploy**: Tables are created/updated in KQL database automatically

### Git Integration Benefits
- ✅ **No API complexity** - No authentication or API call issues
- ✅ **Automatic versioning** - All changes tracked in Git
- ✅ **Reliable deployment** - Fabric handles the sync process
- ✅ **Collaborative development** - Multiple developers can work together
- ✅ **Easy rollback** - Git history provides rollback capabilities
- ✅ **Visual feedback** - Fabric portal shows Git status

## 📁 **Folder Structure**

```
deploy/
├── fabric-artifacts/          # Git integration folder (synced with Fabric)
│   ├── README.md             # Git integration documentation
│   ├── tables/               # KQL table definitions
│   │   ├── otel-logs.kql     # OTELLogs table schema
│   │   ├── otel-metrics.kql  # OTELMetrics table schema
│   │   └── otel-traces.kql   # OTELTraces table schema
│   └── otelobservabilitydb_auto.Eventhouse/  # Fabric-generated structure
├── infra/                    # Infrastructure deployment scripts
│   ├── Deploy-FabricArtifacts-Git.ps1        # Main Git integration script
│   ├── Deploy-FabricArtifacts-Git.ps1       # Simplified Git guidance and sync script
│   ├── Deploy-Complete.ps1                   # Full infrastructure deployment
│   └── Bicep/                # Azure infrastructure templates
└── tools/                    # Development and testing tools
```

## 🚀 **Deployment Process**

### Step 1: Infrastructure Deployment
```powershell
# Deploy Azure infrastructure (Event Hub, Container Instances, etc.)
cd deploy/infra/Bicep
./deploy.ps1
```

### Step 2: Fabric Workspace Setup
```powershell
# Set up Fabric workspace and Git integration
cd deploy/infra
./Deploy-FabricArtifacts-Git.ps1
```

### Step 3: Git Integration Connection
1. **Open Fabric Portal**: https://app.fabric.microsoft.com
2. **Navigate to workspace**: `fabric-otel-workspace`
3. **Go to Settings**: Workspace Settings > Git Integration
4. **Connect repository**: 
   - Provider: GitHub
   - Repository: `azuresamples-fabric-observability`
   - Branch: `main`
   - Folder: `deploy/fabric-artifacts`

### Step 4: Sync and Deploy Tables
```powershell
# Trigger automated Git sync (optional - can be done manually in portal)
cd deploy/infra
./Deploy-FabricArtifacts-Git.ps1 -TriggerSync
```

**OR manually in Fabric portal:**
- Use Source Control panel → Update from Git

## 🔍 **Verification Steps**

After deployment, verify tables are created:

1. **Open KQL Database**: `otelobservabilitydb` in Fabric portal
2. **Run verification query**:
   ```kql
   .show tables
   ```
3. **Expected tables**:
   - `OTELLogs` - OpenTelemetry log data
   - `OTELMetrics` - OpenTelemetry metrics data
   - `OTELTraces` - OpenTelemetry trace data

4. **Test table schemas**:
   ```kql
   OTELLogs | getschema
   OTELMetrics | getschema  
   OTELTraces | getschema
   ```

## 🔄 **Making Schema Changes**

To update table schemas:

1. **Edit KQL files** in `fabric-artifacts/tables/`
2. **Commit changes** to Git repository
3. **Sync in Fabric**: Portal → Source Control → Update from Git
4. **Verify changes**: Run `.show tables` and schema queries

## 🛠️ **Development Workflow**

```bash
# 1. Make changes to table definitions
edit deploy/fabric-artifacts/tables/otel-logs.kql

# 2. Test changes locally
./tests/Test-FabricIntegration-Git.ps1 -WhatIf

# 3. Commit to Git
git add .
git commit -m "Update OTEL table schema"
git push

# 4. Sync in Fabric portal
# Or use automated sync script
./deploy/infra/Deploy-FabricArtifacts-Git.ps1 -TriggerSync
```

## 📋 **Key Files**

| File | Purpose | Usage |
|------|---------|-------|
| `Deploy-FabricArtifacts-Git.ps1` | Main Git integration setup | Initial setup and guidance |
| `Deploy-FabricArtifacts-Git.ps1` | Git guidance & sync | Verify Git structure, provide setup guidance, optional automated sync |
| `fabric-artifacts/tables/*.kql` | Table definitions | Schema definitions synced to Fabric |
| `fabric-artifacts/README.md` | Git integration docs | Setup and usage guidance |

## 🔧 **Troubleshooting**

**Git sync not working?**
- Check workspace Git integration settings
- Verify repository permissions
- Ensure correct folder path: `deploy/fabric-artifacts`

**Tables not created?**
- Check if Git sync completed successfully
- Verify KQL syntax in table definition files
- Check Fabric portal for error messages

**Authentication issues?**
- Run: `fab auth login`
- Verify Fabric workspace access permissions
- Check Azure CLI authentication: `az login`

## 📚 **Migration from API-Based Approach**

Previous versions used complex API-based deployment. The Git integration approach:
- **Eliminates authentication complexity**
- **Provides better reliability**
- **Enables collaborative development**
- **Offers built-in version control**

For legacy API scripts, see commit history before September 2025.
