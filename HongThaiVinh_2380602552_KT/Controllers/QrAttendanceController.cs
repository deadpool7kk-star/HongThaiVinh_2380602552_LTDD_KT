using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;
using HongThaiVinh_2380602552_KT.Data;
using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    public class QrAttendanceRequest
    {
        [Required]
        [StringLength(100)]
        public string QrCode { get; set; } = string.Empty;

        public bool CheckOut { get; set; }
    }

    [ApiController]
    [Route("api/QrAttendance")]
    [Authorize]
    public class QrAttendanceController : ControllerBase
    {
        private const string CacheKey = "Attendance:ActiveQr";

        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IMemoryCache _cache;

        private sealed record ActiveQr(
            byte[] Hash,
            DateTimeOffset ExpiresAtUtc
        );

        public QrAttendanceController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            IMemoryCache cache)
        {
            _context = context;
            _userManager = userManager;
            _cache = cache;
        }

        private async Task<ApplicationUser?> GetActiveUser()
        {
            var user = await _userManager.GetUserAsync(User);

            if (user == null ||
                !user.IsActive ||
                await _userManager.IsLockedOutAsync(user))
            {
                return null;
            }

            return user;
        }

        // Admin tạo QR mới.
        [Authorize(Roles = "Admin")]
        [HttpPost("generate")]
        public async Task<IActionResult> Generate()
        {
            if (await GetActiveUser() == null)
            {
                return Unauthorized();
            }

            var token = Convert.ToHexString(
                RandomNumberGenerator.GetBytes(32)
            );

            var qrText = $"HTV-KT:{token}";
            var expires = DateTimeOffset.UtcNow.AddMinutes(5);

            var hash = SHA256.HashData(
                Encoding.UTF8.GetBytes(qrText)
            );

            _cache.Set(
                CacheKey,
                new ActiveQr(hash, expires),
                expires
            );

            return Ok(new
            {
                success = true,
                data = new
                {
                    qrText,
                    expiresAtUtc = expires
                }
            });
        }

        // Nhân viên gửi mã vừa quét để chấm công.
        [Authorize(Roles = "Employee")]
        [HttpPost("scan")]
        public async Task<IActionResult> Scan(
            [FromBody] QrAttendanceRequest request)
        {
            var user = await GetActiveUser();

            if (user == null)
            {
                return Unauthorized();
            }

            if (!_cache.TryGetValue<ActiveQr>(
                    CacheKey,
                    out var activeQr) ||
                activeQr == null ||
                activeQr.ExpiresAtUtc <= DateTimeOffset.UtcNow)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "QR đã hết hạn hoặc chưa được tạo. "
                        + "Hãy nhờ Admin tạo mã mới."
                });
            }

            var receivedHash = SHA256.HashData(
                Encoding.UTF8.GetBytes(request.QrCode.Trim())
            );

            if (!CryptographicOperations.FixedTimeEquals(
                receivedHash,
                activeQr.Hash))
            {
                return BadRequest(new
                {
                    success = false,
                    message = "QR không hợp lệ hoặc đã được thay bằng mã mới."
                });
            }

            var now = DateTimeOffset.UtcNow;

            var today = DateOnly.FromDateTime(
                now.ToOffset(TimeSpan.FromHours(7)).DateTime
            );

            if (request.CheckOut)
            {
                var updated = await _context.AttendanceRecords
                    .Where(item =>
                        item.UserId == user.Id &&
                        item.WorkDate == today &&
                        item.CheckOutUtc == null &&
                        item.CheckInUtc <= now
                    )
                    .ExecuteUpdateAsync(setters =>
                        setters.SetProperty(
                            item => item.CheckOutUtc,
                            (DateTimeOffset?)now
                        )
                    );

                if (updated != 1)
                {
                    return Conflict(new
                    {
                        success = false,
                        message = "Bạn chưa chấm công vào hôm nay "
                            + "hoặc đã chấm công ra."
                    });
                }

                return Ok(new
                {
                    success = true,
                    message = "Chấm công ra bằng QR thành công."
                });
            }

            var record = new AttendanceRecord
            {
                UserId = user.Id,
                WorkDate = today,
                CheckInUtc = now
            };

            _context.AttendanceRecords.Add(record);

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
                when (ex.InnerException is SqlException sql &&
                    (sql.Number == 2601 || sql.Number == 2627))
            {
                return Conflict(new
                {
                    success = false,
                    message = "Bạn đã chấm công vào hôm nay."
                });
            }

            return Ok(new
            {
                success = true,
                message = "Chấm công vào bằng QR thành công."
            });
        }
    }
}