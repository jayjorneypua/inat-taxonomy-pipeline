using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Inat.Api.Tests.Integration;

// everything the integration tests need from inat_test_empty:
// the api's own connection (inat_api, read from the api's user secrets) pointed at the test database,
// and a one time setup of test data, done as you through windows authentication
internal static class TestDatabase
{
    public const string DatabaseName = "inat_test_empty";
    public const string AdminUsername = "it.admin";
    public const string ViewerUsername = "it.viewer";
    public const string AdminPassword = "Integration-Admin-Password-1!";
    public const string ViewerPassword = "Integration-Viewer-Password-1!";

    // the UserSecretsId from api\Inat.Api\Inat.Api.csproj
    private const string ApiUserSecretsId = "5e0c6628-7134-4ce1-bd18-e4ff55b9a210";

    private const string AdminConnectionString =
        "Server=.;Database=inat_test_empty;Integrated Security=True;Encrypt=True;TrustServerCertificate=True";

    // same login and permissions as the real api, only the database differs
    public static IConfiguration CreateApiConfiguration()
    {
        IConfiguration secrets = new ConfigurationBuilder().AddUserSecrets(ApiUserSecretsId).Build();
        string? apiConnectionString = secrets.GetConnectionString("Inat");

        if (apiConnectionString == null)
        {
            throw new InvalidOperationException("ConnectionStrings:Inat is missing from the api's user secrets.");
        }

        SqlConnectionStringBuilder connectionStringBuilder = new SqlConnectionStringBuilder(apiConnectionString);
        connectionStringBuilder.InitialCatalog = DatabaseName;

        Dictionary<string, string?> settings = new Dictionary<string, string?>
        {
            ["ConnectionStrings:Inat"] = connectionStringBuilder.ConnectionString
        };

        return new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
    }

    // creates the inat_api user in the test database and the test data, skipping whatever already exists
    public static async Task SeedAsync()
    {
        PasswordHasher<object> passwordHasher = new PasswordHasher<object>();

        await using SqlConnection connection = new SqlConnection(AdminConnectionString);
        await connection.OpenAsync();

        await using SqlCommand command = new SqlCommand(SeedSql, connection);
        command.Parameters.AddWithValue("@AdminUsername", AdminUsername);
        command.Parameters.AddWithValue("@ViewerUsername", ViewerUsername);
        command.Parameters.AddWithValue("@AdminPasswordHash", passwordHasher.HashPassword(new object(), AdminPassword));
        command.Parameters.AddWithValue("@ViewerPasswordHash", passwordHasher.HashPassword(new object(), ViewerPassword));

        await command.ExecuteNonQueryAsync();
    }

    // a tiny world: Life > Animalia > Amphibia, and Plantae. 3 amphibian observations with photos,
    // 1 plant observation. an admin who sees everything, a viewer who only sees Amphibia
    private const string SeedSql = """
        SET NOCOUNT ON;

        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'inat_api') BEGIN
            CREATE USER [inat_api] FOR LOGIN [inat_api];
        END

        IF IS_ROLEMEMBER(N'app_api', N'inat_api') = 0 BEGIN
            ALTER ROLE [app_api] ADD MEMBER [inat_api];
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Taxon WHERE ID = 48460) BEGIN
            INSERT INTO dbo.Taxon (ID, ID_Parent, ScientificName, CommonName, Rank, Path, Level, HasChildren, IsInTree)
            VALUES
                (48460, NULL,  N'Life',     N'Life',       N'stateofmatter', '48460',         1, 1, 1)
              , (1,     48460, N'Animalia', N'Animals',    N'kingdom',       '48460,1',       2, 1, 1)
              , (47126, 48460, N'Plantae',  N'Plants',     N'kingdom',       '48460,47126',   2, 0, 1)
              , (20978, 1,     N'Amphibia', N'Amphibians', N'class',         '48460,1,20978', 3, 0, 1);
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Observer WHERE ID = 900001) BEGIN
            INSERT INTO dbo.Observer (ID, Login, Name, DisplayName)
            VALUES (900001, N'it.observer', N'Integration Observer', N'Integration Observer');

            INSERT INTO dbo.Photo (ID, ID_Observer, License, Extension, SquareUrl, MediumUrl, Attribution)
            VALUES
                (900000001, 900001, 'CC-BY', 'jpg', 'https://example.com/1/square.jpg', 'https://example.com/1/medium.jpg', N'(c) Integration Observer')
              , (900000002, 900001, 'CC-BY', 'jpg', 'https://example.com/2/square.jpg', 'https://example.com/2/medium.jpg', N'(c) Integration Observer')
              , (900000003, 900001, 'CC-BY', 'jpg', 'https://example.com/3/square.jpg', 'https://example.com/3/medium.jpg', N'(c) Integration Observer');

            INSERT INTO dbo.Observation (ObservationUuid, ID_Taxon, ID_Observer, ObservedDate, PhotoCount, Source)
            VALUES
                (NEWID(), 20978, 900001, '2026-01-10', 1, 'dump')
              , (NEWID(), 20978, 900001, '2026-01-11', 1, 'dump')
              , (NEWID(), 20978, 900001, '2026-01-12', 1, 'dump')
              , (NEWID(), 47126, 900001, '2026-01-13', 0, 'dump');

            INSERT INTO dbo.Observation_Photo (ID_Observation, ID_Photo, PhotoPosition)
            SELECT
                observations.ID
              , 900000000 + ROW_NUMBER() OVER (ORDER BY observations.ObservedDate)
              , 0
            FROM
                dbo.Observation observations
            WHERE
                observations.ID_Taxon = 20978;
        END

        IF NOT EXISTS (SELECT 1 FROM security.[User] WHERE Username = @AdminUsername) BEGIN
            INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, HasChangedPassword, ID_CreatedBy)
            VALUES (N'Integration', N'Admin', @AdminUsername, N'it.admin@example.com', @AdminPasswordHash, 1, 1);

            DECLARE @AdminID INT = SCOPE_IDENTITY();

            INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy)
            SELECT @AdminID, roles.ID, 1 FROM security.Role roles WHERE roles.Name = N'Administrator';

            INSERT INTO security.User_TaxonScope (ID_User, ID_Taxon, ID_CreatedBy) VALUES (@AdminID, 48460, 1);
        END

        IF NOT EXISTS (SELECT 1 FROM security.[User] WHERE Username = @ViewerUsername) BEGIN
            INSERT INTO security.[User] (FirstName, LastName, Username, Email, PasswordHash, HasChangedPassword, ID_CreatedBy)
            VALUES (N'Integration', N'Viewer', @ViewerUsername, N'it.viewer@example.com', @ViewerPasswordHash, 1, 1);

            DECLARE @ViewerID INT = SCOPE_IDENTITY();

            INSERT INTO security.User_Role (ID_User, ID_Role, ID_CreatedBy)
            SELECT @ViewerID, roles.ID, 1 FROM security.Role roles WHERE roles.Name = N'Viewer';

            INSERT INTO security.User_TaxonScope (ID_User, ID_Taxon, ID_CreatedBy) VALUES (@ViewerID, 20978, 1);
        END
        """;
}