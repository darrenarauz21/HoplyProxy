using System.Globalization;
using System.Net;
using System.Windows.Input;
using Avalonia.Threading;
using Hoply.Desktop.Core.Connection;
using Hoply.Desktop.Core.Storage;
using Hoply.Desktop.Core.SystemProxy;
using Hoply.Desktop.Core.Usbmux;
using Hoply.Desktop.Localization;

namespace Hoply.Desktop.ViewModels;

/// <summary>La única pantalla: elegir cómo conectar, conectar y ver el estado.</summary>
public sealed class MainViewModel : ViewModelBase, IDisposable
{
    private enum DeviceAvailability
    {
        Unknown,
        Connected,
        Missing,
        ServiceMissing,
    }

    private static readonly TimeSpan DevicePollInterval = TimeSpan.FromSeconds(3);
    private static readonly TimeSpan CopiedFeedbackDuration = TimeSpan.FromSeconds(2);

    private readonly PhoneConnection _connection;
    private readonly IUsbmuxClient _usbmux;
    private readonly ISettingsStore _settingsStore;
    private readonly IDesktopShell _shell;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly RelayCommand _selectUsbCommand;
    private readonly RelayCommand _selectWiFiCommand;
    private readonly AsyncRelayCommand _toggleConnectionCommand;
    private readonly AsyncRelayCommand _verifyCommand;

    private ConnectionMode _mode;
    private string _wifiHost;
    private string _portText;
    private bool _configureSystemProxy;
    private bool _configureEnvironmentProxy;
    private StatusKind _statusKind;
    private string _statusTitle = string.Empty;
    private string? _statusDetail;
    private DeviceAvailability _device = DeviceAvailability.Unknown;
    private string? _validationMessage;
    private bool _isTerminalCopied;
    private bool _systemProxyApplied;
    private bool _environmentProxyApplied;
    private bool _started;

    public MainViewModel(PhoneConnection connection, IUsbmuxClient usbmux, ISettingsStore settingsStore, IDesktopShell shell)
    {
        _connection = connection;
        _usbmux = usbmux;
        _settingsStore = settingsStore;
        _shell = shell;

        var settings = settingsStore.Load();
        _mode = settings.Mode;
        _wifiHost = settings.WiFiHost;
        _portText = settings.Port.ToString(CultureInfo.InvariantCulture);
        _configureSystemProxy = settings.ConfigureSystemProxy;
        _configureEnvironmentProxy = settings.ConfigureEnvironmentProxy;

        _selectUsbCommand = new RelayCommand(() => Mode = ConnectionMode.Usb, () => CanEdit);
        _selectWiFiCommand = new RelayCommand(() => Mode = ConnectionMode.WiFi, () => CanEdit);
        _toggleConnectionCommand = new AsyncRelayCommand(ToggleConnectionAsync, () => !IsBusy);
        _verifyCommand = new AsyncRelayCommand(VerifyAsync, () => IsConnected);
        CopyTerminalCommand = new AsyncRelayCommand(CopyTerminalAsync);
        OpenDocumentationCommand = new AsyncRelayCommand(() => _shell.OpenUrlAsync(AppLinks.Documentation));

        _connection.StateChanged += (_, _) => Dispatcher.UIThread.Post(OnConnectionStateChanged);
        _connection.ForwardingFailed += (_, exception) => Dispatcher.UIThread.Post(() => OnForwardingFailed(exception));
        _connection.HealthChanged += (_, health) => Dispatcher.UIThread.Post(() => _ = OnHealthChangedAsync(health));
        ShowIdleStatus();
    }

    public ICommand SelectUsbCommand => _selectUsbCommand;

    public ICommand SelectWiFiCommand => _selectWiFiCommand;

    public ICommand ToggleConnectionCommand => _toggleConnectionCommand;

    public ICommand VerifyCommand => _verifyCommand;

    public ICommand CopyTerminalCommand { get; }

    public ICommand OpenDocumentationCommand { get; }

    public bool IsUsb => _mode == ConnectionMode.Usb;

    public bool IsWiFi => _mode == ConnectionMode.WiFi;

    public string WiFiHost
    {
        get => _wifiHost;
        set
        {
            if (SetProperty(ref _wifiHost, value))
            {
                ValidationMessage = null;
            }
        }
    }

    public string PortText
    {
        get => _portText;
        set
        {
            if (SetProperty(ref _portText, value))
            {
                ValidationMessage = null;
            }
        }
    }

