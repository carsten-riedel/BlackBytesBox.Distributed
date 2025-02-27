
<#
.SYNOPSIS
    Recursively searches a directory for files matching a specified pattern.
.DESCRIPTION
    This function searches the specified directory and all its subdirectories for files
    that match the provided filename pattern (e.g., "*.txt", "*.sln", "*.csproj").
    It returns an array of matching FileInfo objects, which can be iterated with a ForEach loop.
.PARAMETER Path
    The root directory where the search should begin.
.PARAMETER Pattern
    The filename pattern to search for (e.g., "*.txt", "*.sln", "*.csproj").
.EXAMPLE
    $files = Find-FilesByPattern -Path "C:\MyProjects" -Pattern "*.txt"
    foreach ($file in $files) {
        Write-Output $file.FullName
    }
#>
function Find-FilesByPattern {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # Validate that the provided path exists and is a directory.
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "The specified path '$Path' does not exist or is not a directory."
    }

    try {
        # Recursively search for files matching the given pattern.
        $results = Get-ChildItem -Path $Path -Filter $Pattern -Recurse -File -ErrorAction Stop
        return $results
    }
    catch {
        Write-Error "An error occurred while searching for files: $_"
    }
}

function Delete-FilesByPattern {
    <#
    .SYNOPSIS
        Deletes files matching a specified pattern and optionally removes empty directories.

    .DESCRIPTION
        This function recursively searches for files under the given path that match the provided
        pattern and deletes them. After deleting the files, if the optional parameter 'DeleteEmptyDirs'
        is set to $true (default), it will also remove any directories that become empty as a result
        of the deletions.

    .PARAMETER Path
        The directory path in which to search for files.

    .PARAMETER Pattern
        The file search pattern (e.g., "*.log", "*.tmp").

    .PARAMETER DeleteEmptyDirs
        Optional. If set to $true (default), any directories that become empty after deletion are removed.

    .EXAMPLE
        PS> Delete-FilesByPattern -Path "C:\Temp" -Pattern "*.log"
        Deletes all .log files under C:\Temp and its subdirectories, and then removes any empty directories.

    .NOTES
        Ensure you have the necessary permissions to delete files and directories.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter()]
        [bool]$DeleteEmptyDirs = $true
    )

    # Validate that the provided path exists and is a directory.
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "The specified path '$Path' does not exist or is not a directory."
    }

    try {
        # Recursively search for files matching the given pattern.
        $files = Get-ChildItem -Path $Path -Filter $Pattern -Recurse -File -ErrorAction Stop
        foreach ($file in $files) {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            Write-Verbose "Deleted file: $($file.FullName)"
        }

        if ($DeleteEmptyDirs) {
            # Get all directories under $Path in descending order by depth.
            $dirs = Get-ChildItem -Path $Path -Directory -Recurse | Sort-Object {
                $_.FullName.Split([System.IO.Path]::DirectorySeparatorChar).Count
            } -Descending

            foreach ($dir in $dirs) {
                # Check if directory is empty.
                if (-not (Get-ChildItem -Path $dir.FullName -Force)) {
                    Remove-Item -Path $dir.FullName -Force -ErrorAction SilentlyContinue
                    Write-Verbose "Deleted empty directory: $($dir.FullName)"
                }
            }
        }
    }
    catch {
        Write-Error "An error occurred while deleting files or directories: $_"
    }
}

