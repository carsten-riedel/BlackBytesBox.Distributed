<#
.SYNOPSIS
    Converts a DateTime instance into NuGet and assembly version components with a granularity of 64 seconds.

.DESCRIPTION
    This function calculates the total seconds elapsed from January 1st of the input DateTime's year and discards the lower 6 bits (each unit representing 64 seconds). The resulting value is split into:
      - LowPart: The lower 16 bits, simulating a ushort value.
      - HighPart: The remaining upper bits combined with a year-based offset (year multiplied by 10).
    The output is provided as a version string along with individual version components. This conversion is designed to generate version segments suitable for both NuGet package versions and assembly version numbers. The function accepts additional version parameters and supports years up to 6553.

.PARAMETER VersionBuild
    An integer representing the build version component.

.PARAMETER VersionMajor
    An integer representing the major version component.

.PARAMETER InputDate
    An optional DateTime value. If not provided, the current date/time is used.
    The year of the InputDate must not exceed 6553.

.EXAMPLE
    PS C:\> $result = DateTimeVersionConverter64Seconds -VersionBuild 1 -VersionMajor 0 -InputDate (Get-Date "2025-05-01")
    PS C:\> $result
    Name              Value
    ----              -----
    VersionFull       1.0.20250.1234
    VersionBuild      1
    VersionMajor      0
    VersionMinor      20250
    VersionRevision   1234
#>
function DateTimeVersionConverter64Seconds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,

        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,

        [Parameter(Mandatory = $false)]
        [datetime]$InputDate = (Get-Date)
    )

    # The number of bits to discard, where each unit equals 64 seconds.
    $shiftAmount = 6

    $dateTime = $InputDate

    if ($dateTime.Year -gt 6553) {
        throw "Year must not be greater than 6553."
    }

    # Determine the start of the current year
    $startOfYear = [datetime]::new($dateTime.Year, 1, 1, 0, 0, 0, $dateTime.Kind)
    
    # Calculate total seconds elapsed since the start of the year
    $elapsedSeconds = [int](([timespan]($dateTime - $startOfYear)).TotalSeconds)
    
    # Discard the lower bits by applying a bitwise shift
    $shiftedSeconds = $elapsedSeconds -shr $shiftAmount
    
    # LowPart: extract the lower 16 bits (simulate ushort using bitwise AND with 0xFFFF)
    $lowPart = $shiftedSeconds -band 0xFFFF
    
    # HighPart: remaining bits after a right-shift of 16 bits
    $highPart = $shiftedSeconds -shr 16
    
    # Combine the high part with a year offset (year multiplied by 10)
    $combinedHigh = $highPart + ($dateTime.Year * 10)
    
    # Return a hashtable with the version string and components (output names must remain unchanged)
    return @{
        VersionFull    = "$($VersionBuild.ToString()).$($VersionMajor.ToString()).$($combinedHigh.ToString()).$($lowPart.ToString())"
        VersionBuild   = $VersionBuild.ToString();
        VersionMajor   = $VersionMajor.ToString();
        VersionMinor   = $combinedHigh.ToString();
        VersionRevision = $lowPart.ToString()
    }
}



<#
.SYNOPSIS
    Recursively searches a directory for files matching a specified filename pattern.
.DESCRIPTION
    This function searches the specified directory and all its subdirectories for files that match
    the given filename pattern (e.g., *.sln or *.csproj). It returns an array of matching FileInfo objects,
    which can be iterated with a ForEach loop.
.PARAMETER Path
    The root directory where the search should begin.
.PARAMETER Pattern
    The filename pattern to search for (e.g., "*.sln" or "*.csproj").
.EXAMPLE
    $files = Find-ProjectFiles -Path "C:\MyProjects" -Pattern "*.csproj"
    foreach ($file in $files) {
        Write-Output $file.FullName
    }
#>
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


function Get-GitCurrentBranch {
    <#
    .SYNOPSIS
    Retrieves the current Git branch name.

    .DESCRIPTION
    This function calls Git to determine the current branch. It first uses
    'git rev-parse --abbrev-ref HEAD' to get the branch name. If the output is
    "HEAD" (indicating a detached HEAD state), it then attempts to find a branch
    that contains the current commit using 'git branch --contains HEAD'. If no
    branch is found, it falls back to returning the commit hash.

    .EXAMPLE
    PS C:\> Get-GitCurrentBranch

    Returns:
    master

    .NOTES
    - Ensure Git is available in your system's PATH.
    - In cases of a detached HEAD with multiple containing branches, the first
      branch found is returned.
    #>

    try {
        # Get the abbreviated branch name
        $branch = git rev-parse --abbrev-ref HEAD 2>$null

        # If HEAD is returned, we're in a detached state.
        if ($branch -eq 'HEAD') {
            # Try to get branch names that contain the current commit.
            $branches = git branch --contains HEAD 2>$null | ForEach-Object {
                # Remove any asterisks or leading/trailing whitespace.
                $_.Replace('*','').Trim()
            } | Where-Object { $_ -ne '' }

            if ($branches.Count -gt 0) {
                # Return the first branch found
                return $branches[0]
            }
            else {
                # As a fallback, return the commit hash.
                return git rev-parse HEAD 2>$null
            }
        }
        else {
            return $branch.Trim()
        }
    }
    catch {
        Write-Error "Error retrieving Git branch: $_"
    }
}