    public bool ConfigureSystemProxy
    {
        get => _configureSystemProxy;
        set
        {
            if (SetProperty(ref _configureSystemProxy, value))
            {
                SaveSettings();
            }
        }
    }

    public bool IsSystemProxySupported => _connection.IsSystemProxySupported;

    public string SystemProxyHint => Localizer.Get(IsSystemProxySupported ? "systemProxy.hint" : "systemProxy.unsupported");

    public bool ConfigureEnvironmentProxy
    {
        get => _configureEnvironmentProxy;
        set
        {
            if (SetProperty(ref _configureEnvironmentProxy, value))
            {
                SaveSettings();
            }
        }
    }

    public bool IsEnvironmentProxySupported => _connection.IsEnvironmentProxySupported;

    public string EnvironmentProxyHint =>
        Localizer.Get(IsEnvironmentProxySupported ? "environmentProxy.hint" : "environmentProxy.unsupported");

    public bool CanEditEnvironmentProxy => CanEdit && IsEnvironmentProxySupported;

    public bool IsConnected => _connection.State == ConnectionState.Connected;

    public bool IsBusy => _connection.State is ConnectionState.Connecting or ConnectionState.Disconnecting;

    public bool CanEdit => _connection.State == ConnectionState.Disconnected;

    public bool CanEditSystemProxy => CanEdit && IsSystemProxySupported;

    public string PrimaryActionText => Localizer.Get(_connection.State switch
    {
        ConnectionState.Connecting => "action.connecting",
        ConnectionState.Disconnecting => "action.disconnecting",
        ConnectionState.Connected => "action.disconnect",
        _ => "action.connect",
    });

    public string StatusTitle
    {
        get => _statusTitle;
        private set => SetProperty(ref _statusTitle, value);
    }

    public string? StatusDetail
    {
        get => _statusDetail;
        private set
        {
            if (SetProperty(ref _statusDetail, value))
            {
                OnPropertyChanged(nameof(HasStatusDetail));
            }
        }
    }

    public bool HasStatusDetail => !string.IsNullOrEmpty(StatusDetail);

    public bool IsStatusBusy => _statusKind == StatusKind.Busy;

    public bool IsStatusOk => _statusKind == StatusKind.Ok;

    public bool IsStatusWarning => _statusKind == StatusKind.Warning;

    public bool IsStatusError => _statusKind == StatusKind.Error;

    public bool ShowsPowerIcon => _statusKind == StatusKind.Idle;

    public bool ShowsLinkIcon => _statusKind is StatusKind.Busy or StatusKind.Ok;

    public bool ShowsAlertIcon => _statusKind is StatusKind.Warning or StatusKind.Error;

    public bool IsDeviceConnected => _device == DeviceAvailability.Connected;

    public string DeviceStatusText => _device switch
    {
        DeviceAvailability.Connected => Localizer.Get("device.connected"),
        DeviceAvailability.Missing => Localizer.Get("device.missing"),
        DeviceAvailability.ServiceMissing => Localizer.Get(PlatformKey("failure.usbService")),
        _ => Localizer.Get("device.searching"),
    };

    public string? ValidationMessage
    {
        get => _validationMessage;
        private set
        {
            if (SetProperty(ref _validationMessage, value))
            {
                OnPropertyChanged(nameof(HasValidationMessage));
            }
        }
    }

    public bool HasValidationMessage => !string.IsNullOrEmpty(ValidationMessage);

    public string TerminalButtonText => Localizer.Get(_isTerminalCopied ? "terminal.copied" : "terminal.copy");

    private ConnectionMode Mode
    {
        get => _mode;
        set
        {
            if (!SetProperty(ref _mode, value))
            {
                return;
            }
            OnPropertiesChanged(nameof(IsUsb), nameof(IsWiFi));
            ValidationMessage = null;
            SaveSettings();
        }
    }

    /// <summary>Restaura un proxy que quedó cambiado y empieza a buscar el iPhone. Se llama al abrir la ventana.</summary>
    public async Task StartAsync()
    {
        if (_started)
        {
            return;
        }
        _started = true;
        try
        {
            await _connection.RecoverPendingSystemProxyAsync(_lifetime.Token);
        }
        catch (SystemProxyException)
        {
            SetStatus(StatusKind.Warning, Localizer.Get("status.restoreFailed"), Localizer.Get("status.restoreFailed.detail"));
        }
        _ = PollDevicesAsync(_lifetime.Token);
    }

