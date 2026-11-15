using System.Security.Cryptography;
using Inat.Api.Data;
using Inat.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Inat.Api.Tests.Integration;

// integration tests: the real repositories calling the real stored procedures in inat_test_empty,
// logged in as inat_api, so permissions are checked exactly like in production
[TestClass]
public sealed class RepositoryIntegrationTests
{
    private const int MissingPermissionErrorNumber = 50021;
    private const int PermissionDeniedErrorNumber = 229;
    private const int AmphibiaTaxonId = 20978;

    private static SqlConnectionFactory connectionFactory = null!;
    private static SecurityRepository securityRepository = null!;
    private static DashboardRepository dashboardRepository = null!;
    private static TaxonomyRepository taxonomyRepository = null!;
    private static AdminRepository adminRepository = null!;

    [ClassInitialize]
    public static async Task ClassInitialize(TestContext testContext)
    {
        await TestDatabase.SeedAsync();

        IConfiguration configuration = TestDatabase.CreateApiConfiguration();
        connectionFactory = new SqlConnectionFactory(configuration);
        securityRepository = new SecurityRepository(connectionFactory);
        dashboardRepository = new DashboardRepository(connectionFactory);
        taxonomyRepository = new TaxonomyRepository(connectionFactory);
        adminRepository = new AdminRepository(connectionFactory);
    }

    // what the api does after a correct password: a session with a fresh refresh token hash
    private static async Task<long> LogInAsync(string username)
    {
        LoginInfo? loginInfo = await securityRepository.GetLoginInfoAsync(username, CancellationToken.None);
        if (loginInfo == null)
        {
            Assert.Fail($"the test user {username} does not exist");
        }

        byte[] tokenHash = RandomNumberGenerator.GetBytes(32);

        return await securityRepository.CreateSessionAsync(
            loginInfo.UserId,
            tokenHash,
            DateTime.UtcNow.AddHours(1),
            "127.0.0.1",
            "integration tests",
            CancellationToken.None);
    }

    [TestMethod]
    public async Task GetLoginInfo_ReturnsAHashThatVerifiesTheRealPassword()
    {
        LoginInfo? loginInfo = await securityRepository.GetLoginInfoAsync(TestDatabase.AdminUsername, CancellationToken.None);
        if (loginInfo == null)
        {
            Assert.Fail("the admin test user was not found");
        }

        PasswordHasher<object> passwordHasher = new PasswordHasher<object>();
        PasswordVerificationResult rightPassword = passwordHasher.VerifyHashedPassword(new object(), loginInfo.PasswordHash, TestDatabase.AdminPassword);
        PasswordVerificationResult wrongPassword = passwordHasher.VerifyHashedPassword(new object(), loginInfo.PasswordHash, "wrong password");

        Assert.AreNotEqual(PasswordVerificationResult.Failed, rightPassword);
        Assert.AreEqual(PasswordVerificationResult.Failed, wrongPassword);
        Assert.IsFalse(loginInfo.IsLocked);
    }

    [TestMethod]
    public async Task TaxonChildren_AdminSeesBothKingdomsWithCounts()
    {
        long sessionId = await LogInAsync(TestDatabase.AdminUsername);

        IReadOnlyList<TaxonChildCount> children =
            await dashboardRepository.GetTaxonChildrenCountsAsync(sessionId, null, null, CancellationToken.None);

        Assert.AreEqual(2, children.Count);
        Assert.AreEqual("Animalia", children[0].ScientificName);
        Assert.AreEqual(3, children[0].ObservationCount);
        Assert.AreEqual("Plantae", children[1].ScientificName);
        Assert.AreEqual(1, children[1].ObservationCount);
    }

    [TestMethod]
    public async Task TaxonChildren_ViewerOnlySeesTheirScope()
    {
        long sessionId = await LogInAsync(TestDatabase.ViewerUsername);

        IReadOnlyList<TaxonChildCount> children =
            await dashboardRepository.GetTaxonChildrenCountsAsync(sessionId, null, null, CancellationToken.None);

        Assert.AreEqual(1, children.Count);
        Assert.AreEqual("Animalia", children[0].ScientificName);
        Assert.AreEqual(3, children[0].ObservationCount);
    }

