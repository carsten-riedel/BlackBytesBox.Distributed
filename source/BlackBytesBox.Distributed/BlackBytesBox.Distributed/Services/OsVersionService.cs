using System.Threading.Tasks;
using System;
using System.Threading;

using Microsoft.Extensions.Logging;
using System.Runtime.InteropServices;


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
        Task ShowOsVersion(CancellationToken cancellationToken);
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
        public async Task ShowOsVersion(CancellationToken cancellationToken)
        {
            _logger.LogDebug("Displaying the operating system version...");
            Console.WriteLine($"{RuntimeInformation.OSDescription}");
            _logger.LogDebug("Operating system version displayed.");
        }
    }
}