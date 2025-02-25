using System.Collections.Generic;

using Serilog.Sinks.SystemConsole.Themes;

namespace BlackBytesBox.Distributed.Serilog
{
    public static partial class Theme
    {
        public static AnsiConsoleTheme ClarionDusk { get; } = new AnsiConsoleTheme(new Dictionary<ConsoleThemeStyle, string>
        {
            [ConsoleThemeStyle.Text] = "\u001b[38;5;231m",
            [ConsoleThemeStyle.SecondaryText] = "\u001b[38;5;250m",
            [ConsoleThemeStyle.TertiaryText] = "\u001b[38;5;246m",
            [ConsoleThemeStyle.Invalid] = "\u001b[38;5;160m",
            [ConsoleThemeStyle.Null] = "\u001b[38;5;59m",
            [ConsoleThemeStyle.Name] = "\u001b[38;5;45m",
            [ConsoleThemeStyle.String] = "\u001b[38;5;186m",
            [ConsoleThemeStyle.Number] = "\u001b[38;5;220m",
            [ConsoleThemeStyle.Boolean] = "\u001b[38;5;39m",
            [ConsoleThemeStyle.Scalar] = "\u001b[38;5;78m",
            [ConsoleThemeStyle.LevelVerbose] = "\u001b[38;5;244m",
            [ConsoleThemeStyle.LevelDebug] = "\u001b[38;5;81m",
            [ConsoleThemeStyle.LevelInformation] = "\u001b[38;5;76m",
            [ConsoleThemeStyle.LevelWarning] = "\u001b[38;5;226m",
            [ConsoleThemeStyle.LevelError] = "\u001b[38;5;202m",
            [ConsoleThemeStyle.LevelFatal] = "\u001b[38;5;198m\u001b[48;5;52m",
        });
    }
}