using System.Threading.Tasks;
using System;
using System.Threading;

using Microsoft.Extensions.Logging;


namespace BlackBytesBox.Distributed.Services
{

    /// <summary>
    /// A service for retrieving and displaying the operating system version.
    /// </summary>
    public interface IOsVersionService
    {
        /// <summary>
        /// Displays the current operating system version.
        /// </summary>
        Task ShowOsVersion(int delay, CancellationToken cancellationToken);
    }

    /// <summary>
    /// A concrete implementation of IOsVersionService that writes the OS version to the console.
    /// </summary>
    public class OsVersionService : IOsVersionService
    {
        private readonly ILogger<OsVersionService> _logger;

        public OsVersionService(ILogger<OsVersionService> logger)
        {
            _logger = logger;
        }

        /// <inheritdoc />
        public async Task ShowOsVersion(int delay,CancellationToken cancellationToken)
        {
            _logger.LogDebug("Displaying the operating system version...");
            await Task.Delay(delay, cancellationToken);
            Console.WriteLine($"{Environment.OSVersion}");
            _logger.LogDebug("Operating system version displayed.");
        }
    }
}