function Ensure-Variable {
    <#
    .SYNOPSIS
    Ensures a variable meets conditions and displays its details.

    .DESCRIPTION
    Accepts a script block containing a simple variable reference (e.g. { $currentBranch }),
    extracts the variable's name from the AST, evaluates its value, and displays both in one line.
    The -HideValue switch suppresses the actual value by displaying "[Hidden]". When -ExitIfNullOrEmpty
    is specified, the function exits with code 1 if the variable's value is null, an empty string,
    or (in the case of a hashtable) empty.

    .PARAMETER Variable
    A script block that must contain a simple variable reference.

    .PARAMETER HideValue
    If specified, the displayed value will be replaced with "[Hidden]".

    .PARAMETER ExitIfNullOrEmpty
    If specified, the function exits with code 1 when the variable's value is null or empty.

    .EXAMPLE
    $currentBranch = "develop"
    Ensure-Variable -Variable { $currentBranch }
    # Output: Variable Name: currentBranch, Value: develop

    .EXAMPLE
    $currentBranch = ""
    Ensure-Variable -Variable { $currentBranch } -ExitIfNullOrEmpty
    # Outputs an error and exits with code 1.

    .EXAMPLE
    $myHash = @{ Key1 = "Value1"; Key2 = "Value2" }
    Ensure-Variable -Variable { $myHash }
    # Output: Variable Name: myHash, Value: {"Key1":"Value1","Key2":"Value2"}

    .NOTES
    The script block must contain a simple variable reference for the AST extraction to work correctly.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$Variable,
        
        [switch]$HideValue,
        
        [switch]$ExitIfNullOrEmpty
    )

    # Extract variable name from the script block's AST.
    $ast = $Variable.Ast
    $varAst = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)
    if (-not $varAst) {
        Write-Error "The script block must contain a simple variable reference."
        return
    }
    $varName = $varAst.VariablePath.UserPath

    # Evaluate the script block to get the variable's value.
    $value = & $Variable

    # Check if the value is null or empty and exit if required.
    if ($ExitIfNullOrEmpty) {
        if ($null -eq $value) {
            Write-Error "Variable '$varName' is null."
            exit 1
        }
        if (($value -is [string]) -and [string]::IsNullOrEmpty($value)) {
            Write-Error "Variable '$varName' is an empty string."
            exit 1
        }
        if ($value -is [hashtable] -and ($value.Count -eq 0)) {
            Write-Error "Variable '$varName' is an empty hashtable."
            exit 1
        }
    }

    # Prepare the display value.
    if ($HideValue) {
        $displayValue = "[Hidden]"
    }
    else {
        if ($value -is [hashtable]) {
            # Convert the hashtable to a compact JSON string for one-line output.
            $displayValue = $value | ConvertTo-Json -Compress
        }
        else {
            $displayValue = $value
        }
    }

    Write-Output "Variable Name: $varName, Value: $displayValue"
}

function New-DirectoryFromSegments {
    <#
    .SYNOPSIS
        Combines path segments into a full directory path and creates the directory.
    
    .DESCRIPTION
        This function takes an array of strings representing parts of a file system path,
        combines them using [System.IO.Path]::Combine, validates the resulting path, creates
        the directory if it does not exist, and returns the full directory path.
    
    .PARAMETER Paths
        An array of strings that represents the individual segments of the directory path.
    
    .EXAMPLE
        $outputReportDirectory = New-DirectoryFromSegments -Paths @($outputRootReportResultsDirectory, "$($projectFile.BaseName)", "$branchVersionFolder")
        # This combines the three parts, creates the directory if needed, and returns the full path.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )
    
    # Combine the provided path segments into a single path.
    $combinedPath = [System.IO.Path]::Combine($Paths)
    
    # Validate that the combined path is not null or empty.
    if ([string]::IsNullOrEmpty($combinedPath)) {
        Write-Error "The combined path is null or empty."
        exit 1
    }
    
    # Create the directory if it does not exist.
    [System.IO.Directory]::CreateDirectory($combinedPath) | Out-Null
    
    # Return the combined directory path.
    return $combinedPath
}

