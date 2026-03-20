using CloudSoft.Models;

namespace CloudSoft.Services;

public interface INewsletterService
{
    Task<OperationResult> SubscribeAsync(Subscriber subscriber);
    Task<List<Subscriber>> GetSubscribersAsync();
    Task<OperationResult> UnsubscribeAsync(string email);
}
