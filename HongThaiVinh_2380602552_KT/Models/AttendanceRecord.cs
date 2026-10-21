using System.ComponentModel.DataAnnotations;

namespace HongThaiVinh_2380602552_KT.Models
{
    public class AttendanceRecord
    {
        public int Id { get; set; }

        [Required]
        public string UserId { get; set; } = string.Empty;

        public ApplicationUser User { get; set; } = null!;

        public DateOnly WorkDate { get; set; }

        public DateTimeOffset CheckInUtc { get; set; }

        public DateTimeOffset? CheckOutUtc { get; set; }
    }
}