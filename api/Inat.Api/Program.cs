using Inat.Api.Data;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

// data access: one connection factory for the whole app, one repository per request
builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<DashboardRepository>();

WebApplication app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();