# BlackBytesBox.Distributed

BlackBytesBox.Distributed is a multi-purpose command-line .NET tool containing a suite of helper functionalities designed for application development, CI/CD processes, and NuGet package management.

## Prerequisites
- **.NET SDK:** Ensure you have the .NET SDK installed on your machine. If not, download and install it from [the official .NET website](https://dotnet.microsoft.com/download).

## Installing the Tool

### Install/Update/Reinstall as a Global Tool
```
dotnet tool install -g BlackBytesBox.Distributed
```

#### Usage (Global Installation)
```
bbdist -h
bbdist dump osversion
bbdist dump envars
```

### Install/Update/Reinstall as a Local Tool
```
dotnet tool install BlackBytesBox.Distributed
```

#### Usage (Local Installation)
```
dotnet bbdist -h
dotnet bbdist dump osversion
dotnet bbdist dump envars
```

## Commands Examples

### SlnCommand
The **SlnCommand** retrieves csproj file paths from a solution file. For example, you can invoke it as follows:
```
bbdist sln -f "C:\Projects\MySolution.sln" -m Information -i
```
- **-f "C:\Projects\MySolution.sln"** specifies the solution file path.
- **-m Information** sets the minimum log level to Information.
- **-i** enables the ignore errors flag, ensuring the command returns 0 even if errors occur.

### CsProjCommand
The **CsProjCommand** retrieves a specified project property from a project file. An example invocation is:
```
bbdist csproj -f "C:\Projects\MyProject.csproj" --property IsPublishable --elementscope InnerElement -m Warning -i
```
- **-f "C:\Projects\MyProject.csproj"** specifies the project file path.
- **--property IsPublishable** indicates the project property to retrieve.
- **--elementscope InnerElement** specifies the element scope (the default is InnerElement).
- **-m Warning** sets the minimum log level to Warning.
- **-i** enables the ignore errors flag.

## General BlackBytesBox Naming Conventions

---

- **BlackBytesBox.Manifested** (PowerShell module)
- **BlackBytesBox.Unified** (NET Standard library)
- **BlackBytesBox.Distributed** (Dotnet tool)
- **BlackBytesBox.Composed** (NET library)
- **BlackBytesBox.Dosed** (NET-Windows library)
- **BlackBytesBox.Routed** (ASP.NET library)
- **BlackBytesBox.Sliced** (ASP.NET Razor library)
- **BlackBytesBox.Depreacted** (old .NET Framework 4.0 library)
- **BlackBytesBox.Seeded** (template project)
- **BlackBytesBox.[Adjective].[Qualifier]** (for further clarity when needed)

- **BlackBytesBox.Manifested.Base** (PowerShell module)
- **BlackBytesBox.Distributed.Core** (Dotnet tool)