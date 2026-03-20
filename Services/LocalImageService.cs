namespace CloudSoft.Services;

public class LocalImageService : IImageService
{
    public string GetImageUrl(string imageName) => $"/images/{imageName}";
}
