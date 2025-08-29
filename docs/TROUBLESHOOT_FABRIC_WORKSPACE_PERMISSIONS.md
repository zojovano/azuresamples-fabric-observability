# Troubleshooting Fabric Workspace Creation Permissions

## 🚨 **Current Issue**
Service Principal `ADOGenericService` (e10b0ed5-117d-466c-8a84-bee676f32373) is successfully authenticated but fails when attempting to create or list Fabric workspaces with error:
```
[Unauthorized] Access is unauthorized
```

## 🔍 **Root Cause Analysis**
The Service Principal lacks **tenant-level permissions** for workspace operations. Being a "Capacity Admin" is not sufficient for workspace creation via Fabric CLI/APIs.

## ✅ **Required Actions for Fabric Administrator**

### **Step 1: Enable Tenant Settings**
A **Fabric Administrator** needs to configure these tenant settings in the Fabric Admin portal:

1. **Navigate to Fabric Admin Portal**
   - Go to: https://fabric.microsoft.com
   - Click: ⚙️ Settings → Admin portal

2. **Enable Service Principal Workspace Creation**
   - Location: `Tenant settings` → `Developer settings`
   - Setting: **"Service principals can create workspaces, connections, and deployment pipelines"**
   - Status: ⚠️ **DISABLED by default** (this is likely the issue!)
   - Action: ✅ **Enable** this setting

3. **Enable Service Principal API Access** 
   - Location: `Tenant settings` → `Developer settings`
   - Setting: **"Service principals can call Fabric public APIs"**
   - Status: ✅ **ENABLED by default** (should already be enabled)
   - Action: ✅ **Verify** this is enabled

### **Step 2: Configure Security Groups**
For both settings above, you need to:

1. **Create or use existing Microsoft Entra Security Group**
   - Group Type: **Security**
   - Suggested Name: `FabricServicePrincipals` or similar

2. **Add Service Principal to Security Group**
   - Navigate: Azure Portal → Microsoft Entra ID → Groups
   - Select: Your security group
   - Click: **Add Members**
   - Add: Service Principal **ADOGenericService** (e10b0ed5-117d-466c-8a84-bee676f32373)

3. **Configure Tenant Settings to Use Security Group**
   - In both tenant settings above
   - Select: **"Specific security groups"** radio button
   - Add: Your security group name in the text field
   - Click: **Apply**

## 🎯 **Current Service Principal Configuration**

| Property | Value | Status |
|----------|-------|--------|
| **Name** | ADOGenericService | ✅ Configured |
| **Client ID** | e10b0ed5-117d-466c-8a84-bee676f32373 | ✅ Configured |
| **Capacity Role** | Capacity Admin | ✅ Configured |
| **Authentication** | ✅ Working | ✅ Verified |
| **Workspace Creation** | ❌ Unauthorized | ⚠️ **Needs Tenant Settings** |

## 🚀 **Testing After Configuration**

Once the Fabric Administrator completes the above steps, test with:

```powershell
# Test in our repository
cd /workspaces/azuresamples-fabric-observability
pwsh ./infra/Deploy-FabricArtifacts.ps1
```

Expected successful output:
```
🔍 Checking existing workspaces...
🔧 Workspace list exit code: 0
✅ Successfully listed workspaces
🆕 Creating new workspace: fabric-otel-workspace
✅ Successfully created workspace: fabric-otel-workspace
```

## 🔗 **Reference Documentation**

- [Service principals can create workspaces](https://learn.microsoft.com/en-us/fabric/admin/service-admin-portal-developer#service-principals-can-create-workspaces,-connections,-and-deployment-pipelines)
- [Enable service principal authentication](https://learn.microsoft.com/en-us/fabric/admin/enable-service-principal-admin-apis)
- [Developer tenant settings](https://learn.microsoft.com/en-us/fabric/admin/service-admin-portal-developer)

## 💡 **Alternative Workaround**

If tenant settings cannot be modified immediately, an alternative approach is:

1. **Manual Workspace Creation**
   - A user with workspace creation permissions manually creates `fabric-otel-workspace`
   - Adds the Service Principal as **Admin** to the workspace via "Manage access"

2. **Modified Deployment Script**
   - Skip workspace creation in the script
   - Only deploy KQL database and tables to existing workspace

```powershell
# Skip workspace creation, go directly to database operations
pwsh ./infra/Deploy-FabricArtifacts.ps1 -SkipWorkspaceCreation
```

## 📋 **Next Steps**

1. **Contact Fabric Administrator** to enable the tenant settings above
2. **Verify security group membership** for the Service Principal  
3. **Test workspace creation** after configuration
4. **Continue with KQL database deployment** once permissions are resolved

---

**Status**: ⚠️ **Blocked on Tenant Administrator action**  
**Priority**: 🔥 **High** - Required for automated deployment pipeline
