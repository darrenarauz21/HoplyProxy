using System.Text.Json.Serialization;
using Hoply.Desktop.Core.SystemProxy;

namespace Hoply.Desktop.Core.Storage;

[JsonSourceGenerationOptions(WriteIndented = true, UseStringEnumConverter = true)]
[JsonSerializable(typeof(DesktopSettings))]
[JsonSerializable(typeof(SystemProxySnapshot))]
internal sealed partial class StorageJsonContext : JsonSerializerContext
{
}
