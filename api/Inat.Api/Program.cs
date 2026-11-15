using System.Text;
using Inat.Api.Data;
using Inat.Api.Infrastructure;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;

// helper mode: prints a password hash for creating a user, then exits.
//   dotnet run -- hash-password              asks for the password without showing it
//   dotnet run -- hash-password <password>   for scripts, with a known test password only
if (args.Length > 0 && args[0] == "hash-password")
{
    string password;
    if (args.Length > 1)
    {
        password = args[1];
    }
    else
    {
        Console.Error.Write("Password: ");
        password = ReadHiddenLine();
    }

    PasswordHasher<object> passwordHasher = new PasswordHasher<object>();
    Console.WriteLine(passwordHasher.HashPassword(new object(), password));
    return;
}

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

TokenService tokenService = new TokenService(builder.Configuration);
builder.Services.AddSingleton(tokenService);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

// one place that turns errors into 400, 401, 403 or a generic 500
builder.Services.AddExceptionHandler<DatabaseExceptionHandler>();
builder.Services.AddProblemDetails();

// every request with "Authorization: Bearer <token>" is checked: signature, issuer, audience, expiry
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = tokenService.Issuer,
            ValidateAudience = true,
            ValidAudience = tokenService.Audience,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = tokenService.SigningKey,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });
builder.Services.AddAuthorization();

// caching: in memory for now, a distributed cache like redis can be added as a second level later
builder.Services.AddHybridCache();

// data access: one connection factory for the whole app, one repository per request
builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<SecurityRepository>();
builder.Services.AddScoped<AccessRepository>();
builder.Services.AddScoped<DashboardRepository>();
builder.Services.AddScoped<TaxonomyRepository>();
builder.Services.AddScoped<AdminRepository>();
builder.Services.AddScoped<QueryCache>();

WebApplication app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();

// reads a line from the console without showing what is typed
static string ReadHiddenLine()
{
    StringBuilder typedCharacters = new StringBuilder();

    while (true)
    {
        ConsoleKeyInfo keyInfo = Console.ReadKey(intercept: true);

        if (keyInfo.Key == ConsoleKey.Enter)
        {
            Console.Error.WriteLine();
            return typedCharacters.ToString();
        }

        if (keyInfo.Key == ConsoleKey.Backspace)
        {
            if (typedCharacters.Length > 0)
            {
                typedCharacters.Length--;
            }
            continue;
        }

        typedCharacters.Append(keyInfo.KeyChar);
    }
}