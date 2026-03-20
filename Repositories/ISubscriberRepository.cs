using CloudSoft.Models;

namespace CloudSoft.Repositories;

public interface ISubscriberRepository
{
    Task<List<Subscriber>> GetAllAsync();
    Task AddAsync(Subscriber subscriber);
    Task DeleteAsync(string email);
    Task<bool> ExistsAsync(string email);
}
