using System;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

using Spectre.Console;

namespace BlackBytesBox.Distributed.Spectre
{
    /// <summary>
    /// Represents the inputs used for markup formatting.
    /// </summary>
    public class MarkupResult
    {
        /// <summary>
        /// Gets or sets the original message template.
        /// </summary>
        public string MessageTemplate { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the array of property values used for replacement.
        /// </summary>
        public object?[] PropertyValues { get; set; } = Array.Empty<object?>();
    }

    /// <summary>
    /// Provides custom console output methods using Spectre.Console markup.
    /// </summary>
    public static class SpectreConsole
    {
        /// <summary>
        /// Asynchronously calls the synchronous WriteLine method.
        /// </summary>
        /// <param name="messageTemplate">The message template string containing placeholders.</param>
        /// <param name="markupTemplate">
        /// An array of markup styles—one for each replacement. For example, <c>[underline red]</c> for the first placeholder,
        /// or an empty string if no style is desired.
        /// </param>
        /// <param name="propertyValues">
        /// The property values to substitute into the placeholders.
        /// </param>
        /// <returns>
        /// A task whose result is a <see cref="MarkupResult"/> that encapsulates the original inputs.
        /// </returns>
        public static Task<MarkupResult> WriteTemplateAsync(
            string messageTemplate,
            object?[] markupTemplate,
            params object?[]? propertyValues)
        {
            return Task.Run(() => WriteLine(messageTemplate, markupTemplate, propertyValues));
        }

        /// <summary>
        /// Processes a message template by replacing its placeholders with property values styled with optional markup.
        /// Immediately outputs the formatted message to the console.
        /// Returns a <see cref="MarkupResult"/> that encapsulates the original inputs.
        /// </summary>
        /// <param name="messageTemplate">
        /// The message template string containing placeholders (e.g. "{name} World! Today is {day}.").
        /// </param>
        /// <param name="markupTemplate">
        /// An array of markup styles—one for each replacement. For example, <c>[underline red]</c> for the first placeholder,
        /// or an empty string if no style is desired.
        /// </param>
        /// <param name="propertyValues">
        /// The property values to substitute into the placeholders. They are processed in order.
        /// </param>
        /// <returns>
        /// A <see cref="MarkupResult"/> that encapsulates the original inputs.
        /// </returns>
        /// <exception cref="ArgumentNullException">Thrown if <paramref name="messageTemplate"/> is null.</exception>
        public static MarkupResult WriteLine(
            string messageTemplate,
            object?[] markupTemplate,
            params object?[]? propertyValues)
        {
            if (messageTemplate == null)
            {
                throw new ArgumentNullException(nameof(messageTemplate));
            }

            // Treat null arrays as empty.
            markupTemplate = markupTemplate ?? Array.Empty<object?>();
            propertyValues = propertyValues ?? Array.Empty<object?>();

            int matchIndex = 0;

            // Replace placeholders (any text within curly braces) in order.
            string formattedMessage = Regex.Replace(messageTemplate, @"\{[^}]+\}", match =>
            {
                // If there is a corresponding property value, perform the replacement.
                if (matchIndex < propertyValues.Length)
                {
                    // Get the property value (default to empty string if null).
                    string valueStr = propertyValues[matchIndex]?.ToString() ?? string.Empty;

                    // Get the style if provided; otherwise use empty string.
                    string style = matchIndex < markupTemplate.Length
                        ? markupTemplate[matchIndex]?.ToString() ?? string.Empty
                        : string.Empty;

                    // If a non-empty style is provided, wrap the value with it.
                    string replacement = !string.IsNullOrWhiteSpace(style)
                        ? $"{style}{valueStr}[/]"
                        : valueStr;
                    matchIndex++;
                    return replacement;
                }
                else
                {
                    // Leave unmatched placeholders unchanged.
                    return match.Value;
                }
            });

            for (int i = 0; i < propertyValues.Length; i++)
            {
                if (propertyValues[i] is string x)
                {
                    propertyValues[i] = x.Trim();
                }
            }

            // Output the formatted message to the console.
            AnsiConsole.MarkupLine(formattedMessage);

            // Return the inputs wrapped in a MarkupResult instance.
            return new MarkupResult
            {
                MessageTemplate = messageTemplate,
                PropertyValues = propertyValues
            };
        }
    }
}