using Hoply.Desktop.Core.Storage;

namespace Hoply.Desktop.Tests;

public sealed class AppPathsTests : IDisposable
{
    private readonly string _dataRoot = Path.Combine(Path.GetTempPath(), "hoply-tests-" + Guid.NewGuid().ToString("N"));

    public AppPathsTests() => Directory.CreateDirectory(_dataRoot);

    public void Dispose() => Directory.Delete(_dataRoot, recursive: true);

    [Fact]
    public void UsesHoplyFolder()
    {
        var paths = AppPaths.CreateIn(_dataRoot);

        Assert.Equal(Path.Combine(_dataRoot, "Hoply", "settings.json"), paths.SettingsFile);
        Assert.Equal(Path.Combine(_dataRoot, "Hoply", "proxy-recovery.json"), paths.RecoveryFile);
        Assert.Equal(Path.Combine(_dataRoot, "Hoply", "environment-recovery.json"), paths.EnvironmentRecoveryFile);
    }

    [Fact]
    public void MovesLegacyFolderWithItsFiles()
    {
        var legacy = Directory.CreateDirectory(Path.Combine(_dataRoot, AppPaths.LegacyFolderName)).FullName;
        File.WriteAllText(Path.Combine(legacy, "settings.json"), "{\"port\":1080}");
        File.WriteAllText(Path.Combine(legacy, "proxy-recovery.json"), "{\"enabled\":true}");

        var paths = AppPaths.CreateIn(_dataRoot);

        Assert.Equal("{\"port\":1080}", File.ReadAllText(paths.SettingsFile));
        Assert.Equal("{\"enabled\":true}", File.ReadAllText(paths.RecoveryFile));
        Assert.False(Directory.Exists(legacy));
    }

    [Fact]
    public void KeepsExistingHoplyFolder()
    {
        var legacy = Directory.CreateDirectory(Path.Combine(_dataRoot, AppPaths.LegacyFolderName)).FullName;
        File.WriteAllText(Path.Combine(legacy, "settings.json"), "antiguo");
        var current = Directory.CreateDirectory(Path.Combine(_dataRoot, "Hoply")).FullName;
        File.WriteAllText(Path.Combine(current, "settings.json"), "actual");

        var paths = AppPaths.CreateIn(_dataRoot);

        Assert.Equal("actual", File.ReadAllText(paths.SettingsFile));
        Assert.True(Directory.Exists(legacy));
    }
}
