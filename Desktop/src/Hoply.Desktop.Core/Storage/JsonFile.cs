using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

namespace Hoply.Desktop.Core.Storage;

/// <summary>Lectura tolerante y escritura atómica de archivos JSON pequeños.</summary>
internal static class JsonFile
{
    public static T? Read<T>(string path, JsonTypeInfo<T> typeInfo)
        where T : class
    {
        try
        {
            if (!File.Exists(path))
            {
                return null;
            }
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize(stream, typeInfo);
        }
        catch (Exception exception) when (exception is JsonException or IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>Escribe en un archivo temporal y lo renombra, para no dejar nunca un archivo a medias.</summary>
    public static void Write<T>(string path, T value, JsonTypeInfo<T> typeInfo)
    {
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }
        var temporary = path + ".tmp";
        using (var stream = File.Create(temporary))
        {
            JsonSerializer.Serialize(stream, value, typeInfo);
        }
        File.Move(temporary, path, overwrite: true);
    }

    public static void Delete(string path)
    {
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }
}
