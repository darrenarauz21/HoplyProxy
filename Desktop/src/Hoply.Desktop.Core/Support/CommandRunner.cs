using System.ComponentModel;
using System.Diagnostics;
using Hoply.Desktop.Core.SystemProxy;

namespace Hoply.Desktop.Core.Support;

/// <summary>Ejecuta herramientas del sistema con argumentos separados, sin pasar por un shell.</summary>
internal static class CommandRunner
{
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(15);

    public static async Task<string> RunAsync(string fileName, IEnumerable<string> arguments, CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo(fileName)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        Process? process;
        try
        {
            process = Process.Start(startInfo);
        }
        catch (Win32Exception exception)
        {
            throw new SystemProxyException($"No se pudo ejecutar {fileName}.", exception);
        }
        if (process is null)
        {
            throw new SystemProxyException($"No se pudo ejecutar {fileName}.");
        }

        using (process)
        using (var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
        {
            timeout.CancelAfter(Timeout);
            var output = process.StandardOutput.ReadToEndAsync(timeout.Token);
            var error = process.StandardError.ReadToEndAsync(timeout.Token);
            try
            {
                await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                process.Kill(entireProcessTree: true);
                throw;
            }

            if (process.ExitCode != 0)
            {
                var detail = (await error.ConfigureAwait(false)).Trim();
                throw new SystemProxyException($"{fileName} terminó con el código {process.ExitCode}: {detail}");
            }
            return await output.ConfigureAwait(false);
        }
    }

    public static bool IsOnPath(string fileName)
    {
        var path = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrEmpty(path))
        {
            return false;
        }
        return path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries)
            .Any(directory => File.Exists(Path.Combine(directory, fileName)));
    }
}
