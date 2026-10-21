using System.ComponentModel.DataAnnotations;

namespace HongThaiVinh_2380602552_KT.Models
{
    public class DepartmentRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập tên phòng ban.")]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? Description { get; set; }
    }
}