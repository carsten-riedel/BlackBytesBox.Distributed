using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Extensions.Logging;

using Serilog.Events;

using Spectre.Console;
using Spectre.Console.Cli;

using BlackBytesBox.Distributed.Services;
using BlackBytesBox.Distributed.Spectre;

namespace BlackBytesBox.Distributed.Commands
{
    /// <summary>
    /// A concrete abortable command that demonstrates asynchronous, cancellation-aware work.
    /// After 5 seconds it returns success (0), and if aborted it returns 99.
    /// </summary>
    public class VsCodeCommand : CancellableCommand<VsCodeCommand.Settings>
    {
        //private readonly IGreeter _greeter;
        private readonly ILogger<VsCodeCommand> _logger;

        private readonly IOsVersionService _osVersionService;

        private int baseErrorCode = 10;

        private bool forceSuccess = false;

        private int BaseErrorCode
        {
            get
            {
                if (forceSuccess)
                {
                    return 0;
                }
                else
                {
                    return baseErrorCode;
                }
            }
        }

        public class Settings : CommandSettings
        {
            [Description("Minimum loglevel, valid values => Verbose,Debug,Information,Warning,Error,Fatal")]
            [DefaultValue(LogEventLevel.Information)]
            [CommandOption("-l|--loglevel")]
            public LogEventLevel LogEventLevel { get; init; }
            public int Delay { get; init; }

            [Description("Throws and errorcode if command is not found.")]
            [DefaultValue(false)]
            [CommandOption("-f|--forceSuccess")]
            public bool ForceSuccess { get; init; }
        }

        public VsCodeCommand(ILogger<VsCodeCommand> logger, IOsVersionService osVersionService)
        {
            _osVersionService = osVersionService ?? throw new ArgumentNullException(nameof(osVersionService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }


        /// <summary>
        /// Downloads and installs Visual Studio Code silently.
        /// </summary>
        /// <remarks>
        /// This method downloads the latest stable VS Code installer for 64-bit Windows from the official update URL,
        /// saves it to a temporary file, and executes it with silent installation arguments.
        /// </remarks>
        /// <param name="context">The command context.</param>
        /// <param name="settings">The settings for the command, including log level and force success flag.</param>
        /// <param name="cancellationToken">A token to monitor for cancellation requests.</param>
        /// <returns>An integer representing the exit code of the installer process.</returns>
        /// <example>
        /// <code>
        /// int result = await ExecuteAsync(context, settings, cancellationToken);
        /// </code>
        /// </example>
        public override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
        {
            Program.levelSwitch.MinimumLevel = settings.LogEventLevel;
            forceSuccess = settings.ForceSuccess;
            _logger.LogInformation("{CommandName} command started.", context.Name);

            try
            {
                // Define the VS Code installer URL and temporary output path.
                var installerUrl = "https://update.code.visualstudio.com/latest/win32-x64-user/stable";
                var tempPath = Path.GetTempPath();
                var outputPath = Path.Combine(tempPath, "VSCodeSetup.exe");

                _logger.LogInformation("Downloading VS Code installer from {InstallerUrl} to {OutputPath}.", installerUrl, outputPath);

                // Download the installer asynchronously.
                using (var httpClient = new HttpClient())
                {
                    using (var response = await httpClient.GetAsync(installerUrl, cancellationToken))
                    {
                        response.EnsureSuccessStatusCode();
                        using (var fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            await response.Content.CopyToAsync(fs, cancellationToken);
                        }
                    }
                }

                _logger.LogInformation("Successfully downloaded VS Code installer to {OutputPath}.", outputPath);

                // Prepare to execute the installer silently.
                var startInfo = new ProcessStartInfo
                {
                    FileName = outputPath,
                    Arguments = "/VERYSILENT /mergetasks=!runcode",
                    CreateNoWindow = true,
                    UseShellExecute = false
                };

                using (var process = new Process { StartInfo = startInfo })
                {
                    process.Start();
                    _logger.LogInformation("Started VS Code installer process with PID {PID}.", process.Id);
                    await process.WaitForExitAsync(cancellationToken);
                    var exitCode = process.ExitCode;
                    _logger.LogInformation("VS Code installer process exited with code {ExitCode}.", exitCode);
                    return exitCode;
                }
            }
            catch (OperationCanceledException ex)
            {
                _logger.LogError(ex, "{CommandName} command canceled internally.", context.Name);
                return BaseErrorCode;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "{CommandName} command encountered an error.", context.Name);
                return BaseErrorCode + 1;
            }
        }

    }
}