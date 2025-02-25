function Split-Segments {
    <#
    .SYNOPSIS
        Splits a string containing "/" or "\" separated segments into an array.

    .DESCRIPTION
        This function takes an input string where segments are separated by "/" or "\" characters,
        returns an array containing each segment with the first segment in lowercase and subsequent segments in uppercase,
        and replaces any invalid file name characters with an underscore.
        It validates that the number of segments does not exceed a specified maximum (default is 2) and that none of the segments match any forbidden values (case-insensitive).

    .PARAMETER InputString
        The string to be split. It should contain segments separated by "/" or "\".

    .PARAMETER MaxSegments
        (Optional) The maximum allowed number of segments. Defaults to 2. If the number of segments exceeds this value, an error is thrown and the script exits with code 1.

    .PARAMETER ForbiddenSegments
        (Optional) An array of forbidden segment values. If any segment matches one of these (case-insensitive), an error is thrown and the script exits with code 1.
        Defaults to @("latest", "foo").

    .EXAMPLE
        PS> Split-Segments -InputString "Bar/Baz" 
        Returns: @("bar", "BAZ")

    .EXAMPLE
        PS> Split-Segments -InputString "latest\bar" -ForbiddenSegments @("latest","foo")
        Throws an error and exits with code 1 because "latest" is a forbidden segment.

    .NOTES
        - Filters out any empty segments that may result from consecutive "/" or "\" characters.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString,

        [Parameter()]
        [int]$MaxSegments = 2,

        [Parameter()]
        [string[]]$ForbiddenSegments = @("latest", "foo")
    )

    if (-not $InputString) {
        return @()
    }
    
    # Split the input string by "/" or "\" and filter out any empty segments.
    $segments = ($InputString -split '[\\/]')
    
    # Check if the number of segments exceeds the maximum allowed.
    if ($segments.Count -gt $MaxSegments) {
        Write-Error "Number of segments ($($segments.Count)) exceeds the maximum allowed ($MaxSegments)."
        exit 1
    }
    
    # Normalize forbidden segments to lower case.
    $forbiddenLower = $ForbiddenSegments | ForEach-Object { $_.ToLower() }
    
    # Check for any forbidden segments (case-insensitive).
    foreach ($segment in $segments) {
        if ($forbiddenLower -contains $segment.ToLower()) {
            Write-Error "Segment '$segment' is forbidden."
            exit 1
        }
    }

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    

    # Replace invalid characters in each segment.
    for ($i = 0; $i -lt $segments.Count; $i++) {
        foreach ($char in $invalidChars) {
            $pattern = [Regex]::Escape($char)
            $segments[$i] = $segments[$i] -replace $pattern, "-"
        }
        # Lowercase the first segment and uppercase the rest.
        if ($i -eq 0) {
            $segments[$i] = $segments[$i].ToLower() -replace " ", "_"
        }
        else {
            $segments[$i] = $segments[$i].ToUpper() -replace " ", "_"
        }
    }
    
    # Return the segments array.
    return @($segments)
}

function Translate-FirstSegment {
    <#
    .SYNOPSIS
        Translates the first segment of an array using a provided translation hashtable.
    
    .DESCRIPTION
        This function accepts an array of segments and a translation hashtable.
        It reads the first segment and performs a case-insensitive lookup in the translation table.
        If a match is found, the first segment is replaced with its corresponding translated value.
        If no match is found, the first segment is set to the value of the DefaultTranslation parameter (default is "unknown").
    
    .PARAMETER Segments
        The array of segments to be processed.
    
    .PARAMETER TranslationTable
        A hashtable that defines the mapping of original segments to translated segments.
        For example: @{ "testing" = "tofooo"; "testing2" = "tofooo"; "feat" = "dev" }.
    
    .PARAMETER DefaultTranslation
        (Optional) The default value to assign if the first segment is not found in the translation table.
        Defaults to "unknown".
    
    .EXAMPLE
        $segments = @("testing", "BAZ")
        $translationTable = @{
            "testing"  = "tofooo"
            "testing2" = "tofooo"
            "feat"     = "dev"
        }
        $newSegments = Translate-FirstSegment -Segments $segments -TranslationTable $translationTable
        # $newSegments now equals @("tofooo", "BAZ")
    
    .EXAMPLE
        $segments = @("nonexistent", "BAZ")
        $translationTable = @{
            "testing"  = "tofooo"
            "testing2" = "tofooo"
            "feat"     = "dev"
        }
        $newSegments = Translate-FirstSegment -Segments $segments -TranslationTable $translationTable -DefaultTranslation "defaultValue"
        # $newSegments now equals @("defaultValue", "BAZ")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Segments,
    
        [Parameter(Mandatory = $true)]
        [hashtable]$TranslationTable,

        [Parameter()]
        [string]$DefaultTranslation = "unknown"
    )
    
    if (-not $Segments -or $Segments.Count -eq 0) {
        Write-Error "Segments array is empty."
        return $Segments
    }
    
    $firstSegment = $Segments[0]
    
    # Perform a case-insensitive lookup in the translation table.
    $translated = $null
    foreach ($key in $TranslationTable.Keys) {
        if ($firstSegment -ieq $key) {
            $translated = $TranslationTable[$key].ToLower()
            break
        }
    }
    
    if ( -not ($null -eq $translated) ) {
        $Segments[0] = $translated
    }
    else {
        $Segments[0] = $DefaultTranslation
    }
    
    return @($Segments)
}


