using System.Text.Json;
using System.Text.RegularExpressions;

namespace Hoply.Desktop.Tests;

/// <summary>Cada idioma de la app de escritorio trae las mismas claves y los mismos marcadores que el inglés.</summary>
public sealed partial class LocalizationFilesTests
{
    private static readonly string Folder = Path.Combine(AppContext.BaseDirectory, "Localization");

    public static TheoryData<string> Languages() => new() { "es", "pt", "fr" };

    [Theory]
    [MemberData(nameof(Languages))]
    public void HasSameKeysAndPlaceholdersAsEnglish(string language)
    {
        var english = Load("en");
        var translated = Load(language);

        Assert.Equal(english.Keys.Order(), translated.Keys.Order());
        foreach (var (key, value) in english)
        {
            Assert.True(
                Placeholders(value).SequenceEqual(Placeholders(translated[key])),
                $"{language}: los marcadores de «{key}» no coinciden con el inglés.");
            Assert.False(string.IsNullOrWhiteSpace(translated[key]), $"{language}: «{key}» está vacío.");
        }
    }

    private static Dictionary<string, string> Load(string language) =>
        JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(Path.Combine(Folder, $"{language}.json")))!;

    private static IEnumerable<string> Placeholders(string text) =>
        PlaceholderPattern().Matches(text).Select(match => match.Value).Order();

    [GeneratedRegex(@"\{\d+\}")]
    private static partial Regex PlaceholderPattern();
}
