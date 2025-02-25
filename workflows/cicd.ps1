. "$PSScriptRoot\psutility\mapper.ps1"
. "$PSScriptRoot\psutility\common.ps1"
. "$PSScriptRoot\psutility\dotnetlist.ps1"
. "$PSScriptRoot\version.ps1"

$env:MSBUILDTERMINALLOGGER = "off" # Disables the terminal logger to ensure full build output is displayed in the console

Set-DotNetNugetSource -SourceName "SourcePackages"

# Use for cleaning local enviroment only, use channelRoot for deployment.
$isCiCd = $false
$isLocal = $false
if ($env:GITHUB_ACTIONS -ieq "true")
{
    $isCiCd = $true
}
else {
    $isLocal = $true
}

Write-Host "===> Before DOTNET TOOL RESTORE at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) ========================================================" -ForegroundColor Cyan
Set-Location "$PSScriptRoot\.."
$LASTEXITCODE = 0
$dotnet = "dotnet"
$dotnetCommand = @("tool","restore","--verbosity","diagnostic")
$arguments = @("--tool-manifest", [System.IO.Path]::Combine("$PSScriptRoot","dotnet-tools.json"))
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $dotnet @dotnetCommand @arguments
if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
$elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
Set-Location "$PSScriptRoot"
Write-Host "===> After DOTNET TOOL RESTORE  elapsed after: $elapsed =========================================================" -ForegroundColor Green

# Check if the secrets file exists before importing
if (Test-Path "$PSScriptRoot/cicd_secrets.ps1") {
    . "$PSScriptRoot\cicd_secrets.ps1"
    Write-Host "Secrets loaded from file."
} else {
    $NUGET_GITHUB_PUSH = $args[0]
    $NUGET_PAT = $args[1]
    $NUGET_TEST_PAT = $args[2]
    Write-Host "Secrets will be taken from args."
}

$currentBranch = Get-GitCurrentBranch

$currentBranchRoot = Get-BranchRoot -BranchName "$currentBranch"
$topLevelDirectory = Get-GitTopLevelDirectory

#Branch too channel mappings
$branchSegments = @(Split-Segments -InputString "$currentBranch" -ForbiddenSegments @("latest") -MaxSegments 2)
$nugetSuffix = @(Translate-FirstSegment -Segments $branchSegments -TranslationTable @{ "feature" = "-development"; "develop" = "-quality"; "bugfix" = "-quality"; "release" = "-staging"; "main" = ""; "master" = ""; "hotfix" = "" } -DefaultTranslation "{nodeploy}")
$nugetSuffix = $nugetSuffix[0]
$channelSegments = @(Translate-FirstSegment -Segments $branchSegments -TranslationTable @{ "feature" = "development"; "develop" = "quality"; "bugfix" = "quality"; "release" = "staging"; "main" = "production"; "master" = "production"; "hotfix" = "production" } -DefaultTranslation "{nodeploy}")

$branchFolder = Join-Segments -Segments $branchSegments
$branchVersionFolder = Join-Segments -Segments $branchSegments -AppendSegments @( $calculatedVersion.VersionFull )
$channelRoot = $channelSegments[0]
$channelVersionFolder = Join-Segments -Segments $channelSegments -AppendSegments @( $calculatedVersion.VersionFull )
$channelVersionFolderRoot = Join-Segments -Segments $channelSegments -AppendSegments @( "latest" )
if ($channelSegments.Count -eq 2)
{
    $channelVersionFolderRoot = Join-Segments -Segments $channelRoot -AppendSegments @( "latest" )
}


Write-Output "BranchFolder to $branchFolder"
Write-Output "BranchVersionFolder to $branchVersionFolder"
Write-Output "ChannelRoot to $channelRoot"
Write-Output "ChannelVersionFolder to $channelVersionFolder"
Write-Output "ChannelVersionFolderRoot to $channelVersionFolderRoot"

#Guard for variables
Ensure-Variable -Variable { $calculatedVersion } -ExitIfNullOrEmpty
Ensure-Variable -Variable { $currentBranch } -ExitIfNullOrEmpty
Ensure-Variable -Variable { $currentBranchRoot } -ExitIfNullOrEmpty
Ensure-Variable -Variable { $topLevelDirectory } -ExitIfNullOrEmpty
Ensure-Variable -Variable { $nugetSuffix }
Ensure-Variable -Variable { $NUGET_GITHUB_PUSH } -ExitIfNullOrEmpty -HideValue
Ensure-Variable -Variable { $NUGET_PAT } -ExitIfNullOrEmpty -HideValue
Ensure-Variable -Variable { $NUGET_TEST_PAT } -ExitIfNullOrEmpty -HideValue

