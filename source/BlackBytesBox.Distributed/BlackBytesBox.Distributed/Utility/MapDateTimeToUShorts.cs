using System;

namespace BlackBytesBox.Distributed.Utility
{
    public static class Utility
    {
        /// <summary>
        /// Maps a DateTime to two ushort values (encoded as strings) representing a high and low part.
        /// </summary>
        /// <remarks>
        /// This method computes the total seconds elapsed since the start of the year, then discards
        /// the lower 6 bits (i.e. one low part unit represents a 64-second interval). The result is split into:
        /// <list type="bullet">
        ///   <item>
        ///     <description><c>LowPart</c>: The lower 16 bits of the shifted seconds.</description>
        ///   </item>
        ///   <item>
        ///     <description><c>HighPart</c>: The upper bits combined with a year-based offset (year * 10).</description>
        ///   </item>
        /// </list>
        /// <para>
        /// Note: The method supports dates only up to the year 6553 to ensure the HighPart remains within limits.
        /// </para>
        /// </remarks>
        /// <param name="inputDate">
        /// An optional DateTime value; if null, DateTime.Now is used. The year must not be greater than 6553.
        /// </param>
        /// <returns>
        /// A tuple containing:
        /// <list type="bullet">
        ///   <item>
        ///     <description><c>HighPart</c>: The computed high part as a string.</description>
        ///   </item>
        ///   <item>
        ///     <description><c>LowPart</c>: The computed low part as a string.</description>
        ///   </item>
        /// </list>
        /// </returns>
        /// <example>
        /// <code>
        /// var result = MapDateTimeToUShorts(new DateTime(2025, 5, 1));
        /// // result.HighPart and result.LowPart hold the computed values.
        /// // One increment in LowPart corresponds to a timespan of 64 seconds.
        /// </code>
        /// </example>
        public static (string HighPart, string LowPart) MapDateTimeToUShorts(DateTime? inputDate = null)
        {
            int discardBits = 6;

            // Use the provided date or default to DateTime.Now.
            DateTime now = inputDate ?? DateTime.Now;

            // Validate that the year does not exceed the maximum supported value.
            if (now.Year > 6553)
            {
                throw new ArgumentOutOfRangeException(nameof(inputDate), "Year must not be greater than 6553.");
            }

            // Calculate the start of the current year.
            DateTime startOfYear = new DateTime(now.Year, 1, 1, 0, 0, 0, now.Kind);

            // Compute total seconds elapsed since the start of the year.
            int seconds = (int)(now - startOfYear).TotalSeconds;

            // Compute the low part by discarding the lower 6 bits (right-shift by discardBits).
            int computedLow = seconds >> discardBits;
            ushort low = (ushort)(computedLow & 0xFFFF);

            // Extract the high part from computedLow (upper 16 bits).
            ushort high = (ushort)(computedLow >> 16);

            // Combine the high part with a year-based offset (year multiplied by 10).
            int highPartFull = high + now.Year * 10;

            // Return the two parts as strings.
            return (highPartFull.ToString(), low.ToString());
        }

        /// <summary>
        /// Reconstructs a DateTime from the provided high and low parts.
        /// </summary>
        /// <remarks>
        /// This method reverses the transformation from MapDateTimeToUShorts by extracting the year from the high part,
        /// reassembling the elapsed seconds (in 64-second intervals), and adding them to the start of the year.
        /// </remarks>
        /// <param name="highPart">The high part string, including the year offset.</param>
        /// <param name="lowPart">The low part string representing the remaining bits.</param>
        /// <returns>A DateTime reconstructed from the provided parts.</returns>
        public static DateTime MapUShortsToDateTime(string highPart, string lowPart)
        {
            int discardBits = 6;

            // Parse the provided parts.
            if (!int.TryParse(lowPart, out int low))
                throw new ArgumentException("Invalid low part.", nameof(lowPart));

            if (!int.TryParse(highPart, out int highFull))
                throw new ArgumentException("Invalid high part.", nameof(highPart));

            // Extract the original year from the high part.
            int year = highFull / 10;

            // Reconstruct the original high bits.
            int computedHigh = highFull - year * 10;

            // Rebuild the computedLow value by combining high and low parts.
            int computedLow = computedHigh << 16 | low;

            // Recover the elapsed seconds (with lost lower resolution bits).
            int seconds = computedLow << discardBits;

            // Calculate the start of the extracted year (using unspecified kind).
            DateTime startOfYear = new DateTime(year, 1, 1, 0, 0, 0, DateTimeKind.Unspecified);

            // Return the DateTime by adding the elapsed seconds.
            return startOfYear.AddSeconds(seconds);
        }
    }
}