    /// <summary>Desconecta y deja el sistema como estaba. Se llama antes de cerrar la ventana.</summary>
    public async Task ShutdownAsync()
    {
        await _lifetime.CancelAsync();
        await _connection.DisconnectAsync();
    }

    public void Dispose() => _lifetime.Dispose();

    private async Task ToggleConnectionAsync()
    {
        if (IsConnected)
        {
            await DisconnectAsync();
            return;
        }

        var options = BuildValidatedOptions();
        if (options is null)
        {
            return;
        }
        SaveSettings();
        SetStatus(StatusKind.Busy, Localizer.Get("status.connecting"), null);

        try
        {
            var report = await _connection.ConnectAsync(options, _lifetime.Token);
            _systemProxyApplied = report.SystemProxyApplied;
            _environmentProxyApplied = report.EnvironmentProxyApplied;
            ShowConnectedStatus(report.PublicAddress);
        }
        catch (ConnectionException exception)
        {
            SetStatus(StatusKind.Error, Localizer.Get("status.failed"), FailureMessage(exception.Failure, options.Port));
        }
        catch (OperationCanceledException)
        {
            ShowIdleStatus();
        }
    }

    private async Task DisconnectAsync()
    {
        var restored = await _connection.DisconnectAsync();
        if (restored)
        {
            ShowIdleStatus();
        }
        else
        {
            SetStatus(StatusKind.Warning, Localizer.Get("status.restoreFailed"), Localizer.Get("status.restoreFailed.detail"));
        }
    }

    private async Task VerifyAsync()
    {
        SetStatus(StatusKind.Busy, Localizer.Get("status.verifying"), null);
        try
        {
            ShowConnectedStatus(await _connection.VerifyAsync(_lifetime.Token));
        }
        catch (OperationCanceledException)
        {
        }
    }

    private async Task CopyTerminalAsync()
    {
        var options = _connection.ActiveOptions
            ?? ConnectionOptions.Create(_mode, WiFiHost, ParsePort() ?? ConnectionOptions.DefaultPort, configureSystemProxy: false);
        await _shell.CopyToClipboardAsync(TerminalProxyCommand.ForCurrentPlatform(options));

        _isTerminalCopied = true;
        OnPropertyChanged(nameof(TerminalButtonText));
        try
        {
            await Task.Delay(CopiedFeedbackDuration, _lifetime.Token);
        }
        catch (OperationCanceledException)
        {
        }
        _isTerminalCopied = false;
        OnPropertyChanged(nameof(TerminalButtonText));
    }

