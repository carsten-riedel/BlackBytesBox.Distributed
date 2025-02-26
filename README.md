
# BlackBytesBox.Distributed 

BlackBytesBox.Distributed is a multi-purpose command-line .NET tool, containing a suite of helper functionalities designed for application development, CI/CD processes, and NuGet package management.

## Prerequisites
- .NET SDK: Ensure you have the .NET SDK installed on your machine. If not, download and install it from [the official .NET website](https://dotnet.microsoft.com/download).

## Installing the Tool
To install the tool globally on your machine, run the following command in your terminal:

### Install/Update/Reinstall as global tool
```
dotnet tool install -g BlackBytesBox.Distributed
```

#### Use
```
bbdist -h
bbdist dump osversion
bbdist dump envars
```

### Install/Update/Reinstall as local tool
```
dotnet tool install BlackBytesBox.Distributed
```

#### Use
```
dotnet bbdist -h
dotnet bbdist dump osversion
dotnet bbdist dump envars
```

### General BlackBytesBox naming conventions
---

BlackBytesBox.Manifested (PowerShell module)
BlackBytesBox.Unified (NET Standard library)
BlackBytesBox.Distributed (Dotnet tool)
BlackBytesBox.Composed (NET library)
BlackBytesBox.Dosed (NET-Windows library)
BlackBytesBox.Routed (ASP.NET library)
BlackBytesBox.Sliced (ASP.NET Razor library)
BlackBytesBox.Depreacted (old .NET Framework 4.0 library)
BlackBytesBox.Seeded (template project)
BlackBytesBox.[Adjective].[Qualifier] (for further clarity when needed)

BlackBytesBox.Manifested.Base  (Powershell module)
BlackBytesBox.Distributed.Core  (Dotnet tool)