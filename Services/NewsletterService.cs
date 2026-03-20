using CloudSoft.Models;
using CloudSoft.Repositories;

namespace CloudSoft.Services;

public class NewsletterService : INewsletterService
{
    private readonly ISubscriberRepository _repository;

    public NewsletterService(ISubscriberRepository repository)
    {
        _repository = repository;
    }

    public async Task<OperationResult> SubscribeAsync(Subscriber subscriber)
    {
        if (await _repository.ExistsAsync(subscriber.Email!))
            return OperationResult.Failure($"{subscriber.Email} is already subscribed.");

        await _repository.AddAsync(subscriber);
        return OperationResult.Success($"Thank you for subscribing, {subscriber.Name}!");
    }

    public async Task<List<Subscriber>> GetSubscribersAsync() =>
        await _repository.GetAllAsync();

    public async Task<OperationResult> UnsubscribeAsync(string email)
    {
        if (!await _repository.ExistsAsync(email))
            return OperationResult.Failure("Subscriber not found.");

        await _repository.DeleteAsync(email);
        return OperationResult.Success($"{email} has been unsubscribed.");
    }
}
