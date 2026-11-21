using System.Net;

namespace Hoply.Desktop.Core.Verification;

public interface IConnectionVerifier
{
    /// <summary>IP pública vista a través del proxy, o null si no hubo respuesta válida.</summary>
    Task<IPAddress?> TryGetPublicAddressAsync(string proxyHost, ushort port, CancellationToken cancellationToken);
}

/// <summary>Pide la IP pública a través del proxy del iPhone: si responde, la conexión funciona de punta a punta.</summary>
public sealed class ConnectionVerifier : IConnectionVerifier
{
    private static readonly Uri PublicAddressEndpoint = new("https://ifconfig.me/ip");
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(12);
    private const int MaxResponseBytes = 256;
    private const int MaxAddressLength = 45;

    public async Task<IPAddress?> TryGetPublicAddressAsync(string proxyHost, ushort port, CancellationToken cancellationToken)
    {
        using var handler = new HttpClientHandler
        {
            Proxy = new WebProxy(new Uri($"http://{proxyHost}:{port}")),
            UseProxy = true,
        };
        using var client = new HttpClient(handler) { Timeout = Timeout, MaxResponseContentBufferSize = MaxResponseBytes };

        try
        {
            var body = (await client.GetStringAsync(PublicAddressEndpoint, cancellationToken).ConfigureAwait(false)).Trim();
            return body.Length <= MaxAddressLength && IPAddress.TryParse(body, out var address) ? address : null;
        }
        catch (HttpRequestException)
        {
            return null;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
    }
}
