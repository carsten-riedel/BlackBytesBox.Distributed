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
    /// A command that retrieves a project property, demonstrating asynchronous and cancellation-aware work.
    /// It validates the project file location and attempts to fetch the "IsPublishable" property.
    /// Returns 0 on success and appropriate error codes on failures.
    /// </summary>
    public class CsProjCommand : CancellableCommand<CsProjCommand.Settings>
    {
        private readonly ILogger<CsProjCommand> _logger;
        private readonly ISolutionProjectService _solutionProjectService;

        private int baseErrorCode = 10;
        private bool forceSuccess = false;

        private int BaseErrorCode
        {
            get
            {
                return forceSuccess ? 0 : baseErrorCode;
            }
        }

        /// <summary>
        /// Command settings for ProjectPropertyCommand.
        /// </summary>
        public class Settings : CommandSettings
        {
            /// <summary>
            /// Defines the scope for retrieving the project property.
            /// </summary>
            public enum ScopeType
            {
                OuterElement,
                InnerElement
            }

            [Description("The location of the project file.")]
            [CommandOption("--location")]
            public string? FileLocation { get; set; }

            [Description("The name of the property to read.")]
            [CommandOption("--property")]
            public string? PropertyName { get; set; }

            [Description("Specifies the scope of the project property; valid values are InnerElement or OuterElement.")]
            [DefaultValue(ScopeType.InnerElement)]
            [CommandOption("--scope")]
            public ScopeType? Scope { get; set; }

            [Description("Specifies the minimum log level (e.g., Verbose, Debug, Information, Warning, Error, Fatal).")]
            [DefaultValue(LogEventLevel.Warning)]
            [CommandOption("--loglevel")]
            public LogEventLevel LogEventLevel { get; init; }

            [Description("If set to true, forces the command to return success (0) regardless of errors.")]
            [DefaultValue(false)]
            [CommandOption("--forceSuccess")]
            public bool ForceSuccess { get; init; }
        }

        /// <summary>
        /// Initializes a new instance of the ProjectPropertyCommand class.
        /// </summary>
        /// <param name="logger">The logger for diagnostic output.</param>
        /// <param name="solutionProjectService">The service used to retrieve project properties.</param>
        public CsProjCommand(ILogger<CsProjCommand> logger, ISolutionProjectService solutionProjectService)
        {
            _solutionProjectService = solutionProjectService ?? throw new ArgumentNullException(nameof(solutionProjectService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Executes the command to retrieve the "IsPublishable" property from the specified project file.
        /// </summary>
        /// <remarks>
        /// This method first configures the logging level based on settings and validates the project file path.
        /// It then attempts to retrieve the "IsPublishable" property using the provided scope.
        /// If the file path is missing or invalid, or if any error occurs during retrieval, a corresponding error code is returned.
        /// </remarks>
        /// <param name="context">The command context.</param>
        /// <param name="settings">The command settings including project location, scope, log level, and force success flag.</param>
        /// <param name="cancellationToken">A token that monitors for cancellation requests.</param>
        /// <returns>An integer representing the exit code: 0 for success, or a non-zero error code for failures.</returns>
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

            if (string.IsNullOrWhiteSpace(settings.FileLocation))
            {
                _logger.LogError("Project location is required. Use --location to specify the project file.");
                return BaseErrorCode + 2;
            }

            if (!System.IO.File.Exists(settings.FileLocation))
            {
                _logger.LogError("Project --location is not a valid file.");
                return BaseErrorCode + 3;
            }

            try
            {
                var projectProperty = await _solutionProjectService.GetProjectProperty(settings.FileLocation, settings.PropertyName, settings.Scope, cancellationToken);
                if (projectProperty == null)
                {
                    _logger.LogError($"The '{settings.PropertyName}' property could not be retrieved from the project file.");
                    return BaseErrorCode + 4;
                }
                else
                {
                    Console.WriteLine(projectProperty);
                }
                return 0;
            }
            catch (OperationCanceledException ex)
            {
                _logger.LogError(ex, "{CommandName} command was canceled.", context.Name);
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
