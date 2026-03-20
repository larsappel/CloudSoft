using System.Collections.Concurrent;
using CloudSoft.Models;

namespace CloudSoft.Repositories;

public class InMemorySubscriberRepository : ISubscriberRepository
{
    private readonly ConcurrentDictionary<string, Subscriber> _subscribers = new();

    public Task<List<Subscriber>> GetAllAsync() =>
        Task.FromResult(_subscribers.Values.ToList());

    public Task AddAsync(Subscriber subscriber)
    {
        _subscribers[subscriber.Email!] = subscriber;
        return Task.CompletedTask;
    }

    public Task DeleteAsync(string email)
    {
        _subscribers.TryRemove(email, out _);
        return Task.CompletedTask;
    }

    public Task<bool> ExistsAsync(string email) =>
        Task.FromResult(_subscribers.ContainsKey(email));
}
