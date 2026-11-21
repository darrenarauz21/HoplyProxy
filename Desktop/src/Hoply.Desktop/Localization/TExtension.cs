using Avalonia.Markup.Xaml;

namespace Hoply.Desktop.Localization;

/// <summary>Texto traducido en XAML: <c>Text="{l:T clave}"</c>.</summary>
public sealed class TExtension : MarkupExtension
{
    public TExtension(string key)
    {
        Key = key;
    }

    public string Key { get; set; }

    public override object ProvideValue(IServiceProvider serviceProvider) => Localizer.Get(Key);
}
