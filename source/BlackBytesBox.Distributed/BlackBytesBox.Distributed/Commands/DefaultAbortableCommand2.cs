using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

using Spectre.Console.Cli;

using BlackBytesBox.Distributed.Services;
using BlackBytesBox.Distributed.Spectre;

namespace BlackBytesBox.Distributed.Commands
{

    /// <summary>
    /// A concrete abortable command that demonstrates asynchronous, cancellation-aware work.
    /// After 5 seconds it returns success (0), and if aborted it returns 99.
    /// </summary>
    public class DefaultAbortableCommand2 : CancellableCommand<DefaultAbortableCommand2.Settings>
    {

        private readonly ILogger<DefaultAbortableCommand2> _logger;

        public class Settings : CommandSettings
        {
            public string Name { get; set; } = "World";
        }

        public DefaultAbortableCommand2( ILogger<DefaultAbortableCommand2> logger)
        {
            
            _logger = logger;
        }

        public override async Task<int> ExecuteAsync(CommandContext context, Settings settings, CancellationToken cancellationToken)
        {
          
            _logger.LogInformation("DefaultAbortableCommand started.");

            try
            {
                // Run for 5 seconds unless canceled.
                int totalSeconds = 5;
                for (int i = 0; i < totalSeconds; i++)
                {
                    _logger.LogInformation("Working... {Second}s", i + 1);
                    await Task.Delay(1000, cancellationToken);
                }
                _logger.LogInformation("DefaultAbortableCommand completed normally after 5 seconds.");
                return 0;
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("DefaultAbortableCommand canceled internally.");
                return 99;
            }
        }
    }
}
