namespace Hoply.Desktop.ViewModels;

/// <summary>Lo que el view model necesita de la ventana sin depender de ella.</summary>
public interface IDesktopShell
{
    Task CopyToClipboardAsync(string text);

    Task OpenUrlAsync(Uri url);
}
