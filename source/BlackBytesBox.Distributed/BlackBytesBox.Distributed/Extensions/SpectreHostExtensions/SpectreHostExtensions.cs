using System;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using Spectre.Console.Cli;

using BlackBytesBox.Distributed.Spectre;

namespace BlackBytesBox.Distributed.Extensions.SpectreHostExtensions
{
    /// <summary>
    /// Provides extension methods to register Spectre.CommandApp within the Generic Host.
    /// </summary>
    public static class SpectreHostExtensions
    {
        /// <summary>
        /// Configures and registers the Spectre.CommandApp as well as the hosted service that runs it asynchronously.
        /// Also registers the shared ExitCodeHolder.
        /// </summary>
        public static IHostBuilder AddCommandAppHostedService(this IHostBuilder builder, Action<IConfigurator> configure, string[] args)
        {
            builder.ConfigureServices((context, services) =>
            {
                // Create a TypeRegistrar to integrate Spectre with the Microsoft DI container.
                var registrar = new Spectre.TypeRegistrar(services);
                // Create the CommandApp instance.
                var commandApp = new CommandApp(registrar);
                // Allow the caller to configure the command pipeline.
                commandApp.Configure(configure);
                // Register the CommandApp in DI.
                services.AddSingleton(commandApp);
                services.AddHostedService<CommandAppHostedService>();
            });
            return builder;
        }
    }
}