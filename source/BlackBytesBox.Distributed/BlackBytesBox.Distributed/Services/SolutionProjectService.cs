using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Build.Construction;
using Microsoft.Extensions.Logging;

namespace BlackBytesBox.Distributed.Services
{
    /// <summary>
    /// A service for retrieving and displaying the operating system version.
    /// </summary>
    public interface ISolutionProjectService
    {
        /// <summary>
        /// Displays the current operating system version.
        /// </summary>
        Task<List<string>> GetCsProjAbsolutPathsFromSolutions(string solutionLocation, CancellationToken cancellationToken);
        Task<string?> GetProjectProperty(string projectLocation, string? propertyName, Commands.CsProjCommand.Settings.ScopeType? scopeType, CancellationToken cancellationToken);
    }

    /// <summary>
    /// A concrete implementation of IOsVersionService that writes the OS version to the console.
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
            var sln = Microsoft.Build.Construction.SolutionFile.Parse(solutionLocation);

            foreach (var item in sln.ProjectsInOrder)
            {
                if (item.ProjectType == Microsoft.Build.Construction.SolutionProjectType.KnownToBeMSBuildFormat)
                {
                    retval.Add(item.AbsolutePath);
                }
            }
            return retval;
        }

        public async Task<string?> GetProjectProperty(string projectLocation,string? propertyName, Commands.CsProjCommand.Settings.ScopeType? scopeType, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(propertyName))
            {
                return null;
            }

            var projectRoot = ProjectRootElement.Open(projectLocation);

            var property = projectRoot.Properties.FirstOrDefault(e => e.Name == propertyName);

            if (scopeType.HasValue)
            {
                if (scopeType.Value == Commands.CsProjCommand.Settings.ScopeType.InnerElement)
                {
                    return property?.Value;
                }
                else
                {
                    return property?.OuterElement;
                }
                    
            }
            else
            {
                return null;
            }


            //var filter = sln.ProjectsInOrder.FirstOrDefault(e => e.ProjectType == Microsoft.Build.Construction.SolutionProjectType.KnownToBeMSBuildFormat);

            //foreach (var item in sln.ProjectsInOrder)
            //{
            //    if (item.ProjectType == Microsoft.Build.Construction.SolutionProjectType.KnownToBeMSBuildFormat)
            //    {
            //        var projectRoot = ProjectRootElement.Open(item.AbsolutePath);
            //    }

            //}
        }

    }
}