function Get-GitTopLevelDirectory {
    <#
    .SYNOPSIS
        Retrieves the top-level directory of the current Git repository.

    .DESCRIPTION
        This function calls Git using 'git rev-parse --show-toplevel' to determine
        the root directory of the current Git repository. If Git is not available
        or the current directory is not within a Git repository, the function returns
        an error. The function converts any forward slashes to the system's directory
        separator (works correctly on both Windows and Linux).

    .EXAMPLE
        PS C:\Projects\MyRepo> Get-GitTopLevelDirectory
        C:\Projects\MyRepo

    .NOTES
        Ensure Git is installed and available in your system's PATH.
    #>

    try {
        # Attempt to retrieve the top-level directory of the Git repository.
        $topLevel = git rev-parse --show-toplevel 2>$null

        if (-not $topLevel) {
            Write-Error "Not a Git repository or Git is not available in the PATH."
            return $null
        }

        # Trim the result and replace forward slashes with the current directory separator.
        $topLevel = $topLevel.Trim().Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        return $topLevel
    }
    catch {
        Write-Error "Error retrieving Git top-level directory: $_"
    }
}


function Get-BranchRoot {
    <#
    .SYNOPSIS
    Extracts the root segment from a Git branch name.

    .DESCRIPTION
    This function splits the provided branch name by the '/' delimiter and returns the first segment.
    For branch names without a '/', it returns the original branch name.

    .PARAMETER BranchName
    The full branch name (e.g., "feature/integreateupdates/fsdd" or "master").

    .EXAMPLE
    PS C:\> Get-BranchRoot -BranchName "feature/integreateupdates/fsdd"
    Returns: feature

    .EXAMPLE
    PS C:\> Get-BranchRoot -BranchName "master"
    Returns: master

    .NOTES
    Ensure that the branch name is correctly passed as a string.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    if (-not $BranchName) {
        Write-Error "BranchName cannot be empty."
        return $null
    }

    # Split the branch name by '/' and return the first part.
    $parts = $BranchName.Split('/')
    return $parts[0]
}

function Get-NuGetSuffix {
    <#
    .SYNOPSIS
    Maps a Git branch root to a NuGet package suffix.

    .DESCRIPTION
    This function maps the provided Git branch root (e.g., "feature", "develop") to a NuGet package suffix.
    For branch roots named 'main' or 'master', it returns an empty string. For all other branch roots,
    it returns the suffix by prefixing the branch root with a hyphen.

    .PARAMETER BranchRoot
    The root of the Git branch (e.g., "feature", "develop", "master").

    .EXAMPLE
    PS C:\> Get-NuGetSuffix -BranchRoot "feature"
    Returns: -feature

    .EXAMPLE
    PS C:\> Get-NuGetSuffix -BranchRoot "master"
    Returns: 

    .NOTES
    This mapping assumes that the 'main' and 'master' branches do not require a suffix,
    while all other branch roots are suffixed.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$BranchRoot
    )

    if ([string]::IsNullOrWhiteSpace($BranchRoot)) {
        Write-Error "BranchRoot cannot be empty."
        return $null
    }

    switch ($BranchRoot.ToLower()) {
        'main' { return "" }
        'master' { return "" }
        default { return "-$BranchRoot" }
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

<#
.SYNOPSIS
    Sanitizes a branch name for use as a directory name.

.DESCRIPTION
    This function takes a branch name string, replaces invalid filename characters 
    (as determined by System.IO.Path.GetInvalidFileNameChars) with underscores, 
    and converts forward slashes (/) into the current directory separator 
    (obtained via System.IO.Path.DirectorySeparatorChar).

.PARAMETER BranchName
    The branch name string to sanitize.

.EXAMPLE
    PS> $sanitizedBranch = Sanitize-BranchName -BranchName "feature/some/branch"
    PS> Write-Host $sanitizedBranch
#>
function Sanitize-BranchName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    # Get the invalid file name characters
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()

    # Start with the original branch name
    $sanitized = $BranchName

    # Replace each invalid character with an underscore
    foreach ($char in $invalidChars) {
        $pattern = [Regex]::Escape($char)
        $sanitized = $sanitized -replace $pattern, "_"
    }

    # Replace forward slashes with the current directory separator
    $dirSep = [System.IO.Path]::DirectorySeparatorChar
    $sanitized = $sanitized -replace '/', $dirSep

    return $sanitized
}

