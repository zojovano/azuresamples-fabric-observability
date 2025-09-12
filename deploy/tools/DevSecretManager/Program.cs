using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Extensions.Configuration;
using System.CommandLine;

namespace DevSecretManager;

public class Program
{
    private static IConfiguration? _configuration;
    
    public static async Task<int> Main(string[] args)
    {
        // Build configuration with user secrets
        _configuration = new ConfigurationBuilder()
            .AddUserSecrets<Program>()
            .AddEnvironmentVariables()
            .Build();

        var rootCommand = new RootCommand("Fabric Observability Development Secret Manager")
        {
            CreateSetCommand(),
            CreateGetCommand(),
            CreateListCommand(),
            CreateTestCommand(),
            CreateKeyVaultCommand()
        };

        return await rootCommand.InvokeAsync(args);
    }

    private static Command CreateSetCommand()
    {
        var keyOption = new Option<string>("--key", "Secret key name") { IsRequired = true };
        var valueOption = new Option<string>("--value", "Secret value") { IsRequired = true };
        var command = new Command("set", "Set a user secret")
        {
            keyOption,
            valueOption
        };

        command.SetHandler(async (key, value) =>
        {
            await SetUserSecret(key, value);
        }, keyOption, valueOption);

        return command;
    }

    private static Command CreateGetCommand()
    {
        var keyOption = new Option<string>("--key", "Secret key name") { IsRequired = true };
        var command = new Command("get", "Get a user secret")
        {
            keyOption
        };

        command.SetHandler(async (key) =>
        {
            await GetUserSecret(key);
        }, keyOption);

        return command;
    }

    private static Command CreateListCommand()
    {
        var command = new Command("list", "List all configured secrets (without values)");

        command.SetHandler(async () =>
        {
            await ListUserSecrets();
        });

        return command;
    }

    private static Command CreateTestCommand()
    {
        var command = new Command("test", "Test Fabric authentication with stored secrets");

        command.SetHandler(async () =>
        {
            await TestFabricAuthentication();
        });

        return command;
    }

    private static Command CreateKeyVaultCommand()
    {
        var keyVaultNameOption = new Option<string>("--vault-name", "Key Vault name") { IsRequired = true };
        var secretNameOption = new Option<string>("--secret-name", "Secret name in Key Vault") { IsRequired = true };
        var localKeyOption = new Option<string>("--local-key", "Local user secret key name") { IsRequired = true };

        var command = new Command("import-from-keyvault", "Import secret from Azure Key Vault to user secrets")
        {
            keyVaultNameOption,
            secretNameOption,
            localKeyOption
        };

        command.SetHandler(async (vaultName, secretName, localKey) =>
        {
            await ImportFromKeyVault(vaultName, secretName, localKey);
        }, keyVaultNameOption, secretNameOption, localKeyOption);

        return command;
    }