#Required directorys
$artifactsOutputFolderName = "artifacts"
$reportsOutputFolderName = "reports"

$outputRootArtifactsDirectory = [System.IO.Path]::Combine($topLevelDirectory, $artifactsOutputFolderName)
$outputRootReportResultsDirectory   = [System.IO.Path]::Combine($topLevelDirectory, $reportsOutputFolderName)
$targetConfigAllowedLicenses = [System.IO.Path]::Combine($topLevelDirectory, ".config", "allowed-licenses.json")

Ensure-Variable -Variable { $outputRootArtifactsDirectory } -ExitIfNullOrEmpty
Ensure-Variable -Variable { $outputRootReportResultsDirectory } -ExitIfNullOrEmpty
Ensure-Variable -Variable { $targetConfigAllowedLicenses } -ExitIfNullOrEmpty

[System.IO.Directory]::CreateDirectory($outputRootArtifactsDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory($outputRootReportResultsDirectory) | Out-Null

if (-not $isCiCd) { Delete-FilesByPattern -Path "$outputRootArtifactsDirectory" -Pattern "*"  }
if (-not $isCiCd) { Delete-FilesByPattern -Path "$outputRootReportResultsDirectory" -Pattern "*"  }

# Get current Git user settings once before the loop
$gitUserLocal = git config user.name
$gitMailLocal = git config user.email

$gitTempUser = "Workflow"
$gitTempMail = "carstenriedel@outlook.com"  # Assuming a placeholder email

git config user.name $gitTempUser
git config user.email $gitTempMail

# Solutions clean restore and build ------------------------------------

$solutionFiles = Find-FilesByPattern -Path "$topLevelDirectory\source" -Pattern "*.sln"

foreach ($solutionFile in $solutionFiles) {

    $commonSolutionParameters = @(
        "--verbosity","minimal",
        "-p:""VersionBuild=$($calculatedVersion.VersionBuild)""",
        "-p:""VersionMajor=$($calculatedVersion.VersionMajor)""",
        "-p:""VersionMinor=$($calculatedVersion.VersionMinor)""",
        "-p:""VersionRevision=$($calculatedVersion.VersionRevision)"""
    )
  
    Write-Host "===> Before DOTNET CLEAN at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =======================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "clean"
    $dotnetSolution = """$($solutionFile.FullName)"""
    $dotnetStage = "-p:""Stage=$dotnetCommand"""
    $arguments = @("-c", "Release")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand $dotnetSolution @arguments $dotnetStage @commonSolutionParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET CLEAN elapsed after: $elapsed =========================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET RESTORE at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =====================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "restore"
    $dotnetSolution = """$($solutionFile.FullName)"""
    $dotnetStage = "-p:""Stage=$dotnetCommand"""
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand $dotnetSolution $dotnetStage @commonSolutionParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET RESTORE elapsed after: $elapsed =======================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET BUILD at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =======================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "build"
    $dotnetSolution = """$($solutionFile.FullName)"""
    $dotnetStage = "-p:""Stage=$dotnetCommand"""
    $arguments = @("-c", "Release")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand $dotnetSolution @arguments $dotnetStage @commonSolutionParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET BUILD elapsed after: $elapsed =========================================================" -ForegroundColor Green
}

# Projects clean restore and build ------------------------------------
Write-Host "===> Projects =========================================================" -ForegroundColor Green
Write-Host "===> Projects =========================================================" -ForegroundColor Green
Write-Host "===> Projects =========================================================" -ForegroundColor Green


$projectFiles = Find-FilesByPattern -Path "$topLevelDirectory\source" -Pattern "*.csproj"

foreach ($projectFile in $projectFiles) {

    $outputReportDirectory = New-DirectoryFromSegments -Paths @($outputRootReportResultsDirectory, "$($projectFile.BaseName)" , "$branchVersionFolder")
    $outputArtifactsDirectory = New-DirectoryFromSegments -Paths @($outputRootArtifactsDirectory, "$($projectFile.BaseName)" , "$branchVersionFolder")
    $outputArtifactPackDirectory = New-DirectoryFromSegments -Paths @($outputArtifactsDirectory , "pack")
    $outputArtifactPublishDirectory = New-DirectoryFromSegments -Paths @($outputArtifactsDirectory , "publish")

    $commonProjectParameters = @(
        "--verbosity","normal",
        "-p:""VersionBuild=$($calculatedVersion.VersionBuild)""",
        "-p:""VersionMajor=$($calculatedVersion.VersionMajor)""",
        "-p:""VersionMinor=$($calculatedVersion.VersionMinor)""",
        "-p:""VersionRevision=$($calculatedVersion.VersionRevision)""",
        "-p:""VersionSuffix=$($nugetSuffix)""",
        "-p:""BranchFolder=$branchFolder""",
        "-p:""BranchVersionFolder=$branchVersionFolder""",
        "-p:""ChannelVersionFolder=$channelVersionFolder""",
        "-p:""ChannelVersionFolderRoot=$channelVersionFolderRoot""",
        "-p:""OutputReportDirectory=$outputReportDirectory""",
        "-p:""OutputArtifactsDirectory=$outputArtifactsDirectory""",
        "-p:""OutputArtifactPackDirectory=$outputArtifactPackDirectory""",
        "-p:""OutputArtifactPublishDirectory=$outputArtifactPublishDirectory"""
    )

    Write-Host "===> Before DOTNET CLEAN at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =======================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "clean"
    $dotnetProject = """$($projectFile.FullName)"""
    $dotnetStage = "-p:""Stage=$dotnetCommand"""
    $arguments = @("-c", "Release")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand $dotnetProject @arguments $dotnetStage @commonProjectParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET CLEAN elapsed after: $elapsed =========================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET RESTORE at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =====================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "restore"
    $dotnetProject = """$($projectFile.FullName)"""
    $dotnetStage = "-p:""Stage=$dotnetCommand"""
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand $dotnetProject $dotnetStage @commonProjectParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET RESTORE elapsed after: $elapsed =======================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET BUILD at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =======================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "build"
    $dotnetProject = """$($projectFile.FullName)"""
    $dotnetStage = "-p:""Stage=$dotnetCommand"""
    $arguments = @("-c", "Release")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand $dotnetProject @arguments $dotnetStage @commonProjectParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET BUILD elapsed after: $elapsed =========================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET LIST VULNERABLE at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =============================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "list"
    $dotnetProject = "$($projectFile.FullName)"
    $arguments = @("package", "--vulnerable", "--format", "json")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $jsonOutputVulnerable = & $dotnet $dotnetCommand $dotnetProject @arguments  2>&1
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    New-DotnetVulnerabilitiesReport -jsonInput $jsonOutputVulnerable -OutputFile "$outputReportDirectory\ReportVulnerabilities.md" -OutputFormat markdown -ExitOnVulnerability $true
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET LIST VULNERABLE elapsed after: $elapsed ===============================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET LIST PACKAGE DEPRECATED at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =====================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "list"
    $dotnetProject = "$($projectFile.FullName)"
    $arguments = @("package", "--deprecated", "--include-transitive", "--format", "json")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $jsonOutputDeprecated = & $dotnet $dotnetCommand $dotnetProject @arguments
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    New-DotnetDeprecatedReport -jsonInput $jsonOutputDeprecated -OutputFile "$outputReportDirectory\ReportDeprecated.md" -OutputFormat markdown -IgnoreTransitivePackages $true -ExitOnDeprecated $true
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET LIST PACKAGE DEPRECATED elapsed after: $elapsed =======================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET LIST PACKAGE OUTDATED at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =======================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "list"
    $dotnetProject = "$($projectFile.FullName)"
    $arguments = @("package", "--outdated", "--include-transitive", "--format", "json")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $jsonOutputOutdated = & $dotnet $dotnetCommand $dotnetProject @arguments
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    New-DotnetOutdatedReport -jsonInput $jsonOutputOutdated -OutputFile "$outputReportDirectory\ReportOutdated.md" -OutputFormat markdown -IgnoreTransitivePackages $true
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET LIST PACKAGE OUTDATED elapsed after: $elapsed =========================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET LIST PACKAGE BOM at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) ============================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "list"
    $dotnetProject = "$($projectFile.FullName)"
    $arguments = @("package", "--include-transitive", "--format", "json")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $jsonOutputBom = & $dotnet $dotnetCommand $dotnetProject @arguments
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    New-DotnetBillOfMaterialsReport -jsonInput $jsonOutputBom -OutputFile "$outputReportDirectory\ReportBillOfMaterials.md" -OutputFormat markdown -IgnoreTransitivePackages $true
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()    
    Write-Host "===> After DOTNET LIST PACKAGE BOM elapsed after: $elapsed ==============================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET nuget-license at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) ===============================================" -ForegroundColor Cyan
    $targetSolutionLicensesJsonFile = [System.IO.Path]::Combine($outputReportDirectory ,"ReportLicenses.json")
    $targetSolutionThirdPartyNoticesFile = [System.IO.Path]::Combine($outputReportDirectory ,"ReportThirdPartyNotices.txt")
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "nuget-license"
    $dotnetProject = @("--input", "$($projectFile.FullName)")
    $arguments = @(
        "--allowed-license-types", "$targetConfigAllowedLicenses",
        "--output","JsonPretty"
        "--file-output","$targetSolutionLicensesJsonFile"
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand @dotnetProject @arguments
    Generate-ThirdPartyNotices -LicenseJsonPath "$targetSolutionLicensesJsonFile" -OutputPath "$targetSolutionThirdPartyNoticesFile"
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET nuget-license elapsed after: $elapsed =================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET TEST at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) ========================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "test"
    $dotnetProject = @("$($projectFile.FullName)")
    $arguments = @("-c", "Release", "-p:""Stage=test""")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand @dotnetProject @arguments @commonProjectParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET TEST elapsed after: $elapsed ==========================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET PACK at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) ========================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "pack"
    $dotnetProject = @("$($projectFile.FullName)")
    $arguments = @("-c", "Release", "-p:""Stage=pack""")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand @dotnetProject @arguments @commonProjectParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET PACK elapsed after: $elapsed ==========================================================" -ForegroundColor Green

    Write-Host "===> Before DOTNET PUBLISH at $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) (UTC) =====================================================" -ForegroundColor Cyan
    $LASTEXITCODE = 0
    $dotnet = "dotnet"
    $dotnetCommand = "publish"
    $dotnetProject = @("$($projectFile.FullName)")
    $arguments = @("-c", "Release", "-p:""Stage=publish""")
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $dotnet $dotnetCommand @dotnetProject @arguments @commonProjectParameters
    if ($LASTEXITCODE -ne 0) { Write-Error "Command failed with exit code $LASTEXITCODE. Exiting script." -ForegroundColor Red ; exit $LASTEXITCODE }
    $elapsed = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.fff") ; $stopwatch.Stop()
    Write-Host "===> After DOTNET PUBLISH elapsed after: $elapsed =======================================================" -ForegroundColor Green

    #$fileItem = Get-Item -Path $targetSolutionThirdPartyNoticesFile
    #$fileName = $fileItem.Name  # Includes extension (e.g., THIRD-PARTY-NOTICES.txt)
    #$destinationPath = Join-Path -Path $topLevelDirectory -ChildPath $fileName
    #Copy-Item -Path $fileItem.FullName -Destination $destinationPath -Force
    
    #git add $destinationPath
    #git commit -m "Updated from Workflow [no ci]"
    #git push origin $currentBranch
}

