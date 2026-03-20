using CloudSoft.Models;
using CloudSoft.Options;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace CloudSoft.Repositories;

public class MongoDbSubscriberRepository : ISubscriberRepository
{
    private readonly IMongoCollection<Subscriber> _collection;

    public MongoDbSubscriberRepository(IOptions<MongoDbOptions> options)
    {
        var settings = options.Value;
        var client = new MongoClient(settings.ConnectionString);
        var database = client.GetDatabase(settings.DatabaseName);
        _collection = database.GetCollection<Subscriber>(settings.SubscribersCollectionName);
    }

    public async Task<List<Subscriber>> GetAllAsync() =>
        await _collection.Find(_ => true).ToListAsync();

    public async Task AddAsync(Subscriber subscriber) =>
        await _collection.InsertOneAsync(subscriber);

    public async Task DeleteAsync(string email) =>
        await _collection.DeleteOneAsync(s => s.Email == email);

    public async Task<bool> ExistsAsync(string email) =>
        await _collection.Find(s => s.Email == email).AnyAsync();
}
