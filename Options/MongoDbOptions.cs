namespace CloudSoft.Options;

public class MongoDbOptions
{
    public const string SectionName = "MongoDb";
    public string ConnectionString { get; set; } = string.Empty;
    public string DatabaseName { get; set; } = "cloudsoft";
    public string SubscribersCollectionName { get; set; } = "subscribers";
}
