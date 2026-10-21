using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations;

namespace HongThaiVinh_2380602552_KT.Models
{
    public class ApplicationUser : IdentityUser
    {
        [Required]
        [MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        public bool IsActive { get; set; } = true;

        public int? DepartmentId { get; set; }

        public Department? Department { get; set; }
    }
}