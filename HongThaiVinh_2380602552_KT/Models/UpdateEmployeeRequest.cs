using System.ComponentModel.DataAnnotations;

namespace HongThaiVinh_2380602552_KT.Models
{
    public class UpdateEmployeeRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên.")]
        [MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        public int? DepartmentId { get; set; }
    }
}