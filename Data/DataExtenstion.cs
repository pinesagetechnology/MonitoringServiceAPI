using FileMonitorWorkerService.Data.Repository;
using Microsoft.EntityFrameworkCore;

namespace MonitoringServiceAPI.Data
{
    public static class DataExtenstion
    {
        public static IServiceCollection RegisterDataServices(this IServiceCollection services, IConfiguration configuration)
        {
            var connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("DefaultConnection not found");

            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseSqlite(connectionString);
                options.EnableSensitiveDataLogging(false);
                options.EnableDetailedErrors(true);
            });

            // Register repositories
            services.AddTransient(typeof(IRepository<>), typeof(Repository<>));

            return services;
        }

    }
}
