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
    public class SlnCommand : CancellableCommand<SlnCommand.Settings>
    {
        private readonly ILogger<SlnCommand> _logger;
        private readonly ISolutionProjectService _solutionProjectService;

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
            [Description("The location of the solution file.")]
            [CommandOption("-s|--solution")]
            public string? SolutionLocation { get; set; }

            [Description("Minimum loglevel, valid values => Verbose,Debug,Information,Warning,Error,Fatal")]
            [DefaultValue(LogEventLevel.Warning)]
            [CommandOption("-l|--loglevel")]
            public LogEventLevel LogEventLevel { get; init; }

            [Description("Throws and errorcode if command is not found.")]
            [DefaultValue(false)]
            [CommandOption("-f|--forceSuccess")]
            public bool ForceSuccess { get; init; }
        }

        public SlnCommand(ILogger<SlnCommand> logger, ISolutionProjectService solutionProjectService)
        {
            _solutionProjectService = solutionProjectService ?? throw new ArgumentNullException(nameof(solutionProjectService));
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
            _logger.LogDebug("{CommandName} command started.", context.Name);

            if (string.IsNullOrWhiteSpace(settings.SolutionLocation))
            {
                _logger.LogError("Solution location is required. -s|--solution");
                return BaseErrorCode+2;
            }

            if (!System.IO.File.Exists(settings.SolutionLocation))
            {
                _logger.LogError("Solution location is not a valid file.");
                return BaseErrorCode + 3;
            }

            try
            {
                var projectsAbsolutePaths = await _solutionProjectService.GetCsProjAbsolutPathsFromSolutions(settings.SolutionLocation, cancellationToken);

                for (int i = 0; i < projectsAbsolutePaths.Count; i++)
                {
                    Console.WriteLine(projectsAbsolutePaths[i]);
                }

                return 0;
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