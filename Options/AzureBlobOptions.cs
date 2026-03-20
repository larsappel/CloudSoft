namespace CloudSoft.Options;

public class AzureBlobOptions
{
    public const string SectionName = "AzureBlob";
    public string AccountName { get; set; } = string.Empty;
    public string AccountKey { get; set; } = string.Empty;
    public string ContainerName { get; set; } = "images";
}
