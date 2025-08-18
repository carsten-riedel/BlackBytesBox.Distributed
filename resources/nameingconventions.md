### General BlackBytesBox naming conventions
---

- **BlackBytesBox.Manifested** (PowerShell module)
- **BlackBytesBox.Distributed** (Dotnet tool)

### NETSTANDARD2.0 LIBRARY

* **BlackBytesBox.Unified.Core**: `SDK: Microsoft.NET.Sdk` · `Target Framework: netstandard2.0` · `Dependencies: none`
* **BlackBytesBox.Unified.Base**: `SDK: Microsoft.NET.Sdk` · `Target Framework: netstandard2.0` · `Dependencies: Microsoft-compatible packages`
* **BlackBytesBox.Unified.Integrated**: `SDK: Microsoft.NET.Sdk` · `Target Framework: netstandard2.0` · `Dependencies: third-party packages`

### NET6–9 LIBRARY

* **BlackBytesBox.Composed.Core**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0, net7.0, net8.0, net9.0` · `Dependencies: none`
* **BlackBytesBox.Composed.Base**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0, net7.0, net8.0, net9.0` · `Dependencies: Microsoft-compatible packages`
* **BlackBytesBox.Composed.Integrated**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0, net7.0, net8.0, net9.0` · `Dependencies: third-party packages`

### NET6–9 WINDOWS LIBRARY

* **BlackBytesBox.Marshaled.Core**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0-windows, net7.0-windows, net8.0-windows, net9.0-windows` · `Dependencies: none`
* **BlackBytesBox.Marshaled.Base**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0-windows, net7.0-windows, net8.0-windows, net9.0-windows` · `Dependencies: Microsoft-compatible packages`
* **BlackBytesBox.Marshaled.Integrated**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0-windows, net7.0-windows, net8.0-windows, net9.0-windows` · `Dependencies: third-party packages`
* **BlackBytesBox.Marshaled.WinForms**: `SDK: Microsoft.NET.Sdk` · `Target Frameworks: net6.0-windows, net7.0-windows, net8.0-windows, net9.0-windows` · `Dependencies: WinForms`

### WEB (ROUTED) LIBRARY

* **BlackBytesBox.Routed.Core**: `SDK: Microsoft.NET.Sdk.Web` · `Target Frameworks: net6.0, net7.0, net8.0, net9.0` · `Dependencies: none`
* **BlackBytesBox.Routed.Base**: `SDK: Microsoft.NET.Sdk.Web` · `Target Frameworks: net6.0, net7.0, net8.0, net9.0` · `Dependencies: Microsoft-compatible packages`
* **BlackBytesBox.Routed.Integrated**: `SDK: Microsoft.NET.Sdk.Web` · `Target Frameworks: net6.0, net7.0, net8.0, net9.0` · `Dependencies: third-party packages`

### DEPRECATED FRAMEWORK 2.0

* **BlackBytesBox.DepreactedNet2.Core**: `.NET Framework 2.0` · `Dependencies: none`
* **BlackBytesBox.DepreactedNet2.Base**: `.NET Framework 2.0` · `Dependencies: none`
* **BlackBytesBox.DepreactedNet2.Integrated**: `.NET Framework 2.0` · `Dependencies: none`
* **BlackBytesBox.DepreactedNet2.WinForms**: `.NET Framework 2.0` · `Dependencies: none`

### DEPRECATED FRAMEWORK 4.0

* **BlackBytesBox.DepreactedNet4.Core**: `.NET Framework 4.0` · `Dependencies: none`
* **BlackBytesBox.DepreactedNet4.Base**: `.NET Framework 4.0` · `Dependencies: none`
* **BlackBytesBox.DepreactedNet4.Integrated**: `.NET Framework 4.0` · `Dependencies: none`
* **BlackBytesBox.DepreactedNet4.WinForms**: `.NET Framework 4.0` · `Dependencies: none`


- **BlackBytesBox.Bladed** (ASP.NET Razor library)
- **BlackBytesBox.Seeded** (template project)

- **BlackBytesBox.[Adjective].[Qualifier]** (for further clarity when needed)

### Active projects

- Powershell Manifest Module [BlackBytesBox.Manifested.Initialize](https://github.com/carsten-riedel/BlackBytesBox.Manifested.Initialize)
- Powershell Manifest Module [BlackBytesBox.Manifested.Version](https://github.com/carsten-riedel/BlackBytesBox.Manifested.Version)
- Powershell Manifest Module [BlackBytesBox.Manifested.GitX](https://github.com/carsten-riedel/BlackBytesBox.Manifested.GitX)

- ASP.NET Core Filters [BlackBytesBox.Routed.RequestFilters](https://github.com/carsten-riedel/BlackBytesBox.Routed.RequestFilters)
- Dotnet tool bbdist [BlackBytesBox.Distributed](https://github.com/carsten-riedel/BlackBytesBox.Distributed)
- Microsoft.NET.Sdk ; netstandard2.0 ; no thirdparty packages [BlackBytesBox.Unified.Core](https://github.com/carsten-riedel/BlackBytesBox.Unified.Core)


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



