param (
    [string]$NUGET_GITHUB_PUSH,
    [string]$NUGET_PAT,
    [string]$NUGET_TEST_PAT,
    [string]$POWERSHELL_GALLERY
)

# If any of the parameters are empty, try loading them from a secrets file.
if ([string]::IsNullOrEmpty($NUGET_GITHUB_PUSH) -or [string]::IsNullOrEmpty($NUGET_PAT) -or [string]::IsNullOrEmpty($NUGET_TEST_PAT) -or [string]::IsNullOrEmpty($POWERSHELL_GALLERY)) {
    if (Test-Path "$PSScriptRoot\cicd_secrets.ps1") {
        . "$PSScriptRoot\cicd_secrets.ps1"
        Write-Host "Secrets loaded from file."
    }
    if ([string]::IsNullOrEmpty($NUGET_GITHUB_PUSH))
    {
        exit 1
    }
}

Install-Module -Name BlackBytesBox.Manifested.Initialize -Repository "PSGallery" -Force -AllowClobber
Install-Module -Name BlackBytesBox.Manifested.Version -Repository "PSGallery" -Force -AllowClobber
Install-Module -Name BlackBytesBox.Manifested.Git -Repository "PSGallery" -Force -AllowClobber

. "$PSScriptRoot\psutility\common.ps1"
. "$PSScriptRoot\psutility\dotnetlist.ps1"

$env:MSBUILDTERMINALLOGGER = "off" # Disables the terminal logger to ensure full build output is displayed in the console

Initialize-NugetRepositoryDotNet -Name "LocalNuget" -Location "$HOME\source\localNuget"

$calculatedVersion = Convert-DateTimeTo64SecVersionComponents -VersionBuild 0 -VersionMajor 1

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

Set-Location "$PSScriptRoot\.."
Invoke-Exec -Executable "dotnet" -Arguments @("tool", "restore", "--verbosity", "diagnostic","--tool-manifest",[System.IO.Path]::Combine("$PSScriptRoot","dotnet-tools.json"))
Set-Location "$PSScriptRoot"


$currentBranch = Get-GitCurrentBranch
$currentBranchRoot = Get-GitCurrentBranchRoot
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

$outputRootArtifactsDirectory = New-DirectoryFromSegments -Paths @($topLevelDirectory, $artifactsOutputFolderName)
$outputRootReportResultsDirectory = New-DirectoryFromSegments -Paths @($topLevelDirectory, $reportsOutputFolderName)
$targetConfigAllowedLicenses = Join-Segments -Segments @($topLevelDirectory, ".config", "allowed-licenses.json")
$targetConfigLicensesMappings = Join-Segments -Segments @($topLevelDirectory, ".config", "licenses-mapping.json")


if (-not $isCiCd) { Delete-FilesByPattern -Path "$outputRootArtifactsDirectory" -Pattern "*"  }
if (-not $isCiCd) { Delete-FilesByPattern -Path "$outputRootReportResultsDirectory" -Pattern "*"  }

# Get current Git user settings once before the loop
$gitUserLocal = git config user.name
$gitMailLocal = git config user.email

$gitTempUser = "Workflow"
$gitTempMail = "carstenriedel@outlook.com"  # Assuming a placeholder email

git config user.name $gitTempUser
git config user.email $gitTempMail

# Initialize the array to accumulate projects.
$solutionFiles = Find-FilesByPattern -Path "$topLevelDirectory\source" -Pattern "*.sln"
$solutionProjects = @()
foreach ($solutionFile in $solutionFiles) {
    $currentProjects = Invoke-Exec -Executable "dotnet" -Arguments @("bbdist", "sln", "--file", "$($solutionFile.FullName)")
    $solutionProjects += $currentProjects
}
$solutionProjectsObj = $solutionProjects | ForEach-Object { Get-Item $_ }


