using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
using Avalonia.VisualTree;
using Hoply.Desktop.ViewModels;

namespace Hoply.Desktop.Views;

/// <summary>
/// Panel flotante anclado a la bandeja del sistema. Se oculta al perder el foco y se vuelve a abrir desde el
/// icono de la bandeja; Alt+F4 o «Salir» cierran la app y restauran el proxy del sistema.
/// </summary>
public sealed partial class MainWindow : Window, IDesktopShell
{
    private static readonly TimeSpan TrayClickGuard = TimeSpan.FromMilliseconds(350);

    private bool _isShutdownComplete;
    private bool _isClosingForGood;
    private bool _isPositioned;
    private bool _isStarted;
    private bool _trayAvailable = true;
    private DateTime _trayClickGuardUntil;

    /// <summary>
    /// Sin un icono de bandeja no habría forma de recuperar el panel oculto, así que en ese caso se comporta como
    /// una ventana normal: aparece en la barra de tareas y el botón de ocultar cierra la app.
    /// </summary>
    public bool TrayAvailable
    {
        get => _trayAvailable;
        set
        {
            _trayAvailable = value;
            ShowInTaskbar = !value;
        }
    }

    public MainWindow()
    {
        InitializeComponent();
        Opened += OnOpened;
        Closing += OnClosing;
        Deactivated += OnDeactivated;
        KeyDown += OnKeyDown;
    }

    /// <summary>Muestra el panel; si ya estaba visible, solo le devuelve el foco.</summary>
    public void ShowFlyout()
    {
        if (_isClosingForGood)
        {
            return;
        }
        if (!IsVisible)
        {
            Show();
        }
        Activate();
    }

    /// <summary>Comportamiento del icono de la bandeja: abre o cierra el panel.</summary>
    public void ToggleFlyout()
    {
        if (IsVisible && IsActive)
        {
            HideToTray();
            return;
        }
        // Al hacer clic en la bandeja, el panel pierde el foco y se oculta antes de recibir este clic. Ese
        // clic debe cerrar el panel, no volver a abrirlo.
        if (DateTime.UtcNow < _trayClickGuardUntil)
        {
            return;
        }
        ShowFlyout();
    }

    /// <summary>Oculta el panel sin desconectar; la app sigue viva en la bandeja.</summary>
    public void HideToTray()
    {
        if (!_trayAvailable)
        {
            Quit();
            return;
        }
        if (!IsVisible || _isClosingForGood || _isShutdownComplete)
        {
            return;
        }
        _trayClickGuardUntil = DateTime.UtcNow + TrayClickGuard;
        Hide();
    }

    /// <summary>Cierra la app restaurando antes el proxy del sistema.</summary>
    public void Quit()
    {
        _isClosingForGood = true;
        Close();
    }

    public async Task CopyToClipboardAsync(string text)
    {
        if (Clipboard is { } clipboard)
        {
            await clipboard.SetTextAsync(text);
        }
    }

    public async Task OpenUrlAsync(Uri url)
    {
        await Launcher.LaunchUriAsync(url);
    }

    private async void OnOpened(object? sender, EventArgs e)
    {
        if (!_isPositioned)
        {
            _isPositioned = true;
            EnsureOpaqueFallback();
            MoveNextToTaskbar();
        }

        if (!_isStarted && DataContext is MainViewModel viewModel)
        {
            _isStarted = true;
            await viewModel.StartAsync();
        }
    }

    /// <summary>Coloca el panel en la esquina inferior derecha del área de trabajo, sobre la bandeja.</summary>
    private void MoveNextToTaskbar()
    {
        var screen = Screens.Primary ?? (Screens.All.Count > 0 ? Screens.All[0] : null);
        if (screen is null)
        {
            return;
        }
        var scale = screen.Scaling;
        var area = screen.WorkingArea;

        // En pantallas pequeñas o con mucho zoom, el panel se acorta y el contenido se desplaza.
        var availableHeight = (area.Height / scale) - 24;
        if (Height > availableHeight)
        {
            Height = Math.Max(320, availableHeight);
        }

        var margin = (int)Math.Round(12 * scale);
        var width = (int)Math.Round(Width * scale);
        var height = (int)Math.Round((Bounds.Height > 1 ? Bounds.Height : Height) * scale);
        Position = new PixelPoint(
            Math.Max(area.X, area.Right - width - margin),
            Math.Max(area.Y, area.Bottom - height - margin));
    }

    /// <summary>Si el escritorio no admite ventanas transparentes, se usa un fondo opaco para no ver negro.</summary>
    private void EnsureOpaqueFallback()
    {
        if (ActualTransparencyLevel == WindowTransparencyLevel.None
            && this.TryFindResource("Tp.Background", out var brush)
            && brush is IBrush background)
        {
            Background = background;
        }
    }

    private void OnHeaderPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (!e.GetCurrentPoint(this).Properties.IsLeftButtonPressed
            || (e.Source is Visual source && source.FindAncestorOfType<Button>() is not null))
        {
            return;
        }
        BeginMoveDrag(e);
    }

    private void OnHideClick(object? sender, RoutedEventArgs e) => HideToTray();

    private void OnAdvancedToggled(object? sender, RoutedEventArgs e)
    {
        var expanded = AdvancedToggle.IsChecked == true;
        AdvancedContent.IsVisible = expanded;
        if (expanded)
        {
            Dispatcher.UIThread.Post(() => ContentScroller.ScrollToEnd(), DispatcherPriority.Background);
        }
    }

    private void OnDeactivated(object? sender, EventArgs e)
    {
        if (_trayAvailable)
        {
            HideToTray();
        }
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            HideToTray();
            e.Handled = true;
        }
    }

    /// <summary>Antes de cerrar se restaura el proxy del sistema; la ventana se cierra cuando termina.</summary>
    private async void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        if (_isShutdownComplete || DataContext is not MainViewModel viewModel)
        {
            return;
        }
        e.Cancel = true;
        IsEnabled = false;
        try
        {
            await viewModel.ShutdownAsync();
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            _isShutdownComplete = true;
            viewModel.Dispose();
            Close();
        }
    }
}