function Join-Segmentsold {
    <#
    .SYNOPSIS
        Joins an array of segments using the current directory separator.
    
    .DESCRIPTION
        This function takes an array of string segments and combines them into a single path,
        using the current system directory separator. An optional override array can be applied
        to change segments positionally. For each index, if the corresponding element in the override
        array is neither `$null` nor an empty string, the segment is replaced with that value;
        otherwise, the original segment is kept.
    
    .PARAMETER Segments
        An array of strings representing the segments to join.
    
    .PARAMETER OverrideArray
        (Optional) A string array defining positional overrides for the segments. Defaults to `$null`.
        For example: @("tofooo", $null, "dev")
        In this example, the first segment is replaced with "tofooo", the second segment remains unchanged,
        and the third segment is replaced with "dev".
    
    .EXAMPLE
        PS> $segments = @("testing", "value2", "feat")
        PS> Join-Segments -Segments $segments -OverrideArray @( $null, "latest" )
        Returns: "testing\<sep>latest\<sep>feat"  (where <sep> is the system directory separator)
    
    .NOTES
        - Uses [System.IO.Path]::Combine to join the segments.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Segments,

        [Parameter()]
        [string[]]$OverrideArray = $null
    )

    if ($Segments -eq $null -or $Segments.Count -eq 0) {
        return ""
    }

    # If an override array is provided, apply positional overrides.
    if ($OverrideArray) {
        for ($i = 0; $i -lt [Math]::Min($Segments.Count, $OverrideArray.Count); $i++) {
            # Only override if the value is not null or empty.
            if (-not [string]::IsNullOrEmpty($OverrideArray[$i])) {
                $Segments[$i] = $OverrideArray[$i]
            }
        }
    }

    # Initialize the path with the first segment.
    $path = $Segments[0]
    # Combine each subsequent segment.
    for ($i = 1; $i -lt $Segments.Count; $i++) {
        $path = [System.IO.Path]::Combine($path, $Segments[$i])
    }
    
    return $path
}

function Join-Segments {
    <#
    .SYNOPSIS
        Joins an array of segments using the current directory separator.

    .DESCRIPTION
        This function takes an array of string segments and combines them into a single path
        using the current system directory separator. It supports an optional override array
        that can replace segments positionally, and an optional append array that is simply
        concatenated to the end of the segments. The resulting array is built as follows:
          - For each position, if the override value is neither $null nor empty, it replaces the segment.
          - Otherwise, if a segment exists at that position, it is used.
          - Otherwise, an empty string is used.
          - After the above, if an append array is provided, its values are added to the end.
        The output length is determined by:
          - If no override array is provided, the output length equals the segments count.
          - If an override array is provided and its length is greater than the segments count,
            then the effective length is the override array length only if at least one override
            beyond the segments count is non-null/non-empty; otherwise, it remains the segments count.
          - Finally, any appended segments increase the output length accordingly.

    .PARAMETER Segments
        An array of strings representing the segments to join.

    .PARAMETER OverrideArray
        (Optional) A string array defining positional overrides for the segments.
        For example: @("tofooo", $null, "dev"). Defaults to $null.

    .PARAMETER AppendSegments
        (Optional) A string array containing additional segments that are appended to the end
        of the result. Defaults to $null.

    .EXAMPLE
        PS> $segments = @("testing")
        PS> $overrideArray = @($null, "hello", $null, $null, "abc")
        PS> $appendSegments = @("final", "segment")
        PS> Join-Segments -Segments $segments -OverrideArray $overrideArray -AppendSegments $appendSegments
        Returns: @("testing", "hello", "", "", "abc", "final", "segment")

    .EXAMPLE
        PS> $segments = @("testing", "foo")
        PS> $overrideArray = @($null, "hello", $null, $null, $null)
        PS> Join-Segments -Segments $segments -OverrideArray $overrideArray
        Returns: @("testing", "hello")

    .NOTES
        - Uses [System.IO.Path]::Combine to join the segments.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Segments,

        [Parameter()]
        [string[]]$OverrideArray = $null,

        [Parameter()]
        [string[]]$AppendSegments = $null
    )

    if ($Segments -eq $null -or $Segments.Count -eq 0) {
        return ""
    }

    # Determine the effective length for segments and override array.
    $effectiveLength = $Segments.Count
    if ($OverrideArray) {
        if ($OverrideArray.Count -gt $Segments.Count) {
            # Check if any element beyond the last segment index is non-null/non-empty.
            $hasExtraOverrides = $false
            for ($i = $Segments.Count; $i -lt $OverrideArray.Count; $i++) {
                if (-not [string]::IsNullOrEmpty($OverrideArray[$i])) {
                    $hasExtraOverrides = $true
                    break
                }
            }
            if ($hasExtraOverrides) {
                $effectiveLength = $OverrideArray.Count
            }
        }
    }

    # Build the result array using the effective length.
    $result = for ($i = 0; $i -lt $effectiveLength; $i++) {
        # Get the override if available, else $null.
        $override = if ($OverrideArray -and $i -lt $OverrideArray.Count) { $OverrideArray[$i] } else { $null }
        # Get the original segment if available, else empty string.
        $segment = if ($i -lt $Segments.Count) { $Segments[$i] } else { "" }
        
        # Use the override if it is neither null nor empty; otherwise, use the original segment.
        if (-not [string]::IsNullOrEmpty($override)) {
            $override
        }
        else {
            $segment
        }
    }

    # Ensure $result is an array.
    $result = @($result)

    # Append additional segments if provided by expanding each element.
    if ($AppendSegments) {
        foreach ($seg in $AppendSegments) {
            $result += $seg
        }
    }

    # Join the resulting segments using the current directory separator.
    $path = $result[0]
    for ($i = 1; $i -lt $result.Count; $i++) {
        $path = [System.IO.Path]::Combine($path, $result[$i])
    }
    
    return $path
}