    private async Task PollDevicesAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(DevicePollInterval);
        try
        {
            do
            {
                if (IsUsb && _connection.State == ConnectionState.Disconnected)
                {
                    await RefreshDeviceAsync(cancellationToken);
                }
            }
            while (await timer.WaitForNextTickAsync(cancellationToken));
        }
        catch (OperationCanceledException)
        {
        }
    }

    private async Task RefreshDeviceAsync(CancellationToken cancellationToken)
    {
        DeviceAvailability availability;
        try
        {
            var devices = await _usbmux.ListDevicesAsync(cancellationToken);
            availability = devices.Any(device => device.IsUsb) ? DeviceAvailability.Connected : DeviceAvailability.Missing;
        }
        catch (UsbmuxException)
        {
            availability = DeviceAvailability.ServiceMissing;
        }

        if (_device != availability)
        {
            _device = availability;
            OnPropertiesChanged(nameof(IsDeviceConnected), nameof(DeviceStatusText));
        }
    }

    private ConnectionOptions? BuildValidatedOptions()
    {
        var options = ConnectionOptions.Create(
            _mode,
            WiFiHost,
            ParsePort() ?? (ushort)0,
            ConfigureSystemProxy && IsSystemProxySupported,
            ConfigureEnvironmentProxy && IsEnvironmentProxySupported);
        var issues = ConnectionOptionsValidator.Validate(options);
        if (issues.Count == 0)
        {
            ValidationMessage = null;
            return options;
        }
        ValidationMessage = string.Join(Environment.NewLine, issues.Select(issue => Localizer.Get(issue switch
        {
            ConnectionIssue.InvalidHost => "validation.host",
            _ => "validation.port",
        })));
        return null;
    }

    private ushort? ParsePort() =>
        ushort.TryParse(PortText.Trim(), NumberStyles.None, CultureInfo.InvariantCulture, out var port) ? port : null;

    private void SaveSettings()
    {
        var port = ParsePort();
        _settingsStore.Save(new DesktopSettings
        {
            Mode = _mode,
            WiFiHost = WiFiHost.Trim(),
            Port = port >= ConnectionOptions.MinimumPort ? port.Value : ConnectionOptions.DefaultPort,
            ConfigureSystemProxy = ConfigureSystemProxy,
            ConfigureEnvironmentProxy = ConfigureEnvironmentProxy,
        });
    }

    private void OnConnectionStateChanged()
    {
        OnPropertiesChanged(
            nameof(IsConnected), nameof(IsBusy), nameof(CanEdit), nameof(CanEditSystemProxy), nameof(CanEditEnvironmentProxy),
            nameof(PrimaryActionText));
        _selectUsbCommand.NotifyCanExecuteChanged();
        _selectWiFiCommand.NotifyCanExecuteChanged();
        _toggleConnectionCommand.NotifyCanExecuteChanged();
        _verifyCommand.NotifyCanExecuteChanged();
    }

    private void OnForwardingFailed(UsbmuxException exception)
    {
        if (!IsConnected)
        {
            return;
        }
        var detailKey = exception.Error switch
        {
            UsbmuxError.DeviceNotFound => "forward.deviceMissing",
            UsbmuxError.ConnectionRefused => "forward.refused",
            UsbmuxError.ServiceUnavailable => PlatformKey("failure.usbService"),
            _ => "forward.other",
        };
        SetStatus(StatusKind.Warning, Localizer.Get("status.phoneUnreachable"), Localizer.Get(detailKey));
    }

    /// <summary>
    /// El monitor perdió o recuperó el iPhone. Mientras no responde se sigue intentando solo; al volver se reactiva el
    /// proxy del sistema y se muestra de nuevo la IP pública.
    /// </summary>
    private async Task OnHealthChangedAsync(ConnectionHealth health)
    {
        if (!IsConnected)
        {
            return;
        }
        if (health == ConnectionHealth.Unreachable)
        {
            SetStatus(StatusKind.Busy, Localizer.Get("status.reconnecting"), Localizer.Get("status.reconnecting.detail"));
            return;
        }

        SetStatus(StatusKind.Busy, Localizer.Get("status.verifying"), null);
        try
        {
            var publicAddress = await _connection.RefreshAfterRecoveryAsync(_lifetime.Token);
            if (IsConnected && _connection.Health == ConnectionHealth.Healthy)
            {
                ShowConnectedStatus(publicAddress);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private void ShowIdleStatus() =>
        SetStatus(StatusKind.Idle, Localizer.Get("status.disconnected"), Localizer.Get("status.disconnected.detail"));

    private void ShowConnectedStatus(IPAddress? publicAddress)
    {
        if (publicAddress is null)
        {
            SetStatus(StatusKind.Warning, Localizer.Get("status.unverified"), Localizer.Get("status.unverified.detail"));
            return;
        }
        var detail = Localizer.Format("status.connected.detail", publicAddress);
        if (_systemProxyApplied)
        {
            detail += Environment.NewLine + Localizer.Get("status.systemProxyOn");
        }
        if (_environmentProxyApplied)
        {
            detail += Environment.NewLine + Localizer.Get("status.environmentProxyOn");
        }
        SetStatus(StatusKind.Ok, Localizer.Get("status.connected"), detail);
    }

    private void SetStatus(StatusKind kind, string title, string? detail)
    {
        _statusKind = kind;
        StatusTitle = title;
        StatusDetail = detail;
        OnPropertiesChanged(
            nameof(IsStatusBusy), nameof(IsStatusOk), nameof(IsStatusWarning), nameof(IsStatusError),
            nameof(ShowsPowerIcon), nameof(ShowsLinkIcon), nameof(ShowsAlertIcon));
    }

    private static string FailureMessage(ConnectionFailure failure, ushort port) => failure switch
    {
        ConnectionFailure.UsbServiceUnavailable => Localizer.Get(PlatformKey("failure.usbService")),
        ConnectionFailure.DeviceNotFound => Localizer.Get("failure.deviceNotFound"),
        ConnectionFailure.PortInUse => Localizer.Format("failure.portInUse", port),
        ConnectionFailure.SystemProxyFailed => Localizer.Get("failure.systemProxy"),
        ConnectionFailure.EnvironmentProxyFailed => Localizer.Get("failure.environmentProxy"),
        _ => Localizer.Get("failure.invalidOptions"),
    };

    private static string PlatformKey(string prefix)
    {
        if (OperatingSystem.IsWindows())
        {
            return prefix + ".windows";
        }
        return prefix + (OperatingSystem.IsMacOS() ? ".macos" : ".linux");
    }
}
