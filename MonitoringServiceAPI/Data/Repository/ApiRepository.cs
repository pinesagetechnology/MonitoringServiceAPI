using Microsoft.EntityFrameworkCore;
using System.Linq.Expressions;

namespace FileMonitorWorkerService.Data.Repository
{
    public class ApiRepository<T> : IRepository<T> where T : class
    {
        private readonly MonitoringServiceAPI.Data.ApiDbContext _context;
        protected readonly DbSet<T> _dbSet;

        public ApiRepository(MonitoringServiceAPI.Data.ApiDbContext context)
        {
            _context = context;
            _dbSet = _context.Set<T>();
        }

        public async Task<T> AddAsync(T entity)
        {
            await _dbSet.AddAsync(entity);
            await _context.SaveChangesAsync();
            return entity;
        }

        public async Task<int> CountAsync(Expression<Func<T, bool>> predicted)
        {
            return await _dbSet.CountAsync(predicted);
        }

        public async Task<int> CountAsync()
        {
            return await _dbSet.CountAsync();
        }

        public async Task DeleteAsync(T entity)
        {
            _dbSet.Remove(entity);
            await _context.SaveChangesAsync();
        }

        public async Task<IEnumerable<T>> FindAsync(Expression<Func<T, bool>> predicted)
        {
            return await _dbSet.Where(predicted).ToListAsync();
        }

        public async Task<T?> GetByKeyAsync<TKey>(TKey key) where TKey : notnull
        {
            return await _dbSet.FindAsync(key);
        }

        public async Task<IEnumerable<T>> GetAllAsync()
        {
            return await _dbSet.ToListAsync();
        }

        public async Task<T?> GetByIdAsync(int id)
        {
            return await _dbSet.FindAsync(id);
        }

        public async Task UpdateAsync(T entity)
        {
            _dbSet.Update(entity);
            await _context.SaveChangesAsync();
        }
    }
}


