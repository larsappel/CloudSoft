using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using CloudSoft.Options;
using Microsoft.Extensions.Options;

namespace CloudSoft.Services;

public class AzureBlobImageService : IImageService
{
    private readonly AzureBlobOptions _options;

    public AzureBlobImageService(IOptions<AzureBlobOptions> options)
    {
        _options = options.Value;
    }

    public string GetImageUrl(string imageName)
    {
        var credential = new Azure.Storage.StorageSharedKeyCredential(_options.AccountName, _options.AccountKey);
        var blobClient = new BlobClient(
            new Uri($"https://{_options.AccountName}.blob.core.windows.net/{_options.ContainerName}/{imageName}"),
            credential);

        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = _options.ContainerName,
            BlobName = imageName,
            Resource = "b",
            ExpiresOn = DateTimeOffset.UtcNow.AddHours(1)
        };
        sasBuilder.SetPermissions(BlobSasPermissions.Read);

        var sasUri = blobClient.GenerateSasUri(sasBuilder);
        return sasUri.ToString();
    }
}
