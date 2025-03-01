using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Build.Construction;
using Microsoft.Extensions.Logging;

namespace BlackBytesBox.Distributed.Services
{
    /// <summary>
    /// A service for retrieving project file paths and properties from a solution.
    /// </summary>
    public interface ISolutionProjectService
    {
        /// <summary>
        /// Retrieves the absolute paths of csproj files from the specified solution.
        /// </summary>
        /// <param name="solutionLocation">The full path to the solution file.</param>
        /// <param name="cancellationToken">A token for monitoring cancellation requests.</param>
        /// <returns>A list of absolute paths to csproj files.</returns>
        Task<List<string>> GetCsProjAbsolutPathsFromSolutions(string solutionLocation, CancellationToken cancellationToken);

        /// <summary>
        /// Retrieves a specified project property from a project file.
        /// </summary>
        /// <param name="projectLocation">The full path to the project file.</param>
        /// <param name="propertyName">The name of the property to retrieve.</param>
        /// <param name="scopeType">The element scope used to determine the property value (inner or outer element).</param>
        /// <param name="cancellationToken">A token for monitoring cancellation requests.</param>
        /// <returns>The property value if found; otherwise, null.</returns>
        Task<string?> GetProjectProperty(string projectLocation, string? propertyName, Commands.CsProjCommand.Settings.ElementScope? scopeType, CancellationToken cancellationToken);
    }

    /// <summary>
    /// A concrete implementation of <see cref="ISolutionProjectService"/> that retrieves project paths and properties.
    /// </summary>
    public class SolutionProjectService : ISolutionProjectService
    {
        private readonly ILogger<SolutionProjectService> _logger;

        public SolutionProjectService(ILogger<SolutionProjectService> logger)
        {
            _logger = logger;
        }

        public async Task<List<string>> GetCsProjAbsolutPathsFromSolutions(string solutionLocation, CancellationToken cancellationToken)
        {
            List<string> retval = new List<string>();
            try
            {
                List<ProjectInSolution> sln = SolutionFile.Parse(solutionLocation).ProjectsInOrder.Where(e => e.ProjectType == SolutionProjectType.KnownToBeMSBuildFormat).ToList();
                List<ProjectRootElement> projects = new List<ProjectRootElement>();

                // Load each project file.
                foreach (var item in sln)
                {
                    try
                    {
                        ProjectRootElement projectRoot = ProjectRootElement.Open(item.AbsolutePath);
                        projects.Add(projectRoot);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed to open project file: {ProjectLocation}", item.AbsolutePath);
                        return null;
                    }
                }

                // Sort projects so that any project that has a PackageReference with Include="Microsoft.NET.Test.Sdk" appears first.
                // Test projects: projects with any PackageReference that has Include "Microsoft.NET.Test.Sdk".
                var testProjects = projects.Where(project =>
                    project.Items.Any(item =>
                        item.ElementName == "PackageReference" &&
                        string.Equals(item.Include, "Microsoft.NET.Test.Sdk", StringComparison.OrdinalIgnoreCase)
                    )
                ).ToList();

                // Non-test projects: projects that do NOT have any PackageReference with Include "Microsoft.NET.Test.Sdk".
                var nonTestProjects = projects.Where(project =>
                    !project.Items.Any(item =>
                        item.ElementName == "PackageReference" &&
                        string.Equals(item.Include, "Microsoft.NET.Test.Sdk", StringComparison.OrdinalIgnoreCase)
                    )
                ).ToList();

                foreach (var item in testProjects)
                {
                    retval.Add(item.FullPath);
                }

                foreach (var item in nonTestProjects)
                {
                    retval.Add(item.FullPath);
                }

                //projects.Items.where // dont' know here items ElementName == "PackageReference" and on this if there is an Include == "Microsoft.NET.Test.Sdk" this project should be sorted first.
                //projects.OrderBy(e => e.Items == "PackageReference");

                if (retval.Count == 0)
                {
                    _logger.LogWarning("No csproj files were found in the solution: {SolutionLocation}", solutionLocation);
                }
                else
                {
                    _logger.LogDebug("Found {Count} csproj files in the solution: {SolutionLocation}", retval.Count, solutionLocation);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while parsing the solution file: {SolutionLocation}", solutionLocation);
                throw;
            }

            return retval;
        }

        public async Task<string?> GetProjectProperty(string projectLocation, string? propertyName, Commands.CsProjCommand.Settings.ElementScope? scopeType, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(propertyName))
            {
                _logger.LogWarning("No property name was specified for project: {ProjectLocation}", projectLocation);
                return null;
            }

            ProjectRootElement projectRoot;
            try
            {
                projectRoot = ProjectRootElement.Open(projectLocation);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to open project file: {ProjectLocation}", projectLocation);
                return null;
            }

            var property = projectRoot.Properties.FirstOrDefault(e => e.Name.Equals(propertyName, StringComparison.OrdinalIgnoreCase));

            if (property == null)
            {
                _logger.LogWarning("Property '{PropertyName}' was not found in the project file: {ProjectLocation}", propertyName, projectLocation);
                return null;
            }

            if (scopeType.HasValue)
            {
                if (scopeType.Value == Commands.CsProjCommand.Settings.ElementScope.InnerElement)
                {
                    _logger.LogDebug("Returning inner element value for property '{PropertyName}' from project: {ProjectLocation}", propertyName, projectLocation);
                    return property.Value;
                }
                else
                {
                    _logger.LogDebug("Returning outer element value for property '{PropertyName}' from project: {ProjectLocation}", propertyName, projectLocation);
                    return property.OuterElement;
                }
            }
            else
            {
                _logger.LogWarning("No element scope specified for property '{PropertyName}' in project: {ProjectLocation}", propertyName, projectLocation);
                return null;
            }
        }
    }
}
