using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using Spectre.Console.Cli;

using BlackBytesBox.Distributed.Extensions.SpectreHostExtensions;

namespace BlackBytesBox.Distributed.Spectre
{
    /// <summary>
    /// An abstract base class for commands designed to be abortable via cancellation.
    /// Inherits from Spectre.Console.Cli's Command<TSettings> and overrides Execute to call the async version.
    /// This version obtains the shared ExitCodeHolder from SpectreHostExtensions.
    /// </summary>
    public abstract class CancellableCommand<TSettings> : Command<TSettings> where TSettings : CommandSettings, new()
    {
        public override int Execute(CommandContext context, TSettings settings)
        {
            int exitCode = ExecuteAsync(context, settings, CommandAppHostedService.CommandAppShutdownTokenSource.Token).GetAwaiter().GetResult();
            if (!CommandAppHostedService.CommandAppExitCode.HasValue)
            {
                CommandAppHostedService.CommandAppExitCode = exitCode;
            }

            return exitCode;
        }

        public abstract Task<int> ExecuteAsync(CommandContext context, TSettings settings, CancellationToken cancellationToken);
    }
}