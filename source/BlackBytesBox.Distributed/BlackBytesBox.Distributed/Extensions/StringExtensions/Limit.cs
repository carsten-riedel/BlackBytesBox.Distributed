using System;
using System.Collections.Generic;
using System.Linq;

namespace BlackBytesBox.Distributed.Extensions.StringExtensions
{
    public static class StringExtensions
    {
        /// <summary>
        /// Limits the string to a maximum number of characters.
        /// If the string is longer than <paramref name="maxLength"/>, it returns a substring of the first <paramref name="maxLength"/> characters.
        /// Otherwise, it returns the original string.
        /// </summary>
        /// <param name="input">The input string.</param>
        /// <param name="maxLength">The maximum number of characters to allow.</param>
        /// <returns>A string limited to <paramref name="maxLength"/> characters.</returns>
        /// <exception cref="ArgumentNullException">Thrown if <paramref name="input"/> is null.</exception>
        /// <exception cref="ArgumentOutOfRangeException">Thrown if <paramref name="maxLength"/> is negative.</exception>
        public static string Limit(this string input, int maxLength)
        {
            if (input == null)
                throw new ArgumentNullException(nameof(input));
            if (maxLength < 0)
                throw new ArgumentOutOfRangeException(nameof(maxLength), "maxLength must be non-negative.");

            return input.Length <= maxLength ? input : input.Substring(0, maxLength);
        }

        public static string PadLimit(this string input, int maxLength)
        {
            input = input.PadRight(maxLength);
            input = input.Limit(maxLength);
            return input;
        }

        public static bool HasOneOrNoneSlash(this string input)
        {
            // Return true for null or empty strings as they don't contain any slash
            if (string.IsNullOrEmpty(input))
            {
                return true;
            }

            int slashCount = 0;
            foreach (char c in input)
            {
                if (c == '/')
                {
                    slashCount++;
                    if (slashCount > 1)
                    {
                        return false;
                    }
                }
            }
            return true;
        }

        public static List<string> GetSegments(this string input)
        {
            if (input == null)
            {
                return null;
            }

            // Split the input string by '/' and convert the resulting array to a list.
            return input.Split(new char[] { '/' }, StringSplitOptions.None).ToList();
        }

    }
}