    private static async Task SetUserSecret(string key, string value)
    {
        try
        {
            // Use dotnet user-secrets command
            var process = new System.Diagnostics.Process
            {
                StartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "dotnet",
                    Arguments = $"user-secrets set \"{key}\" \"{value}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            await process.WaitForExitAsync();

            if (process.ExitCode == 0)
            {
                Console.WriteLine($"✅ Secret '{key}' set successfully");
            }
            else
            {
                var error = await process.StandardError.ReadToEndAsync();
                Console.WriteLine($"❌ Failed to set secret: {error}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error setting secret: {ex.Message}");
        }
    }

    private static async Task GetUserSecret(string key)
    {
        try
        {
            var value = _configuration?[key];
            if (!string.IsNullOrEmpty(value))
            {
                Console.WriteLine($"🔑 {key}: {MaskSecret(value)}");
            }
            else
            {
                Console.WriteLine($"❌ Secret '{key}' not found");
            }
            await Task.CompletedTask;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error getting secret: {ex.Message}");
        }
    }

    private static async Task ListUserSecrets()
    {
        try
        {
            Console.WriteLine("📋 Configured secrets:");
            var relevantKeys = new[]
            {
                "Azure:ClientId",
                "Azure:ClientSecret", 
                "Azure:TenantId",
                "Azure:SubscriptionId",
                "Fabric:WorkspaceName",
                "Fabric:DatabaseName",
                "Azure:ResourceGroupName",
                "Azure:KeyVaultName"
            };

            foreach (var key in relevantKeys)
            {
                var value = _configuration?[key];
                var status = !string.IsNullOrEmpty(value) ? "✅ SET" : "❌ NOT SET";
                Console.WriteLine($"  {key}: {status}");
            }
            await Task.CompletedTask;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error listing secrets: {ex.Message}");
        }
    }

    private static async Task TestFabricAuthentication()
    {
        try
        {
            var clientId = _configuration?["Azure:ClientId"];
            var clientSecret = _configuration?["Azure:ClientSecret"];
            var tenantId = _configuration?["Azure:TenantId"];

            if (string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret) || string.IsNullOrEmpty(tenantId))
            {
                Console.WriteLine("❌ Missing required secrets. Please set:");
                Console.WriteLine("   dotnet run set --key \"Azure:ClientId\" --value \"your-client-id\"");
                Console.WriteLine("   dotnet run set --key \"Azure:ClientSecret\" --value \"your-client-secret\"");
                Console.WriteLine("   dotnet run set --key \"Azure:TenantId\" --value \"your-tenant-id\"");
                return;
            }

            Console.WriteLine("🔐 Testing authentication with stored secrets...");
            Console.WriteLine($"📋 Client ID: {MaskSecret(clientId)}");
            Console.WriteLine($"📋 Tenant ID: {tenantId}");

            // Export to environment variables for PowerShell
            var exportScript = Path.Combine(Path.GetTempPath(), "fabric-test-env.ps1");
            await File.WriteAllTextAsync(exportScript, $@"
$env:AZURE_CLIENT_ID = '{clientId}'
$env:AZURE_CLIENT_SECRET = '{clientSecret}'
$env:AZURE_TENANT_ID = '{tenantId}'
$env:FABRIC_WORKSPACE_NAME = '{_configuration?["Fabric:WorkspaceName"] ?? "fabric-otel-workspace"}'
$env:FABRIC_DATABASE_NAME = '{_configuration?["Fabric:DatabaseName"] ?? "otelobservabilitydb"}'
$env:RESOURCE_GROUP_NAME = '{_configuration?["Azure:ResourceGroupName"] ?? "azuresamples-platformobservabilty-fabric"}'

Write-Host ""🔑 Environment variables set for Fabric testing"" -ForegroundColor Green
Write-Host ""You can now run: .\infra\Deploy-FabricArtifacts-Git.ps1"" -ForegroundColor Cyan
");

            Console.WriteLine($"✅ Environment script created: {exportScript}");
            Console.WriteLine("💡 To test Fabric deployment:");
            Console.WriteLine($"   1. Run: pwsh -File \"{exportScript}\"");
            Console.WriteLine("   2. Then: .\\infra\\Deploy-FabricArtifacts-Git.ps1");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error testing authentication: {ex.Message}");
        }
    }

    private static async Task ImportFromKeyVault(string vaultName, string secretName, string localKey)
    {
        try
        {
            Console.WriteLine($"🔐 Importing '{secretName}' from Key Vault '{vaultName}'...");

            var keyVaultUrl = $"https://{vaultName}.vault.azure.net/";
            var credential = new DefaultAzureCredential();
            var client = new SecretClient(new Uri(keyVaultUrl), credential);

            var secret = await client.GetSecretAsync(secretName);
            await SetUserSecret(localKey, secret.Value.Value);

            Console.WriteLine($"✅ Imported '{secretName}' as local secret '{localKey}'");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error importing from Key Vault: {ex.Message}");
            Console.WriteLine("💡 Make sure you're authenticated with Azure CLI: az login");
        }
    }

    private static string MaskSecret(string secret)
    {
        if (string.IsNullOrEmpty(secret) || secret.Length < 8)
            return "***";
        
        return secret[..4] + "***" + secret[^4..];
    }
}
