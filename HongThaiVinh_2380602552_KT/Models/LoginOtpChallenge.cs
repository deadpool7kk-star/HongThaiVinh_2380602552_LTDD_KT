using System.ComponentModel.DataAnnotations;

namespace HongThaiVinh_2380602552_KT.Models
{
    public class LoginOtpChallenge
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public string UserId { get; set; } = string.Empty;

        [Required]
        [MaxLength(512)]
        public string CodeHash { get; set; } = string.Empty;

        public DateTime CreatedAtUtc { get; set; }

        public DateTime ExpiresAtUtc { get; set; }

        public int FailedAttempts { get; set; }

        public bool IsConsumed { get; set; }
    }
}