foreach ($projectFile in $solutionProjectsObj) {

    $isTestProject = Invoke-Exec -Executable "dotnet" -Arguments @("bbdist", "csproj", "--file", "$($projectFile.FullName)", "--property", "IsTestProject")
    $isPackable = Invoke-Exec -Executable "dotnet" -Arguments @("bbdist", "csproj", "--file", "$($projectFile.FullName)", "--property", "IsPackable")
    $isPublishable = Invoke-Exec -Executable "dotnet" -Arguments @("bbdist", "csproj", "--file", "$($projectFile.FullName)", "--property", "IsPublishable")

    $outputReportDirectory = New-DirectoryFromSegments -Paths @($outputRootReportResultsDirectory, "$($projectFile.BaseName)" , "$branchVersionFolder")
    $outputArtifactsDirectory = New-DirectoryFromSegments -Paths @($outputRootArtifactsDirectory, "$($projectFile.BaseName)" , "$branchVersionFolder")
    $outputArtifactPackDirectory = New-DirectoryFromSegments -Paths @($outputArtifactsDirectory , "pack")
    $outputArtifactPublishDirectory = New-DirectoryFromSegments -Paths @($outputArtifactsDirectory , "publish")
    

    $commonProjectParameters = @(
        "--verbosity","minimal",
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

    Invoke-Exec -Executable "dotnet" -Arguments @("clean", """$($projectFile.FullName)""", "-c", "Release","-p:""Stage=clean""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    Invoke-Exec -Executable "dotnet" -Arguments @("restore", """$($projectFile.FullName)""", "-p:""Stage=restore""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    Invoke-Exec -Executable "dotnet" -Arguments @("build", """$($projectFile.FullName)""", "-c", "Release","-p:""Stage=build""")  -CommonArguments $commonProjectParameters -CaptureOutput $false

    if (($isPackable -eq $true) -or ($isPublishable -eq $true))
    {
        $jsonOutputVulnerable = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--vulnerable", "--format", "json")
        New-DotnetVulnerabilitiesReport -jsonInput $jsonOutputVulnerable -OutputFile "$outputReportDirectory\ReportVulnerabilities.md" -OutputFormat markdown -ExitOnVulnerability $true
    
        $jsonOutputDeprecated = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--deprecated", "--include-transitive", "--format", "json")
        New-DotnetDeprecatedReport -jsonInput $jsonOutputDeprecated -OutputFile "$outputReportDirectory\ReportDeprecated.md" -OutputFormat markdown -IgnoreTransitivePackages $true -ExitOnDeprecated $true
    
        $jsonOutputOutdated = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--outdated", "--include-transitive", "--format", "json")
        New-DotnetOutdatedReport -jsonInput $jsonOutputOutdated -OutputFile "$outputReportDirectory\ReportOutdated.md" -OutputFormat markdown -IgnoreTransitivePackages $true
    
        $jsonOutputBom = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--include-transitive", "--format", "json")
        New-DotnetBillOfMaterialsReport -jsonInput $jsonOutputBom -OutputFile "$outputReportDirectory\ReportBillOfMaterials.md" -OutputFormat markdown -IgnoreTransitivePackages $true
    
        Invoke-Exec -Executable "dotnet" -Arguments @("nuget-license", "--input", "$($projectFile.FullName)", "--allowed-license-types", "$targetConfigAllowedLicenses", "--output", "JsonPretty", "--licenseurl-to-license-mappings" ,"$targetConfigLicensesMappings", "--file-output", "$outputReportDirectory/ReportProjectLicences.json" )
        Generate-ThirdPartyNotices -LicenseJsonPath "$outputReportDirectory/ReportProjectLicences.json" -OutputPath "$outputReportDirectory\ReportThirdPartyNotices.txt"
    }

    if ($isTestProject -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("test", "$($projectFile.FullName)", "-c", "Release","-p:""Stage=test""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    }

    if ($isPackable -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("pack", "$($projectFile.FullName)", "-c", "Release","-p:""Stage=pack""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    }

    if ($isPublishable -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("publish", "$($projectFile.FullName)", "-c", "Release","-p:""Stage=publish""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    }

    if ($isPackable -eq $true)
    {
        $replacements = @{
            "sourceCodeDirectory" = "$($projectFile.DirectoryName)"
            "outputDirectory"     = "$outputReportDirectory\docfx"
            "projfilebasename"     = "$($projectFile.BaseName)"
        }
        Replace-FilePlaceholders -InputFile "$topLevelDirectory/.config/docfx/build/docfx_local_template.json" -OutputFile "$topLevelDirectory/.config/docfx/build/docfx_local.json" -Replacements $replacements
        dotnet docfx "$topLevelDirectory/.config/docfx/build/docfx_local.json"
    }

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

foreach ($projectFile in $solutionProjectsObj) {

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
            dotnet nuget push "$($firstFileMatch.FullName)" --source LocalNuget
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
            dotnet nuget push "$($firstFileMatch.FullName)" --source LocalNuget
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
            dotnet nuget push "$($firstFileMatch.FullName)" --source LocalNuget
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
            dotnet nuget push "$($firstFileMatch.FullName)" --source LocalNuget
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

