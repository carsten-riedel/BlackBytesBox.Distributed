using System;
using System.ComponentModel;
using System.Threading;
using System.Threading.Tasks;

using BlackBytesBox.Distributed.Services;
using BlackBytesBox.Distributed.Spectre;

using Microsoft.Extensions.Logging;

using Serilog.Events;

using Spectre.Console.Cli;

namespace BlackBytesBox.Distributed.Commands
{
    /// <summary>
    /// A command that retrieves absolute paths of csproj files from a solution file.
    /// This command demonstrates asynchronous, cancellation-aware work. On success, it returns 0.
    /// If errors occur and IgnoreErrors is false, non-zero exit codes are returned; otherwise, 0 is returned.
    /// </summary>
    public class SlnCommand : CancellableCommand<SlnCommand.Settings>
    {
        private readonly ILogger<SlnCommand> _logger;
        private readonly ISolutionProjectService _solutionProjectService;

        // The base error code used when returning error exit codes.
        private int defaultErrorCode = 10;

        /// <summary>
        /// Command settings for SlnCommand.
        /// </summary>
        public class Settings : CommandSettings
        {
            /// <summary>
            /// Gets or sets the full path to the solution file.
            /// </summary>
            [Description("The full path to the solution file.")]
            [CommandOption("-f|--file")]
            public string? FilePath { get; set; }

            /// <summary>
            /// Gets or sets the minimum log level (valid values: Verbose, Debug, Information, Warning, Error, Fatal).
            /// </summary>
            [Description("The minimum log level, valid values: Verbose, Debug, Information, Warning, Error, Fatal. Default is Warning.")]
            [DefaultValue(LogEventLevel.Warning)]
            [CommandOption("-m|--minLogLevel")]
            public LogEventLevel MinLogLevel { get; init; }

            /// <summary>
            /// Gets or sets a value indicating whether the command should ignore errors.
            /// If true, the command always returns 0 regardless of errors.
            /// </summary>
            [Description("If true, any errors encountered will be ignored and a success exit code (0) is returned.")]
            [DefaultValue(false)]
            [CommandOption("-i|--ignoreerrors")]
            public bool IgnoreErrors { get; init; }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="SlnCommand"/> class.
        /// </summary>
        /// <param name="logger">The logger instance for diagnostic output.</param>
        /// <param name="solutionProjectService">The service used to retrieve csproj file paths from a solution.</param>
        public SlnCommand(ILogger<SlnCommand> logger, ISolutionProjectService solutionProjectService)
        {
            _solutionProjectService = solutionProjectService ?? throw new ArgumentNullException(nameof(solutionProjectService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Executes the command to retrieve csproj file paths from the specified solution file.
        /// </summary>
        /// <remarks>
        /// This method validates the solution file path, sets the logging level, and attempts to retrieve
        /// all csproj file paths contained within the solution. If any error occurs and IgnoreErrors is false,
        /// an error-specific exit code is returned. If IgnoreErrors is true, 0 is returned even in error cases.
        /// </remarks>
        /// <param name="context">The command context.</param>
        /// <param name="settings">The settings for the command, including file path, log level, and ignore errors flag.</param>
        /// <param name="cancellationToken">A token that monitors for cancellation requests.</param>
        /// <returns>
        /// An integer representing the exit code:
        /// 0 indicates success,
        /// non-zero codes indicate specific error conditions unless errors are being ignored.
        /// </returns>
        /// <example>
        /// <code>
        /// int result = await ExecuteAsync(context, settings, cancellationToken);
        /// </code>
        /// </example>
        public override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
        {
            Program.levelSwitch.MinimumLevel = settings.MinLogLevel;
            _logger.LogDebug("{CommandName} command started.", context.Name);

            // Validate that a solution file path is provided.
            if (string.IsNullOrWhiteSpace(settings.FilePath))
            {
                _logger.LogError("Solution file path is required. Use -f|--file to specify the solution file.");
                return settings.IgnoreErrors ? 0 : defaultErrorCode + 2;
            }

            // Validate that the solution file exists.
            if (!System.IO.File.Exists(settings.FilePath))
            {
                _logger.LogError("The specified solution file does not exist.");
                return settings.IgnoreErrors ? 0 : defaultErrorCode + 3;
            }

            try
            {
                var projectsAbsolutePaths = await _solutionProjectService.GetCsProjAbsolutPathsFromSolutions(settings.FilePath, cancellationToken);

                // Output each discovered csproj file path.
                foreach (var path in projectsAbsolutePaths)
                {
                    Console.WriteLine(path);
                }

                return 0;
            }
            catch (OperationCanceledException ex)
            {
                _logger.LogError(ex, "{CommandName} command was canceled.", context.Name);
                return settings.IgnoreErrors ? 0 : defaultErrorCode;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "{CommandName} command encountered an error.", context.Name);
                return settings.IgnoreErrors ? 0 : defaultErrorCode + 1;
            }
        }
    }
}