function Copy-FilesRecursively {
    <#
    .SYNOPSIS
        Recursively copies files from a source directory to a destination directory.

    .DESCRIPTION
        This function copies files from the specified source directory to the destination directory.
        The file filter (default "*") limits the files that are copied. The –CopyEmptyDirs parameter
        controls directory creation:
         - If $true (default), the complete source directory tree is recreated.
         - If $false, only directories that contain at least one file matching the filter (in that
           directory or any subdirectory) will be created.
        The –ForceOverwrite parameter (default $true) determines whether existing files are overwritten.
        The –CleanDestination parameter (default $false) controls whether additional files in the root of the
        DestinationDirectory (files that do not exist in the source directory) should be removed.
        **Note:** This cleaning only applies to files in the destination root and does not affect files
        in subdirectories.

    .PARAMETER SourceDirectory
        The directory from which files and directories are copied.

    .PARAMETER DestinationDirectory
        The target directory to which files and directories will be copied.

    .PARAMETER Filter
        A wildcard filter that limits which files are copied. Defaults to "*".

    .PARAMETER CopyEmptyDirs
        If $true, the entire directory structure from the source is recreated in the destination.
        If $false, only directories that will contain at least one file matching the filter are created.
        Defaults to $true.

    .PARAMETER ForceOverwrite
        A Boolean value that indicates whether existing files should be overwritten.
        Defaults to $true.

    .PARAMETER CleanDestination
        If $true, any extra files found in the destination directory’s root (that are not present in the
        source directory, matching the filter) are removed. Files in subdirectories are not affected.
        Defaults to $false.

    .EXAMPLE
        # Copy all *.txt files, create only directories that hold matching files, and clean extra files in the destination root.
        Copy-FilesRecursively2 -SourceDirectory "C:\Source" `
                               -DestinationDirectory "C:\Dest" `
                               -Filter "*.txt" `
                               -CopyEmptyDirs $false `
                               -ForceOverwrite $true `
                               -CleanDestination $true

    .EXAMPLE
        # Copy all files, recreate the full directory tree without cleaning extra files.
        Copy-FilesRecursively2 -SourceDirectory "C:\Source" `
                               -DestinationDirectory "C:\Dest"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,

        [Parameter()]
        [string]$Filter = "*",

        [Parameter()]
        [bool]$CopyEmptyDirs = $true,

        [Parameter()]
        [bool]$ForceOverwrite = $true,

        [Parameter()]
        [bool]$CleanDestination = $false
    )

    # Validate that the source directory exists.
    if (-not (Test-Path -Path $SourceDirectory -PathType Container)) {
        Write-Error "Source directory '$SourceDirectory' does not exist."
        return
    }

    # If CopyEmptyDirs is false, check if there are any files matching the filter.
    if (-not $CopyEmptyDirs) {
        $matchingFiles = Get-ChildItem -Path $SourceDirectory -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue
        if (-not $matchingFiles -or $matchingFiles.Count -eq 0) {
            Write-Verbose "No files matching filter found in source. Skipping directory creation as CopyEmptyDirs is false."
            return
        }
    }

    # Create the destination directory if it doesn't exist.
    if (-not (Test-Path -Path $DestinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
    }

    # If CleanDestination is enabled, remove files in the destination root that aren't in the source root.
    if ($CleanDestination) {
        Write-Verbose "Cleaning destination root: removing extra files not present in source."
        $destRootFiles = Get-ChildItem -Path $DestinationDirectory -File -Filter $Filter
        foreach ($destFile in $destRootFiles) {
            $sourceFilePath = Join-Path -Path $SourceDirectory -ChildPath $destFile.Name
            if (-not (Test-Path -Path $sourceFilePath -PathType Leaf)) {
                Write-Verbose "Removing file: $($destFile.FullName)"
                Remove-Item -Path $destFile.FullName -Force
            }
        }
    }

    # Set full paths for easier manipulation.
    $sourceFullPath = (Get-Item $SourceDirectory).FullName.TrimEnd('\')
    $destFullPath   = (Get-Item $DestinationDirectory).FullName.TrimEnd('\')

    if ($CopyEmptyDirs) {
        Write-Verbose "Recreating complete directory structure from source."
        # Recreate every directory under the source.
        Get-ChildItem -Path $sourceFullPath -Recurse -Directory | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceFullPath.Length)
            $newDestDir   = Join-Path -Path $destFullPath -ChildPath $relativePath
            if (-not (Test-Path -Path $newDestDir)) {
                New-Item -ItemType Directory -Path $newDestDir | Out-Null
            }
        }
    }
    else {
        Write-Verbose "Creating directories only for files matching the filter."
        # Using previously obtained $matchingFiles.
        foreach ($file in $matchingFiles) {
            $sourceDir   = Split-Path -Path $file.FullName -Parent
            $relativeDir = $sourceDir.Substring($sourceFullPath.Length)
            $newDestDir  = Join-Path -Path $destFullPath -ChildPath $relativeDir
            if (-not (Test-Path -Path $newDestDir)) {
                New-Item -ItemType Directory -Path $newDestDir | Out-Null
            }
        }
    }

    # Copy files matching the filter, preserving relative paths.
    Write-Verbose "Copying files from source to destination."
    if ($CopyEmptyDirs) {
        $filesToCopy = Get-ChildItem -Path $SourceDirectory -Recurse -File -Filter $Filter
    }
    else {
        $filesToCopy = $matchingFiles
    }
    foreach ($file in $filesToCopy) {
        $relativePath = $file.FullName.Substring($sourceFullPath.Length)
        $destFile     = Join-Path -Path $destFullPath -ChildPath $relativePath

        # Skip copying if overwrite is disabled and the file already exists.
        if (-not $ForceOverwrite -and (Test-Path -Path $destFile)) {
            Write-Verbose "Skipping existing file (overwrite disabled): $destFile"
            continue
        }

        # Ensure the destination directory exists.
        $destDir = Split-Path -Path $destFile -Parent
        if (-not (Test-Path -Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir | Out-Null
        }

        Write-Verbose "Copying file: $($file.FullName) to $destFile"
        if ($ForceOverwrite) {
            Copy-Item -Path $file.FullName -Destination $destFile -Force
        }
        else {
            Copy-Item -Path $file.FullName -Destination $destFile
        }
    }
}

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