# Deploy ------------------------------------
Write-Host "===> Deploying channel: '$($channelRoot.ToLower())' | Local: $($isLocal.ToString()) | CI/CD: $($isCiCd.ToString()) =======================" -ForegroundColor Green
Write-Host "===> Deploying channel: '$($channelRoot.ToLower())' | Local: $($isLocal.ToString()) | CI/CD: $($isCiCd.ToString()) =======================" -ForegroundColor Green
Write-Host "===> Deploying channel: '$($channelRoot.ToLower())' | Local: $($isLocal.ToString()) | CI/CD: $($isCiCd.ToString()) =======================" -ForegroundColor Green

foreach ($projectFile in $projectFiles) {

    $outputReportDirectory = New-DirectoryFromSegments -Paths @($outputRootReportResultsDirectory, "$($projectFile.BaseName)" , "$branchVersionFolder")
    $outputArtifactsDirectory = New-DirectoryFromSegments -Paths @($outputRootArtifactsDirectory, "$($projectFile.BaseName)" , "$branchVersionFolder")
    $outputArtifactPackDirectory = New-DirectoryFromSegments -Paths @($outputArtifactsDirectory , "pack")
    $outputArtifactPublishDirectory = New-DirectoryFromSegments -Paths @($outputArtifactsDirectory , "publish")

    $publishCopyDir = "C:\temp"

    if ($channelRoot.ToLower() -in @("{nodeploy}"))
    {
        Write-Host "===> $channelRoot is {nodeploy} skipping ================================================================" -ForegroundColor Green
    } elseif ($channelRoot.ToLower() -in @("development")) {
        if ($isLocal)
        {
            $destinationPublishDirectory = New-DirectoryFromSegments -Paths @($publishCopyDir, "$($projectFile.BaseName)")
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolder" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolderRoot" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true

            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            dotnet nuget push "$($firstFileMatch.FullName)" --source SourcePackages
        }
        if ($isCiCd)
        {
            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            if ($firstFileMatch) {
                Write-Host "===> NuGet package found: '$($firstFileMatch.FullName)'. Proceeding with push..." -ForegroundColor Green
                dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
            }
            else {
                Write-Host "===> Warning: No NuGet package (*.nupkg) found in '$outputArtifactPackDirectory' for deployment." -ForegroundColor Yellow
            }
        }
    } elseif ($channelRoot.ToLower() -in @("quality")) {
        if ($isLocal)
        {
            $destinationPublishDirectory = New-DirectoryFromSegments -Paths @($publishCopyDir, "$($projectFile.BaseName)")
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolder" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolderRoot" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true

            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            dotnet nuget push "$($firstFileMatch.FullName)" --source SourcePackages
        }
        if ($isCiCd)
        {
            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            if ($firstFileMatch) {
                Write-Host "===> NuGet package found: '$($firstFileMatch.FullName)'. Proceeding with push..." -ForegroundColor Green
                dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_TEST_PAT --source https://apiint.nugettest.org/v3/index.json
            }
            else {
                Write-Host "===> Warning: No NuGet package (*.nupkg) found in '$outputArtifactPackDirectory' for deployment." -ForegroundColor Yellow
            }
        }
    } elseif ($channelRoot.ToLower() -in @("staging")) {
        if ($isLocal)
        {
            $destinationPublishDirectory = New-DirectoryFromSegments -Paths @($publishCopyDir, "$($projectFile.BaseName)")
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolder" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolderRoot" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true

            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            dotnet nuget push "$($firstFileMatch.FullName)" --source SourcePackages
        }
        if ($isCiCd)
        {
            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            if ($firstFileMatch) {
                Write-Host "===> NuGet package found: '$($firstFileMatch.FullName)'. Proceeding with push..." -ForegroundColor Green
                dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_TEST_PAT --source https://apiint.nugettest.org/v3/index.json
            }
            else {
                Write-Host "===> Warning: No NuGet package (*.nupkg) found in '$outputArtifactPackDirectory' for deployment." -ForegroundColor Yellow
            }
        }
    } elseif ($channelRoot.ToLower() -in @("production")) {
        if ($isLocal)
        {
            $destinationPublishDirectory = New-DirectoryFromSegments -Paths @($publishCopyDir, "$($projectFile.BaseName)")
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolder" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory\$channelVersionFolderRoot" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
            Copy-FilesRecursively -SourceDirectory "$outputArtifactPublishDirectory" -DestinationDirectory "$destinationPublishDirectory" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true

            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            dotnet nuget push "$($firstFileMatch.FullName)" --source SourcePackages
        }
        if ($isCiCd)
        {
            $firstFileMatch = Get-ChildItem -Path $outputArtifactPackDirectory -Filter "*.nupkg" -File -Recurse | Select-Object -First 1
            if ($firstFileMatch) {
                Write-Host "===> NuGet package found: '$($firstFileMatch.FullName)'. Proceeding with push..." -ForegroundColor Green
                dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
                dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_PAT --source https://api.nuget.org/v3/index.json
            }
            else {
                Write-Host "===> Warning: No NuGet package (*.nupkg) found in '$outputArtifactPackDirectory' for deployment." -ForegroundColor Yellow
            }
        }
    } else {
        <# Action when all if and elseif conditions are false #>
    }

}


