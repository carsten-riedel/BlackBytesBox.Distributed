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
    /// A command that retrieves a specified project property from a project file.
    /// It demonstrates asynchronous, cancellation-aware work. On success, the command returns 0;
    /// if errors occur and IgnoreErrors is false, a non-zero error code is returned.
    /// </summary>
    public class CsProjCommand : CancellableCommand<CsProjCommand.Settings>
    {
        private readonly ILogger<CsProjCommand> _logger;
        private readonly ISolutionProjectService _solutionProjectService;

        // Base error code for non-successful execution.
        private int defaultErrorCode = 10;

        /// <summary>
        /// Command settings for CsProjCommand.
        /// </summary>
        public class Settings : CommandSettings
        {
            /// <summary>
            /// Defines the element scope for retrieving the project property.
            /// Valid values are InnerElement (default) or OuterElement.
            /// </summary>
            public enum ElementScope
            {
                OuterElement,
                InnerElement
            }

            /// <summary>
            /// Gets or sets the full path to the project file.
            /// </summary>
            [Description("The full path to the project file.")]
            [CommandOption("-f|--file")]
            public string? FilePath { get; set; }

            /// <summary>
            /// Gets or sets the name of the property to retrieve from the project file.
            /// </summary>
            [Description("The name of the property to retrieve.")]
            [CommandOption("--property")]
            public string? PropertyName { get; set; }

            /// <summary>
            /// Gets or sets the element scope to use when retrieving the project property.
            /// Valid values: InnerElement (default) or OuterElement.
            /// </summary>
            [Description("Specifies the element scope; valid values: InnerElement (default) or OuterElement.")]
            [DefaultValue(ElementScope.InnerElement)]
            [CommandOption("--elementscope")]
            public ElementScope? Scope { get; set; }

            /// <summary>
            /// Gets or sets the minimum log level.
            /// Valid values: Verbose, Debug, Information, Warning, Error, Fatal. Default is Warning.
            /// </summary>
            [Description("The minimum log level, valid values: Verbose, Debug, Information, Warning, Error, Fatal. Default is Warning.")]
            [DefaultValue(LogEventLevel.Warning)]
            [CommandOption("-m|--minLogLevel")]
            public LogEventLevel MinLogLevel { get; init; }

            /// <summary>
            /// Gets or sets a value indicating whether errors should be ignored.
            /// If true, the command returns a success exit code (0) regardless of errors.
            /// </summary>
            [Description("If true, any errors encountered will be ignored and a success exit code (0) is returned.")]
            [DefaultValue(false)]
            [CommandOption("-i|--ignoreerrors")]
            public bool IgnoreErrors { get; init; }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="CsProjCommand"/> class.
        /// </summary>
        /// <param name="logger">The logger used for diagnostic output.</param>
        /// <param name="solutionProjectService">The service used to retrieve project properties.</param>
        public CsProjCommand(ILogger<CsProjCommand> logger, ISolutionProjectService solutionProjectService)
        {
            _solutionProjectService = solutionProjectService ?? throw new ArgumentNullException(nameof(solutionProjectService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Executes the command to retrieve a specified project property from the project file.
        /// </summary>
        /// <remarks>
        /// The method configures the logging level, validates the project file path,
        /// and attempts to retrieve the specified property using the provided element scope.
        /// If errors occur and IgnoreErrors is false, an error-specific exit code is returned.
        /// Otherwise, 0 is returned.
        /// </remarks>
        /// <param name="context">The command context.</param>
        /// <param name="settings">The command settings including file path, property name, element scope, log level, and ignore errors flag.</param>
        /// <param name="cancellationToken">A token that monitors for cancellation requests.</param>
        /// <returns>
        /// An integer exit code: 0 indicates success; non-zero values indicate specific error conditions.
        /// </returns>
        /// <example>
        /// <code>
        /// int result = await ExecuteAsync(context, settings, cancellationToken);
        /// </code>
        /// </example>
        public override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
        {
            // Set the logging level based on the user's settings.
            Program.levelSwitch.MinimumLevel = settings.MinLogLevel;
            _logger.LogDebug("{CommandName} command started.", context.Name);
            string? filePath = settings.FilePath;

            // Validate that a project file path is provided.
            if (string.IsNullOrWhiteSpace(filePath))
            {
                _logger.LogError("Project file path is required. Use -f|--file to specify the project file.");
                return settings.IgnoreErrors ? 0 : defaultErrorCode + 2;
            }

            filePath = filePath.Trim('\'');
            filePath = filePath.Trim('\"');

            // Validate that the project file exists.
            if (!System.IO.File.Exists(filePath))
            {
                _logger.LogError("The specified project file does not exist.");
                return settings.IgnoreErrors ? 0 : defaultErrorCode + 3;
            }

            try
            {
                // Attempt to retrieve the specified project property.
                var projectProperty = await _solutionProjectService.GetProjectProperty(filePath, settings.PropertyName, settings.Scope, cancellationToken);
                if (projectProperty == null)
                {
                    _logger.LogError($"The property '{settings.PropertyName}' could not be retrieved from the project file.");
                    return settings.IgnoreErrors ? 0 : defaultErrorCode + 4;
                }
                else
                {
                    // Output the retrieved property.
                    Console.WriteLine(projectProperty);
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
