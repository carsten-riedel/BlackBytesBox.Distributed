
# STROM.ATOM.TOOL.Common 

STROM.ATOM.TOOL.Common is a multi-purpose command-line .NET tool, containing a suite of helper functionalities designed for application development, CI/CD processes, and NuGet package management.

## Prerequisites
- .NET SDK: Ensure you have the .NET SDK installed on your machine. If not, download and install it from [the official .NET website](https://dotnet.microsoft.com/download).

## Installing the Tool
To install the tool globally on your machine, run the following command in your terminal:

### Install/Update/Reinstall as global tool
```
dotnet tool install -g STROM.ATOM.TOOL.Common
```

#### Use
```
satcom -h
satcom dump osversion
satcom dump envars
```

### Install/Update/Reinstall as local tool
```
dotnet tool install STROM.ATOM.TOOL.Common
```

#### Use
```
dotnet satcom -h
dotnet satcom dump osversion
dotnet satcom dump envars
```

### General STROM naming conventions
---

**STROM** is a lean, modular framework built on three layers:

- **STROM**: The core architectural foundation. (**S**ystem **T**echnology **R**epository for **O**bject **M**odularization)

**Naming Conventions**
- **CELL**: The application layer. (**C**ontained **E**xecution in **L**ocalized **L**ayers)
- **ATOM**: Lightweight, single-purpose libraries. (**A**gile **T**echnology for **O**perational **M**echanics)
- **NANO**: Ultra-light libraries with only Microsoft dependencies. (**N**ucleus **A**rtifacts for **N**anoscale **O**perations)

**Targets**
- **NS**: Compatible with .NET Standard for broad compatibility (e.g., `netstandard2.1`).  
- **NETFX**: Designed for the legacy .NET Framework (e.g., `net40` for Windows XP compatibility).  
- **NET**: Built on modern, cross-platform .NET (e.g., `net7.0`).  
- **NETW**: Incorporates Windows-specific extensions (e.g., `net7.0-windows`).  
- **NETW10**: Targets Windows 10 features (e.g., `net7.0-windows10.0.19041.0`).
- **PSWH**: PowerShell Script
- **PSMOD**: PowerShell C# Module.
- **TOOL**: dotnet tool.
- **MSBUILD**: C# MSBUILD Project.
- **TEMPLATE**: NET Templates.

## Branch to Channel mappings
| **Branch Type**        | **Example Name**    | **Build and Deployment Channel (Large: 20+ FT)** | **Build and Deployment Channel (Normal: 10–20 FT)** | **Build and Deployment Channel (Small: 5–10 FT)** | **Build and Deployment Channel (Mini: 1–5 FT)** | **Best Practice Guidelines**                                                                                                                                                                                         |
|------------------------|---------------------|--------------------------------------------------|---------------------------------------------------|---------------------------------------------------|-------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Other/Experimental     | `experimental/*`    | none                                             | none                                              | none                                              | none                                            | Intended for trial or temporary work. No builds or deployments are activated, keeping infrastructure costs to a minimum.                                                                                              |
| Feature                | `feature/*`         | development                                      | development (build-only)                          | development (build-only)                          | development (build-only)                        | Used for early code validation and feedback. Larger teams may deploy to a dedicated development environment; Normal, Small, and Mini teams perform builds only to conserve resources.                            |
| Develop                | `develop`           | quality                                          | quality                                           | staging                                           | quality                                         | Serves as the central integration branch. Large and Normal teams maintain a dedicated quality environment; Small teams consolidate integration into staging, while Mini teams use quality to avoid extra overhead.  |
| Bugfix                 | `bugfix/*`          | quality                                          | quality                                           | staging                                           | quality                                         | Addresses integration issues. Larger and Normal teams use a dedicated quality channel; Small teams merge bugfixes into staging, and Mini teams consolidate fixes in quality to streamline maintenance.          |
| Release                | `release/*`         | staging                                          | staging                                           | -                                                 | -                                               | Prepares code for production. Large and Normal teams use staging for final validation and user acceptance testing. Small and Mini teams, to cut costs, do not use separate release branches and deploy directly via master/main. |
| Master/Main            | `master`/`main`     | production                                       | production                                        | production                                        | production                                      | Contains production-ready code. Rigorous builds and testing ensure that only fully validated changes are deployed live, regardless of team size.                                                                      |
| Hotfix                 | `hotfix/*`          | production                                       | production                                        | production                                        | production                                      | For urgent production fixes. Expedited builds and deployments address critical issues promptly, with fixes merged back into integration branches to maintain consistency.                                     |


| **Channel Name** | **Description**                                                                             | **Cost Impact**                  | **Maintenance Complexity**            |
|------------------|---------------------------------------------------------------------------------------------|----------------------------------|-----------------------------------------|
| none             | No build or deployment environment is activated.                                          | Negligible – no additional cost. | Minimal – no infrastructure to manage.|
| development      | A basic environment for code validation and early feedback.                                 | Low – basic build servers and tooling. | Low – simple setup, fewer integrations.  |
| quality          | A dedicated integration (QA) environment for thorough testing and validation.               | Moderate – additional resources required for testing and monitoring. | Moderate – requires regular updates and test data management. |
| staging          | An environment that mirrors production for final validation, user acceptance testing, etc.   | High – similar to production in cost.  | High – needs to stay in sync with production and replicate its conditions. |
| production       | The live environment for production-ready code.                                             | Highest – extensive resources, security, and reliability are needed. | Highest – continuous monitoring, support, and compliance efforts.         |
