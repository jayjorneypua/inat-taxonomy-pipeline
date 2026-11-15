using System.Text;
using Inat.Api.Data;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;

// helper mode: "dotnet run -- hash-password" prints a password hash for creating a user, then exits
if (args.Length > 0 && args[0] == "hash-password")
{
    Console.Error.Write("Password: ");
    string password = ReadHiddenLine();
    PasswordHasher<object> passwordHasher = new PasswordHasher<object>();
    Console.WriteLine(passwordHasher.HashPassword(new object(), password));
    return;
}

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

TokenService tokenService = new TokenService(builder.Configuration);
builder.Services.AddSingleton(tokenService);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

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

// data access: one connection factory for the whole app, one repository per request
builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<SecurityRepository>();
builder.Services.AddScoped<DashboardRepository>();

WebApplication app = builder.Build();

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