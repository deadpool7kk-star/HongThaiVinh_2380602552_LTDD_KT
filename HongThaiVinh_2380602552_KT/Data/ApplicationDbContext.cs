using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace HongThaiVinh_2380602552_KT.Data
{
    public class ApplicationDbContext
        : IdentityDbContext<ApplicationUser>
    {
        public ApplicationDbContext(
            DbContextOptions<ApplicationDbContext> options
        ) : base(options)
        {
        }

        public DbSet<LoginOtpChallenge> LoginOtpChallenges { get; set; } = null!;
        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            builder.Entity<ApplicationUser>()
                .HasOne(user => user.Department)
                .WithMany()
                .HasForeignKey(user => user.DepartmentId)
                .OnDelete(DeleteBehavior.SetNull);

            builder.Entity<ApplicationUser>()
                .Property(user => user.FullName)
                .HasMaxLength(100)
                .IsRequired();
            builder.Entity<LoginOtpChallenge>()
                .HasOne<ApplicationUser>()
                .WithMany()
                .HasForeignKey(challenge => challenge.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            builder.Entity<AttendanceRecord>()
                .HasIndex(item => new { item.UserId, item.WorkDate })
                .IsUnique();

            builder.Entity<AttendanceRecord>()
                .HasOne(item => item.User)
                .WithMany()
                .HasForeignKey(item => item.UserId)
                .OnDelete(DeleteBehavior.Restrict);
            builder.Entity<LoginOtpChallenge>()
                .HasIndex(challenge => new
                {
                    challenge.UserId,
                    challenge.CreatedAtUtc
                });
        }
        public DbSet<Department> Departments { get; set; }
        public DbSet<AttendanceRecord> AttendanceRecords { get; set; }
    }
}