    [TestMethod]
    public async Task ObservationsPage_CursorContinuesWithoutRepeats()
    {
        long sessionId = await LogInAsync(TestDatabase.ViewerUsername);

        IReadOnlyList<ObservationCard> firstPage = await taxonomyRepository.GetObservationsPageAsync(
            sessionId, AmphibiaTaxonId, 2, null, null, null, CancellationToken.None);

        Assert.AreEqual(2, firstPage.Count);
        Assert.AreEqual(new DateOnly(2026, 1, 12), firstPage[0].ObservedDate);
        Assert.AreEqual(new DateOnly(2026, 1, 11), firstPage[1].ObservedDate);

        ObservationCard lastCard = firstPage[firstPage.Count - 1];
        IReadOnlyList<ObservationCard> secondPage = await taxonomyRepository.GetObservationsPageAsync(
            sessionId, AmphibiaTaxonId, 2, lastCard.ObservedDate, lastCard.ObservationId, null, CancellationToken.None);

        Assert.AreEqual(1, secondPage.Count);
        Assert.AreEqual(new DateOnly(2026, 1, 10), secondPage[0].ObservedDate);
        Assert.IsNotNull(secondPage[0].MediumUrl);
    }

    // the dynamic sql inside spUser_Grid only works for inat_api because of WITH EXECUTE AS OWNER.
    // without it, this test fails with "SELECT permission was denied"
    [TestMethod]
    public async Task UsersGrid_RunsAsTheApiLogin()
    {
        long sessionId = await LogInAsync(TestDatabase.AdminUsername);

        UserGridResponse response = await adminRepository.GetUsersGridAsync(
            sessionId, 1, 25, "it.", null, "Username", "asc", null, CancellationToken.None);

        Assert.AreEqual(2, response.TotalCount);
        Assert.AreEqual(TestDatabase.AdminUsername, response.Items[0].Username);
        Assert.AreEqual(TestDatabase.ViewerUsername, response.Items[1].Username);
    }

    [TestMethod]
    public async Task UsersGrid_IsDeniedForViewers()
    {
        long sessionId = await LogInAsync(TestDatabase.ViewerUsername);

        SqlException exception = await Assert.ThrowsExactlyAsync<SqlException>(async () =>
        {
            await adminRepository.GetUsersGridAsync(
                sessionId, 1, 25, null, null, "Username", "asc", null, CancellationToken.None);
        });

        Assert.AreEqual(MissingPermissionErrorNumber, exception.Number);
    }

    [TestMethod]
    public async Task Refresh_RotatesTheTokenAndDetectsReuse()
    {
        LoginInfo? loginInfo = await securityRepository.GetLoginInfoAsync(TestDatabase.ViewerUsername, CancellationToken.None);
        if (loginInfo == null)
        {
            Assert.Fail("the viewer test user was not found");
        }

        byte[] firstTokenHash = RandomNumberGenerator.GetBytes(32);
        byte[] secondTokenHash = RandomNumberGenerator.GetBytes(32);
        byte[] thirdTokenHash = RandomNumberGenerator.GetBytes(32);

        await securityRepository.CreateSessionAsync(
            loginInfo.UserId, firstTokenHash, DateTime.UtcNow.AddHours(1), null, null, CancellationToken.None);

        SessionRefreshResult firstRefresh = await securityRepository.RefreshSessionAsync(
            firstTokenHash, secondTokenHash, DateTime.UtcNow.AddHours(2), null, CancellationToken.None);

        SessionRefreshResult reuseOfFirstToken = await securityRepository.RefreshSessionAsync(
            firstTokenHash, thirdTokenHash, DateTime.UtcNow.AddHours(3), null, CancellationToken.None);

        Assert.AreEqual("ok", firstRefresh.Result);
        Assert.AreEqual("reused", reuseOfFirstToken.Result);
    }

    [TestMethod]
    public async Task ApiLogin_CannotReadTablesDirectly()
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(CancellationToken.None);
        await using SqlCommand command = new SqlCommand("SELECT TOP (1) PasswordHash FROM security.[User]", connection);

        SqlException exception = await Assert.ThrowsExactlyAsync<SqlException>(async () =>
        {
            await command.ExecuteScalarAsync();
        });

        Assert.AreEqual(PermissionDeniedErrorNumber, exception.Number);
    }
}