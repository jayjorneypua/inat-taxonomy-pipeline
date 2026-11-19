using System.Diagnostics;
using Inat.Api.Data;
using Inat.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Services;

// warms the dashboard cache after every new sync, so the first visitor after the 06:00 sync gets
// cached answers instead of cold queries. runs as its own Viewer account and goes through the same
// procs, permission checks and cache keys as a real request, so sessions with the warmer's scope get
// the hits; other scopes still fill their cache on first use.
//   every interval: read DataVersion with spSession_GetAccessContext on its own session (no new login)
//   new version:    load taxon-children and observations-by-month for the start taxon and its children
// off when CacheWarmer:Username, CacheWarmer:Password or CacheWarmer:RootTaxonId is not set.
// never records failed logins, so a wrong password in the config cannot lock the account.
public sealed class CacheWarmer(
    IServiceScopeFactory scopeFactory,
    TokenService tokenService,
    IConfiguration configuration,
    ILogger<CacheWarmer> logger) : BackgroundService
{
    // query names must match DashboardController, otherwise the warmed keys are never asked for
    private const string TaxonChildrenQueryName = "taxon-children";
    private const string ObservationsByMonthQueryName = "observations-by-month";
    private const string DashboardViewPermission = "dashboard.view";
    private const int SessionInvalidErrorNumber = 50020;
    private const string WarmerUserAgent = "inat cache warmer";
    private static readonly PasswordHasher<object> passwordHasher = new PasswordHasher<object>();

    private readonly string _username = configuration["CacheWarmer:Username"] ?? string.Empty;
    private readonly string _password = configuration["CacheWarmer:Password"] ?? string.Empty;
    private readonly int _rootTaxonId = configuration.GetValue<int>("CacheWarmer:RootTaxonId", 0);
    private readonly TimeSpan _interval = TimeSpan.FromSeconds(configuration.GetValue<int>("CacheWarmer:IntervalSeconds", 60));

    private long? _sessionId;
    private long _warmedDataVersion;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (string.IsNullOrWhiteSpace(_username) || string.IsNullOrWhiteSpace(_password) || _rootTaxonId <= 0)
        {
            logger.LogInformation("Cache warmer off (CacheWarmer:Username, Password or RootTaxonId not set)");
            return;
        }

        logger.LogInformation("Cache warmer started as {Username}, root taxon {RootTaxonId}, every {IntervalSeconds} s"
            , _username
            , _rootTaxonId
            , _interval.TotalSeconds);

        while (stoppingToken.IsCancellationRequested == false)
        {
            try
            {
                await RunOnceAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                // for example sql server is down: log it, try again next interval, never stop the api
                logger.LogWarning(ex, "Cache warmer run failed, trying again next interval");
            }

            try
            {
                await Task.Delay(_interval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    // end the warmer's session on shutdown, so it doesn't stay open for 7 days
    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        await base.StopAsync(cancellationToken);

        if (_sessionId is null)
        {
            return;
        }

        try
        {
            using IServiceScope scope = scopeFactory.CreateScope();
            SecurityRepository securityRepository = scope.ServiceProvider.GetRequiredService<SecurityRepository>();
            await securityRepository.RevokeSessionAsync(_sessionId.Value, "logout", null, cancellationToken);
            _sessionId = null;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Cache warmer could not end its session");
        }
    }

    private async Task RunOnceAsync(CancellationToken stoppingToken)
    {
        using IServiceScope scope = scopeFactory.CreateScope();
        SecurityRepository securityRepository = scope.ServiceProvider.GetRequiredService<SecurityRepository>();
        AccessRepository accessRepository = scope.ServiceProvider.GetRequiredService<AccessRepository>();

        if (_sessionId is null)
        {
            _sessionId = await LogInAsync(securityRepository, stoppingToken);
            if (_sessionId is null)
            {
                return;
            }
        }

        AccessContext accessContext;
        try
        {
            accessContext = await accessRepository.GetAccessContextAsync(
                _sessionId.Value, DashboardViewPermission, null, stoppingToken);
        }
        catch (SqlException ex) when (ex.Number == SessionInvalidErrorNumber)
        {
            // expired or revoked by an admin: log in again next interval
            logger.LogInformation("Cache warmer session ended, logging in again next interval");
            _sessionId = null;
            return;
        }

        if (accessContext.DataVersion == _warmedDataVersion)
        {
            return;
        }

        await WarmAsync(scope, _sessionId.Value, accessContext.DataVersion, stoppingToken);
        _warmedDataVersion = accessContext.DataVersion;
    }

    // same checks as AuthController.Login, except failed attempts are not recorded
    private async Task<long?> LogInAsync(SecurityRepository securityRepository, CancellationToken stoppingToken)
    {
        LoginInfo? loginInfo = await securityRepository.GetLoginInfoAsync(_username, stoppingToken);
        if (loginInfo is null || loginInfo.IsLocked)
        {
            logger.LogWarning("Cache warmer cannot log in: user {Username} not found or locked", _username);
            return null;
        }

        PasswordVerificationResult verification =
            passwordHasher.VerifyHashedPassword(new object(), loginInfo.PasswordHash, _password);

        if (verification == PasswordVerificationResult.Failed)
        {
            logger.LogWarning("Cache warmer cannot log in: wrong password for {Username}", _username);
            return null;
        }

        RefreshToken refreshToken = tokenService.CreateRefreshToken();
        long sessionId = await securityRepository.CreateSessionAsync(
            loginInfo.UserId,
            refreshToken.TokenHash,
            refreshToken.ExpiresAt,
            null,
            WarmerUserAgent,
            stoppingToken);

        logger.LogInformation("Cache warmer logged in as {Username}, session {SessionId}", _username, sessionId);
        return sessionId;
    }

    private async Task WarmAsync(IServiceScope scope, long sessionId, long dataVersion, CancellationToken stoppingToken)
    {
        QueryCache queryCache = scope.ServiceProvider.GetRequiredService<QueryCache>();
        DashboardRepository dashboardRepository = scope.ServiceProvider.GetRequiredService<DashboardRepository>();
        WarmStats stats = new WarmStats();
        Stopwatch stopwatch = Stopwatch.StartNew();

        IReadOnlyList<TaxonChildCount> rootChildren = await WarmTaxonAsync(
            queryCache, dashboardRepository, sessionId, _rootTaxonId, stats, stoppingToken);

        foreach (TaxonChildCount child in rootChildren)
        {
            (int childTaxonId, _, _, _, _, _) = child;
            await WarmTaxonAsync(queryCache, dashboardRepository, sessionId, childTaxonId, stats, stoppingToken);
        }

        logger.LogInformation("Cache warmer: data version {DataVersion}, {QueryCount} queries, {LoadedCount} loaded from sql, {ElapsedMs} ms"
            , dataVersion
            , stats.QueryCount
            , stats.LoadedCount
            , stopwatch.ElapsedMilliseconds);
    }

    // the same two cached queries the explorer page asks for when it opens a taxon
    private static async Task<IReadOnlyList<TaxonChildCount>> WarmTaxonAsync(
        QueryCache queryCache,
        DashboardRepository dashboardRepository,
        long sessionId,
        int taxonId,
        WarmStats stats,
        CancellationToken stoppingToken)
    {
        string queryArguments = taxonId.ToString();

        CachedResult<IReadOnlyList<TaxonChildCount>> children = await queryCache.GetOrLoadAsync(
            sessionId,
            DashboardViewPermission,
            TaxonChildrenQueryName,
            queryArguments,
            null,
            (CancellationToken loadCancellationToken) => dashboardRepository.GetTaxonChildrenCountsAsync(
                sessionId, taxonId, null, loadCancellationToken),
            stoppingToken);

        CachedResult<IReadOnlyList<ObservationMonthCount>> monthCounts = await queryCache.GetOrLoadAsync(
            sessionId,
            DashboardViewPermission,
            ObservationsByMonthQueryName,
            queryArguments,
            null,
            (CancellationToken loadCancellationToken) => dashboardRepository.GetObservationsByMonthAsync(
                sessionId, taxonId, null, loadCancellationToken),
            stoppingToken);

        stats.QueryCount = stats.QueryCount + 2;
        if (children.WasCached == false)
        {
            stats.LoadedCount = stats.LoadedCount + 1;
        }
        if (monthCounts.WasCached == false)
        {
            stats.LoadedCount = stats.LoadedCount + 1;
        }

        return children.Value;
    }

    private sealed class WarmStats
    {
        public int QueryCount { get; set; }
        public int LoadedCount { get; set; }
    }
}