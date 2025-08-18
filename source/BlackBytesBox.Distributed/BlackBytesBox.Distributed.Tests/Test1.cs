namespace BlackBytesBox.Distributed.Tests
{
    using System.Runtime.Intrinsics.X86;
    using System.Threading;
    using System.Threading.Tasks;

    using global::BlackBytesBox.Distributed.Services;

    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging;

    using Microsoft.VisualStudio.TestTools.UnitTesting;

    namespace BlackBytesBox.Distributed.Tests
    {
        [TestClass]
        public sealed class OsVersionServiceTests
        {
            private static IHost? host;

            [AssemblyInitialize]
            public static void AssemblyInit(TestContext context)
            {
                // This method is called once for the test assembly, before any tests are run.
            }

            [AssemblyCleanup]
            public static void AssemblyCleanup()
            {
                // This method is called once for the test assembly, after all tests are run.
            }

            [ClassInitialize]
            public static void ClassInit(TestContext context)
            {
                // This method is called once for the test class, before any tests of the class are run.
                host = Host.CreateDefaultBuilder()
                    .ConfigureLogging((ctx, configureLogging) => {
                        configureLogging.ClearProviders();
                        configureLogging.AddConsole();
                    })
                    .ConfigureServices((ctx, services) =>
                    {
                        services.AddTransient<IOsVersionService, OsVersionService>();
                    })
                    .Build();
            }

            [ClassCleanup]
            public static void ClassCleanup()
            {
                // This method is called once for the test class, after all tests of the class are run.
                host?.Dispose();
            }

            [TestInitialize]
            public void TestInit()
            {
                // This method is called before each test method.
            }

            [TestCleanup]
            public void TestCleanup()
            {
                // This method is called after each test method.
            }


            [TestMethod]
            [DataRow(100)]
            [DataRow(200)]
            [DataRow(500)]
            public async Task TestOsVersionServiceIntegration(int delay)
            {
                // Resolve the service from the host's service provider.
                if (host is null) throw new InvalidOperationException("Host is not initialized.");
                IOsVersionService osVersionService = host.Services.GetRequiredService<IOsVersionService>();

                // Call the service method with a short delay and a cancellation token.
                await osVersionService.ShowOsVersion(CancellationToken.None);
            }

            [TestMethod]
            [DataRow(100)]
            public void Versioning(int delay)
            {
                var mapped2 = Utility.Utility.MapDateTimeToUShorts();

                var start = new DateTime(2025, 2, 16);
                var end = start.AddDays(1);
                for (var i = start; i < end; i = i.AddHours(1))
                {
                    var mapped = Utility.Utility.MapDateTimeToUShorts(i);
                    Console.WriteLine($"{mapped.HighPart}-{mapped.LowPart}   {i.ToString()}");
                }
            }

            [TestMethod]
            [DataRow(100)]
            public void FooTest(int delay)
            {
                // The below calls check if the instruction sets are supported on the current CPU and OS
                Console.WriteLine($"SSE  : {Sse.IsSupported}");
                Console.WriteLine($"SSE2 : {Sse2.IsSupported}");
                Console.WriteLine($"SSE3 : {Sse3.IsSupported}");
                Console.WriteLine($"SSSE3: {Ssse3.IsSupported}");
                Console.WriteLine($"SSE4.1: {Sse41.IsSupported}");
                Console.WriteLine($"SSE4.2: {Sse42.IsSupported}");

                // AES and PCLMULQDQ are also checkable
                Console.WriteLine($"AES     : {Aes.IsSupported}");
                Console.WriteLine($"PCLMULQDQ: {Pclmulqdq.IsSupported}");

                // AVX / AVX2 / FMA checks
                Console.WriteLine($"AVX  : {Avx.IsSupported}");
                Console.WriteLine($"AVX2 : {Avx2.IsSupported}");
                Console.WriteLine($"FMA  : {Fma.IsSupported}");

                // .NET 7 introduced SHA
                // if you target .NET 7 or higher, you can check SHA:
                // Console.WriteLine($"SHA : {Sha.IsSupported}");
            }
        }
    }
}