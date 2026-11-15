using System.Security.Cryptography;
using Inat.Api.Data;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Inat.Api.Tests.Integration;

// the access check behind every cached answer, as inat_api against inat_test_empty
[TestClass]
public sealed class AccessContextIntegrationTests
{
    private const int MissingPermissionErrorNumber = 50021;
    private const int InvalidSessionErrorNumber = 50020;

    private static SecurityRepository securityRepository = null!;
    private static AccessRepository accessRepository = null!;

    [ClassInitialize]
    public static async Task ClassInitialize(TestContext testContext)
    {
        await TestDatabase.SeedAsync();

        IConfiguration configuration = TestDatabase.CreateApiConfiguration();
        SqlConnectionFactory connectionFactory = new SqlConnectionFactory(configuration);
        securityRepository = new SecurityRepository(connectionFactory);
        accessRepository = new AccessRepository(connectionFactory);
    }

    private static async Task<long> LogInAsync(string username)
    {
        LoginInfo? loginInfo = await securityRepository.GetLoginInfoAsync(username, CancellationToken.None);
        if (loginInfo == null)
        {
            Assert.Fail($"the test user {username} does not exist");
        }

        return await securityRepository.CreateSessionAsync(
            loginInfo.UserId, RandomNumberGenerator.GetBytes(32), DateTime.UtcNow.AddHours(1), null, null, CancellationToken.None);
    }

    [TestMethod]
    public async Task AccessContext_ScopeSignatureMatchesTheUsersScope()
    {
        long adminSessionId = await LogInAsync(TestDatabase.AdminUsername);
        long viewerSessionId = await LogInAsync(TestDatabase.ViewerUsername);

        AccessContext adminContext = await accessRepository.GetAccessContextAsync(adminSessionId, "dashboard.view", null, CancellationToken.None);
        AccessContext viewerContext = await accessRepository.GetAccessContextAsync(viewerSessionId, "dashboard.view", null, CancellationToken.None);

        Assert.AreEqual("48460", adminContext.ScopeSignature);
        Assert.AreEqual("20978", viewerContext.ScopeSignature);
        Assert.AreEqual(adminContext.DataVersion, viewerContext.DataVersion);
    }

    [TestMethod]
    public async Task AccessContext_IsDeniedWithoutThePermission()
    {
        long viewerSessionId = await LogInAsync(TestDatabase.ViewerUsername);

        SqlException exception = await Assert.ThrowsExactlyAsync<SqlException>(async () =>
        {
            await accessRepository.GetAccessContextAsync(viewerSessionId, "admin.users.manage", null, CancellationToken.None);
        });

        Assert.AreEqual(MissingPermissionErrorNumber, exception.Number);
    }

    // a revoked session must be refused even when the answer itself is sitting in the cache
    [TestMethod]
    public async Task AccessContext_IsDeniedAfterLogout()
    {
        long viewerSessionId = await LogInAsync(TestDatabase.ViewerUsername);
        await securityRepository.RevokeSessionAsync(viewerSessionId, "logout", null, CancellationToken.None);

        SqlException exception = await Assert.ThrowsExactlyAsync<SqlException>(async () =>
        {
            await accessRepository.GetAccessContextAsync(viewerSessionId, "dashboard.view", null, CancellationToken.None);
        });

        Assert.AreEqual(InvalidSessionErrorNumber, exception.Number);
    }
}