exit 0

$stopwatch.Stop()

git config user.name $gitUserLocal
git config user.email $gitMailLocal

$pattern = "*$nugetSuffix.nupkg"

$firstFileMatch = Get-ChildItem -Path $outputRootPackDirectory -Filter $pattern -File -Recurse | Select-Object -First 1

if ($currentBranchRoot.ToLower() -in @("master", "main")) {
    # For branches "master" or "main", push the package to the official NuGet feed.
    # Official NuGet feed: https://api.nuget.org/v3/index.json
    dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_PAT --source https://api.nuget.org/v3/index.json
    
    dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
    dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
}
elseif ($currentBranchRoot.ToLower() -in @("release")) {
    # For the "release" branch, push the package to the test NuGet feed.
    # Test NuGet feed: https://apiint.nugettest.org/v3/index.json
    dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_TEST_PAT --source https://apiint.nugettest.org/v3/index.json
    
    dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
    dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
}
else {
    # For all other branches, add the GitHub NuGet feed and push the package there.
    dotnet nuget add source --username carsten-riedel --password $NUGET_GITHUB_PUSH --store-password-in-clear-text --name github "https://nuget.pkg.github.com/carsten-riedel/index.json"
    dotnet nuget push "$($firstFileMatch.FullName)" --api-key $NUGET_GITHUB_PUSH --source github
}

