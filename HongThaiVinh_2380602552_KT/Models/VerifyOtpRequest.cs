using System.ComponentModel.DataAnnotations;

namespace HongThaiVinh_2380602552_KT.Models
{
    public class VerifyOtpRequest
    {
        public Guid ChallengeId { get; set; }

        [Required]
        [RegularExpression(
            @"^[0-9]{6}$",
            ErrorMessage = "OTP phải gồm đúng 6 chữ số."
        )]
        public string Code { get; set; } = string.Empty;
    }
}