function Generate-ThirdPartyNotices {
    <#
    .SYNOPSIS
    Generates a visually formatted THIRD-PARTY-NOTICES.txt file from a NuGet license JSON.

    .DESCRIPTION
    Reads the `licenses.json` generated by `dotnet nuget-license` and extracts
    package name, version, license type, URL, and authors. It formats them
    into a structured THIRD-PARTY-NOTICES.txt file.

    If any package contains `ValidationErrors`, the script will throw an error and exit.

    .PARAMETER LicenseJsonPath
    Path to the JSON file containing NuGet license information.

    .PARAMETER OutputPath
    Path where the THIRD-PARTY-NOTICES.txt file should be created.

    .EXAMPLE
    Generate-ThirdPartyNotices -LicenseJsonPath "licenses.json" -OutputPath "THIRD-PARTY-NOTICES.txt"

    Generates a THIRD-PARTY-NOTICES.txt file based on `licenses.json`.
    #>
    param(
        [string]$LicenseJsonPath = "licenses.json",
        [string]$OutputPath = "THIRD-PARTY-NOTICES.txt"
    )

    if (!(Test-Path $LicenseJsonPath)) {
        Write-Host "Error: License JSON file not found at $LicenseJsonPath" -ForegroundColor Red
        exit 1
    }

    # Read and parse JSON
    $licenses = Get-Content $LicenseJsonPath | ConvertFrom-Json

    # Check for validation errors
    $hasErrors = $false
    foreach ($package in $licenses) {
        if ($package.ValidationErrors.Count -gt 0) {
            $hasErrors = $true
            Write-Host "License validation error in package: $($package.PackageId) - $($package.PackageVersion)" -ForegroundColor Red
            foreach ($error in $package.ValidationErrors) {
                Write-Host "   $error" -ForegroundColor Yellow
            }
        }
    }

    if ($hasErrors) {
        Write-Host "Exiting due to license validation errors." -ForegroundColor Red
        exit 1
    }

    # Prepare the notice text
    $notices = @()
    $notices += "============================================"
    $notices += "          THIRD-PARTY LICENSE NOTICES       "
    $notices += "============================================"
    $notices += "`nThis project includes third-party libraries under open-source licenses.`n"

    foreach ($package in $licenses) {
        $name = $package.PackageId
        $version = $package.PackageVersion
        $license = $package.License
        $url = $package.LicenseUrl
        $authors = $package.Authors
        $packageProjectUrl = $package.PackageProjectUrl

        $notices += "--------------------------------------------"
        $notices += "📦 Package: $name (v$version)"
        $notices += "🔖 License: $license"
        if ($url) { $notices += "🌍 License URL: $url" }
        if ($authors) { $notices += "👤 Authors: $authors" }
        if ($packageProjectUrl) { $notices += "🔗 Project: $packageProjectUrl" }
        $notices += "--------------------------------------------`n"
    }

    # Write to file
    $notices | Out-File -Encoding utf8 $OutputPath

    Write-Host "THIRD-PARTY-NOTICES.txt generated at: $OutputPath" -ForegroundColor Green
}


