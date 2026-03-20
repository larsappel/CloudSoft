using CloudSoft.Options;
using CloudSoft.Repositories;
using CloudSoft.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

// Options pattern
builder.Services.Configure<MongoDbOptions>(builder.Configuration.GetSection(MongoDbOptions.SectionName));
builder.Services.Configure<AzureBlobOptions>(builder.Configuration.GetSection(AzureBlobOptions.SectionName));

// Feature flag: MongoDB vs InMemory
var useMongo = builder.Configuration.GetValue<bool>("FeatureFlags:UseMongoDB");
if (useMongo)
    builder.Services.AddSingleton<ISubscriberRepository, MongoDbSubscriberRepository>();
else
    builder.Services.AddSingleton<ISubscriberRepository, InMemorySubscriberRepository>();

// Feature flag: Azure Blob vs Local images
var useAzureBlob = builder.Configuration.GetValue<bool>("FeatureFlags:UseAzureBlobStorage");
if (useAzureBlob)
    builder.Services.AddSingleton<IImageService, AzureBlobImageService>();
else
    builder.Services.AddSingleton<IImageService, LocalImageService>();

builder.Services.AddScoped<INewsletterService, NewsletterService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}

app.UseRouting();
app.UseAuthorization();
app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

app.Run();
