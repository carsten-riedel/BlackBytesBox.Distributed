using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using Spectre.Console.Cli;

namespace BlackBytesBox.Distributed.Spectre
{
    /// <summary>
    /// A hosted service that runs the Spectre.CommandApp asynchronously.
    /// When the CommandApp finishes (or is canceled), it signals the host to stop.
    /// If an exception occurs, it sets a default exit code if the command hasn’t already done so.
    /// </summary>
    public class CommandAppHostedService : IHostedService
    {
        private readonly CommandApp _commandApp;
        private readonly string[] _args;
        private readonly ILogger<CommandAppHostedService> _logger;
        private readonly IHostApplicationLifetime _hostApplicationLifetime;
        public static int? CommandAppExitCode { get; set; }
        private Task? _commandAppTask;
        public static CancellationTokenSource CommandAppShutdownTokenSource = new CancellationTokenSource();

        public CommandAppHostedService(CommandApp commandApp, ILogger<CommandAppHostedService> logger, IHostApplicationLifetime hostApplicationLifetime)
        {
            _commandApp = commandApp;
            _logger = logger;
            _hostApplicationLifetime = hostApplicationLifetime;

            var allArgs = Environment.GetCommandLineArgs();
            // Exclude the first element which is the executable or DLL name
            var rawArgs = allArgs.Skip(1).ToArray();

            _args = rawArgs;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            // Register a callback when the host is stopping to cancel the CommandApp's token.
            _hostApplicationLifetime.ApplicationStopping.Register(() =>
            {
                _logger.LogDebug("Host is stopping; signaling CommandApp for graceful shutdown.");
                if (!CommandAppShutdownTokenSource.IsCancellationRequested)
                {
                    CommandAppShutdownTokenSource.Cancel();
                }
            });

            // Register a callback so that if ApplicationStoppingCts is cancelled externally,
            // the host application is also instructed to stop.
            CommandAppShutdownTokenSource.Token.Register(() =>
            {
                // Optionally check if host is not already stopping to avoid duplicate calls.
                if (!_hostApplicationLifetime.ApplicationStopping.IsCancellationRequested)
                {
                    _logger.LogDebug("External cancellation detected; signaling host to stop.");
                    _hostApplicationLifetime.StopApplication();
                }
            });

            _commandApp.Configure(config =>
            {
                // Register a callback when the command is canceled to cancel the CommandApp's token.
                var ss = config.Settings;
            });

            _commandAppTask = Task.Run(async () =>
            {
                CommandAppHostedService.CommandAppExitCode = await _commandApp.RunAsync(_args);
                if (!_hostApplicationLifetime.ApplicationStopping.IsCancellationRequested)
                {
                    _hostApplicationLifetime.StopApplication();
                }
            });

            await Task.CompletedTask;
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogDebug("Stopping SpectreCommandAppHostedService.");

            if (_commandAppTask != null)
            {
                await _commandAppTask;
            }
        }
    }
}