function Test-DotnetVulnerabilities {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the .NET solution file (.sln).")]
        [string]$SolutionPath,

        [Parameter(Mandatory = $false, HelpMessage = "Minimum vulnerability severity that triggers an exit. Valid values: Low, Medium, High, Critical. Default is High.")]
        [ValidateSet("Low", "Medium", "High", "Critical")]
        [string]$ExitOn = "High"
    )

    <#
    .SYNOPSIS
      Checks a .NET solution for package vulnerabilities using the dotnet CLI.
    
    .DESCRIPTION
      This function runs the 'dotnet list' command with the '--vulnerable' flag and a JSON output format.
      It then parses the JSON, inspects each project's frameworks and top-level packages for any vulnerabilities,
      and compares the vulnerability severity against a threshold (provided via the ExitOn parameter).
      If any vulnerability is at or above the threshold, the function writes the details and exits with error code 1.
    
    .PARAMETER SolutionPath
      The path to the .NET solution file to check.
    
    .PARAMETER ExitOn
      The minimum severity level that will trigger an exit. 
      Valid values are: Low, Medium, High, Critical. Defaults to "High".
    
    .EXAMPLE
      Test-DotnetVulnerabilities -SolutionPath "C:\Projects\MySolution.sln" -ExitOn "High"
    #>

    Write-Host "Checking vulnerabilities in solution: $SolutionPath" -ForegroundColor Cyan

    # Execute the dotnet command and capture the JSON output.
    $jsonOutput = dotnet list $SolutionPath package --vulnerable --format json 2>&1
    if (-not $jsonOutput) {
        Write-Error "No output received from dotnet list. Verify the solution path is correct."
        exit 1
    }

    try {
        $result = $jsonOutput | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse JSON output from dotnet list command."
        exit 1
    }

    # Define severity ranking.
    $severityRank = @{
        "Low"      = 1;
        "Medium"   = 2;
        "High"     = 3;
        "Critical" = 4;
    }
    $thresholdRank = $severityRank[$ExitOn]

    $vulnerabilitiesFound = @()

    # Loop through projects and their frameworks to gather vulnerabilities.
    foreach ($project in $result.projects) {
        if ($project.frameworks) {
            foreach ($framework in $project.frameworks) {
                if ($framework.topLevelPackages) {
                    foreach ($package in $framework.topLevelPackages) {
                        if ($package.vulnerabilities) {
                            foreach ($vuln in $package.vulnerabilities) {
                                $vulnerabilitiesFound += [PSCustomObject]@{
                                    Project         = $project.path
                                    Framework       = $framework.framework
                                    Package         = $package.id
                                    RequestedVersion= $package.requestedVersion
                                    ResolvedVersion = $package.resolvedVersion
                                    Severity        = $vuln.severity
                                    AdvisoryUrl     = $vuln.advisoryurl
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if ($vulnerabilitiesFound.Count -gt 0) {
        $triggerExit = $false
        foreach ($vuln in $vulnerabilitiesFound) {
            if ($severityRank[$vuln.Severity] -ge $thresholdRank) {
                $triggerExit = $true
                break
            }
        }

        if ($triggerExit) {
            Write-Host "Vulnerabilities meeting or exceeding the severity threshold '$ExitOn' were found:" -ForegroundColor Red
            $vulnerabilitiesFound | Format-Table -AutoSize
            exit 1
        }
        else {
            Write-Host "Vulnerabilities were found, but none meet the threshold '$ExitOn'." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No vulnerabilities found." -ForegroundColor Green
    }
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

function Set-DotNetNugetSource {
    <#
    .SYNOPSIS
        Configures a dotnet NuGet source.

    .DESCRIPTION
        This function sets up a NuGet source for dotnet by performing the following steps:
         - Lists the current NuGet sources.
         - Removes any existing source with the specified source name.
         - Creates the destination directory (defaulting to "$HOME/source/packages") if it doesn't exist.
         - Adds the new NuGet source using the platform-independent destination path.
         - Enables the new NuGet source.

    .PARAMETER SourceName
        The name of the NuGet source to configure.

    .PARAMETER DestinationDirectory
        The directory path for the NuGet source. If not specified, defaults to "$HOME/source/packages".
        The path is normalized to use the platform-specific directory separator.

    .EXAMPLE
        Set-DotNetNugetSource -SourceName "SourcePackages"
        # This creates (if necessary) a directory "$HOME/source/packages", removes any existing source named "SourcePackages",
        # adds it as a NuGet source, and then enables it.

    .EXAMPLE
        Set-DotNetNugetSource -SourceName "CustomSource" -DestinationDirectory "/custom/nuget/packages"
        # This will normalize the destination path based on the OS and perform the same operations.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceName,

        [Parameter(Mandatory = $false)]
        [string]$DestinationDirectory
    )

    # Default the destination directory if not provided.
    if (-not $DestinationDirectory) {
        $DestinationDirectory = Join-Path -Path $HOME -ChildPath "source/packages"
    }

    # Normalize the directory separators to the platform default.
    $dirSep = [System.IO.Path]::DirectorySeparatorChar
    $DestinationDirectory = $DestinationDirectory -replace '[\\/]', $dirSep

    # Create the destination directory if it does not exist.
    if (-not (Test-Path -Path $DestinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
        Write-Verbose "Created directory: $DestinationDirectory"
    }

    # List current dotnet nuget sources.
    #dotnet nuget list source

    # Remove any existing source with the provided name.
    dotnet nuget remove source $SourceName

    # Add the new NuGet source using the destination directory.
    dotnet nuget add source "$DestinationDirectory" -n $SourceName

    # Enable the newly added source.
    dotnet nuget enable source $SourceName
}



