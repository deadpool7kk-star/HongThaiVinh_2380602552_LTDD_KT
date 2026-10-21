using HongThaiVinh_2380602552_KT.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    [Route("api/email-test")]
    [ApiController]
    public class EmailTestController : ControllerBase
    {
        private readonly EmailService _emailService;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<EmailTestController> _logger;

        public EmailTestController(
            EmailService emailService,
            IConfiguration configuration,
            IWebHostEnvironment environment,
            ILogger<EmailTestController> logger)
        {
            _emailService = emailService;
            _configuration = configuration;
            _environment = environment;
            _logger = logger;
        }

        [AllowAnonymous]
        [HttpPost("send")]
        public async Task<IActionResult> SendTestEmail()
        {
            // API thử chỉ hoạt động trong môi trường Development.
            if (!_environment.IsDevelopment())
            {
                return NotFound();
            }

            var recipient =
                _configuration["MailSettings:TestRecipient"];

            if (string.IsNullOrWhiteSpace(recipient))
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Chưa cấu hình TestRecipient."
                });
            }

            try
            {
                await _emailService.SendAsync(
                    recipient,
                    "Kiểm tra gửi email - Ứng dụng chấm công",
                    "Đây là email kiểm tra từ ứng dụng chấm công "
                    + "HongThaiVinh_2380602552_KT.\n\n"
                    + "Nếu bạn nhận được thư này, "
                    + "chức năng gửi email đã hoạt động.\n\n"
                    + "Email này chưa chứa mã OTP đăng nhập."
                );

                return Ok(new
                {
                    success = true,
                    message = "Đã gửi email thử qua SMTP."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Không gửi được email kiểm tra."
                );

                return StatusCode(500, new
                {
                    success = false,
                    message = "Không gửi được email. "
                        + "Xem Output trong Visual Studio."
                });
            }
        }
    }
}