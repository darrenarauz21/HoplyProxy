using System.Globalization;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Hoply.Desktop.Localization;

/// <summary>
/// Textos de la interfaz en el idioma del sistema (español, inglés, portugués o francés). Si falta una clave en el idioma elegido se usa la
/// versión en inglés y, en último caso, la propia clave.
/// </summary>
public static class Localizer
{
    private const string FallbackLanguage = "en";
    private static readonly string[] SupportedLanguages = ["es", "en", "pt", "fr"];

    private static readonly IReadOnlyDictionary<string, string> Fallback = Load(FallbackLanguage);
    private static readonly IReadOnlyDictionary<string, string> Current = Load(ResolveLanguage(CultureInfo.CurrentUICulture));

    public static string Get(string key) =>
        Current.TryGetValue(key, out var value) || Fallback.TryGetValue(key, out value) ? value : key;

    public static string Format(string key, params object[] arguments) =>
        string.Format(CultureInfo.CurrentCulture, Get(key), arguments);

    private static string ResolveLanguage(CultureInfo culture)
    {
        var language = culture.TwoLetterISOLanguageName;
        return SupportedLanguages.Contains(language) ? language : FallbackLanguage;
    }

    private static Dictionary<string, string> Load(string language)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream($"localization/{language}.json");
        if (stream is null)
        {
            return new Dictionary<string, string>();
        }
        return JsonSerializer.Deserialize(stream, LocalizationJsonContext.Default.DictionaryStringString)
            ?? new Dictionary<string, string>();
    }
}

[JsonSerializable(typeof(Dictionary<string, string>))]
internal sealed partial class LocalizationJsonContext : JsonSerializerContext
{
}
