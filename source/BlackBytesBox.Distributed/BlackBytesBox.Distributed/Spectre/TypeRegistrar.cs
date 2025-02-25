using System;

using Microsoft.Extensions.DependencyInjection;

using Spectre.Console.Cli;

namespace BlackBytesBox.Distributed.Spectre
{
    /// <summary>
    /// Implements Spectre.Console.Cli's ITypeRegistrar for dependency injection using IServiceCollection.
    /// </summary>
    public class TypeRegistrar : ITypeRegistrar
    {
        private readonly IServiceCollection _builder;

        public TypeRegistrar(IServiceCollection builder) => _builder = builder;

        public ITypeResolver Build() => new TypeResolver(_builder.BuildServiceProvider());

        public void Register(Type service, Type implementation) =>
            _builder.AddSingleton(service, implementation);

        public void RegisterInstance(Type service, object implementation) =>
            _builder.AddSingleton(service, implementation);

        public void RegisterLazy(Type service, Func<object> func)
        {
            if (func is null) throw new ArgumentNullException(nameof(func));
            _builder.AddSingleton(service, provider => func());
        }
    }
}