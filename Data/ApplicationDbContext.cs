using BellwoodAuthServer.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace BellwoodAuthServer.Data
{
    public class ApplicationDbContext : IdentityDbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options) { }

        public DbSet<AuthAuditEvent> AuthAuditEvents => Set<AuthAuditEvent>();

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            builder.Entity<AuthAuditEvent>(entity =>
            {
                entity.ToTable("AuthAuditEvents");
                entity.HasKey(x => x.Id);
                entity.Property(x => x.Action).HasMaxLength(100).IsRequired();
                entity.Property(x => x.Result).HasMaxLength(50).IsRequired();
                entity.Property(x => x.Username).HasMaxLength(256);
                entity.Property(x => x.CorrelationId).HasMaxLength(100);
                entity.Property(x => x.IpAddress).HasMaxLength(64);
                entity.Property(x => x.UserAgent).HasMaxLength(512);
            });
        }
    }
}
