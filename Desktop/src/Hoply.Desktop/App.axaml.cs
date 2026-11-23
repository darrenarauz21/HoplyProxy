using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;
using Hoply.Desktop.Core.Connection;
using Hoply.Desktop.Core.Storage;
using Hoply.Desktop.Core.SystemProxy;
using Hoply.Desktop.Core.Usbmux;
using Hoply.Desktop.Core.Verification;
using Hoply.Desktop.Localization;
using Hoply.Desktop.ViewModels;
using Hoply.Desktop.Views;

namespace Hoply.Desktop;

/// <summary>Punto único de composición: crea las dependencias concretas y las inyecta.</summary>
public sealed partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var paths = AppPaths.CreateDefault();
            var usbmux = UsbmuxClient.CreateDefault();
            var connection = new PhoneConnection(
                usbmux,
                SystemProxyConfiguratorFactory.CreateForCurrentPlatform(),
                new ProxyRecoveryStore(paths.RecoveryFile),
                new ConnectionVerifier(),
                EnvironmentProxyConfiguratorFactory.CreateForCurrentPlatform(),
                new ProxyRecoveryStore(paths.EnvironmentRecoveryFile),
                new PacProxyProbe());

            var window = new MainWindow();
            window.DataContext = new MainViewModel(connection, usbmux, new SettingsStore(paths.SettingsFile), window);
            desktop.MainWindow = window;

            CreateTrayIcon(window);
        }
        base.OnFrameworkInitializationCompleted();
    }

    /// <summary>Icono de la bandeja: clic izquierdo abre o cierra el panel; clic derecho muestra el menú.</summary>
    private void CreateTrayIcon(MainWindow window)
    {
        var image = new WindowIcon(AssetLoader.Open(new Uri("avares://Hoply/Assets/logo.png")));

        var menu = new NativeMenu();
        menu.Items.Add(CreateMenuItem("tray.open", (_, _) => window.ShowFlyout()));
        menu.Items.Add(new NativeMenuItemSeparator());
        menu.Items.Add(CreateMenuItem("tray.quit", (_, _) => window.Quit()));

        var trayIcon = new TrayIcon
        {
            Icon = image,
            ToolTipText = "Hoply",
            Menu = menu,
        };
        trayIcon.Clicked += (_, _) => Dispatcher.UIThread.Post(window.ToggleFlyout);

        window.TrayAvailable = trayIcon.NativeMenuExporter is not null;
        TrayIcon.SetIcons(this, new TrayIcons { trayIcon });
    }

    private static NativeMenuItem CreateMenuItem(string key, EventHandler onClick)
    {
        var item = new NativeMenuItem(Localizer.Get(key));
        item.Click += onClick;
        return item;
    }
}
