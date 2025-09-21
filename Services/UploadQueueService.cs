using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.Logging;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public interface IUploadQueueService
    {
        Task<IEnumerable<UploadQueue>> GetPendingUploadsAsync();
        Task<IEnumerable<UploadQueue>> GetFailedUploadsAsync();
        Task<object> GetQueueSummaryAsync();
    }

    public class UploadQueueService : IUploadQueueService
    {
        private readonly ILogger<UploadQueueService> _logger;
        private readonly IRepository<UploadQueue> _repository;
        public UploadQueueService( ILogger<UploadQueueService> logger,
            IRepository<UploadQueue> repository)
        {
            _logger = logger;
            _repository = repository;
        }

        public async Task<IEnumerable<UploadQueue>> GetPendingUploadsAsync()
        {
            var pendingUploads = await _repository.FindAsync(u => u.Status == FileStatus.Pending);

            return pendingUploads.OrderBy(u => u.CreatedAt);
        }

        public async Task<IEnumerable<UploadQueue>> GetFailedUploadsAsync()
        {
            var failedUploads = await _repository.FindAsync(u => u.Status == FileStatus.Failed);

            return failedUploads.OrderByDescending(u => u.LastAttemptAt);
        }

        public async Task<object> GetQueueSummaryAsync()
        {
            var allQueueItem = await _repository.GetAllAsync();

            var summary = allQueueItem.GroupBy(u => u.Status)
                .Select(g => new { Status = g.Key, Count = g.Count() });

            var totalFiles = allQueueItem.Count();

            var result = new
            {
                TotalFiles = totalFiles,
                StatusBreakdown = summary,
                LastUpdated = DateTime.UtcNow
            };

            return result;
        }
    }
}
