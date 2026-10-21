using HongThaiVinh_2380602552_KT.Services;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using HongThaiVinh_2380602552_KT.Data;
using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ApplicationDbContext _context;

        public AuthController(
            UserManager<ApplicationUser> userManager,
            ApplicationDbContext context)
        {
            _userManager = userManager;
            _context = context;
        }

        // POST: api/Auth/register
        [AllowAnonymous]
        [HttpPost("register")]
        public async Task<IActionResult> Register(
            [FromBody] RegisterRequest request)
        {
            var fullName = request.FullName.Trim();
            var username = request.Username.Trim();
            var email = request.Email.Trim();

            // Kiểm tra tên đăng nhập.
            var existingUsername =
                await _userManager.FindByNameAsync(username);

            if (existingUsername != null)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Tên đăng nhập đã tồn tại."
                });
            }

            // Kiểm tra email.
            var existingEmail =
                await _userManager.FindByEmailAsync(email);

            if (existingEmail != null)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Email đã được đăng ký."
                });
            }

            var user = new ApplicationUser
            {
                FullName = fullName,
                UserName = username,
                Email = email,
                IsActive = true
            };

            // Chỉ lưu đăng ký khi cả tạo tài khoản
            // và gán vai trò đều thành công.
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            var createResult = await _userManager.CreateAsync(
                user,
                request.Password
            );

            if (!createResult.Succeeded)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Đăng ký không thành công.",
                    errors = createResult.Errors
                        .Select(error => error.Description)
                });
            }

            // Người đăng ký mới luôn là nhân viên.
            var roleResult = await _userManager.AddToRoleAsync(
                user,
                "Employee"
            );

            if (!roleResult.Succeeded)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = "Không thể hoàn tất đăng ký tài khoản."
                });
            }

            await transaction.CommitAsync();

            return StatusCode(201, new
            {
                success = true,
                message = "Đăng ký tài khoản nhân viên thành công.",
                data = new
                {
                    user.Id,
                    user.FullName,
                    username = user.UserName,
                    user.Email,
                    role = "Employee"
                }
            });
        }
        // POST: api/Auth/login
        [AllowAnonymous]
        [HttpPost("login")]
        public async Task<IActionResult> Login(
            [FromBody] LoginRequest request,
            [FromServices] EmailService emailService,
            [FromServices] ILogger<AuthController> logger)
        {
            var username = request.Username.Trim();

            var user = await _userManager.FindByNameAsync(username);

            if (user == null || !user.IsActive)
            {
                return Unauthorized(new
                {
                    success = false,
                    message = "Tên đăng nhập hoặc mật khẩu không đúng."
                });
            }

            // Kiểm tra tài khoản bị khóa do nhập sai nhiều lần.
            if (await _userManager.IsLockedOutAsync(user))
            {
                return Unauthorized(new
                {
                    success = false,
                    message = "Tài khoản đang bị khóa tạm thời. "
                        + "Vui lòng thử lại sau."
                });
            }

            var passwordValid = await _userManager.CheckPasswordAsync(
                user,
                request.Password
            );

            if (!passwordValid)
            {
                await _userManager.AccessFailedAsync(user);

                return Unauthorized(new
                {
                    success = false,
                    message = "Tên đăng nhập hoặc mật khẩu không đúng."
                });
            }

            await _userManager.ResetAccessFailedCountAsync(user);

            if (string.IsNullOrWhiteSpace(user.Email))
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Tài khoản chưa có email nhận OTP."
                });
            }

            var now = DateTime.UtcNow;

            // Hạn chế bấm gửi mã liên tiếp.
            var recentlyCreated = await _context.LoginOtpChallenges
                .AnyAsync(challenge =>
                    challenge.UserId == user.Id &&
                    challenge.CreatedAtUtc > now.AddSeconds(-60)
                );

            if (recentlyCreated)
            {
                return StatusCode(429, new
                {
                    success = false,
                    message = "Vui lòng đợi 60 giây từ lần gửi mã trước "
                        + "rồi thử lại."
                });
            }

            // Hủy các phiên OTP cũ chưa sử dụng của tài khoản.
            await _context.LoginOtpChallenges
                .Where(challenge =>
                    challenge.UserId == user.Id &&
                    !challenge.IsConsumed
                )
                .ExecuteUpdateAsync(setters =>
                    setters.SetProperty(
                        challenge => challenge.IsConsumed,
                        true
                    )
                );

            // Tạo OTP gồm 6 chữ số.
            var otp = RandomNumberGenerator
                .GetInt32(0, 1000000)
                .ToString("D6");

            var challenge = new LoginOtpChallenge
            {
                UserId = user.Id,
                CreatedAtUtc = now,
                ExpiresAtUtc = now.AddMinutes(5),
                FailedAttempts = 0,
                IsConsumed = false
            };

            // Lưu bản băm, không lưu OTP gốc.
            var hasher = new PasswordHasher<LoginOtpChallenge>();

            challenge.CodeHash = hasher.HashPassword(
                challenge,
                otp
            );

            _context.LoginOtpChallenges.Add(challenge);
            await _context.SaveChangesAsync();

            try
            {
                await emailService.SendAsync(
                    user.Email,
                    "Mã OTP đăng nhập ứng dụng chấm công",
                    $"Xin chào {user.FullName},\n\n"
                        + $"Mã OTP đăng nhập của bạn là: {otp}\n\n"
                        + "Mã có hiệu lực trong 5 phút.\n"
                        + "Chỉ sử dụng mã mới nhất và không chia sẻ mã này."
                );
            }
            catch (Exception ex)
            {
                // Không giữ phiên OTP nếu việc gửi mail thất bại.
                _context.LoginOtpChallenges.Remove(challenge);
                await _context.SaveChangesAsync();

                logger.LogError(
                    ex,
                    "Không gửi được email OTP đăng nhập."
                );

                return StatusCode(500, new
                {
                    success = false,
                    message = "Không gửi được OTP. Vui lòng thử lại sau."
                });
            }

            return Ok(new
            {
                success = true,
                requiresOtp = true,
                message = "Đã gửi OTP tới email đã đăng ký.",
                challengeId = challenge.Id,
                expiresAtUtc = challenge.ExpiresAtUtc
            });
        }
        // POST: api/Auth/verify-otp
        [AllowAnonymous]
        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp(
            [FromBody] VerifyOtpRequest request,
            [FromServices] JwtService jwtService)
        {
            var now = DateTime.UtcNow;

            // Ghi nhận một lượt thử trước khi kiểm tra mã.
            // Giữ tên FailedAttempts từ model trước,
            // nhưng ở đây dùng để giới hạn tổng cộng 5 lượt kiểm tra.
            var reserved = await _context.LoginOtpChallenges
                .Where(challenge =>
                    challenge.Id == request.ChallengeId &&
                    !challenge.IsConsumed &&
                    challenge.ExpiresAtUtc > now &&
                    challenge.FailedAttempts < 5
                )
                .ExecuteUpdateAsync(setters =>
                    setters.SetProperty(
                        challenge => challenge.FailedAttempts,
                        challenge => challenge.FailedAttempts + 1
                    )
                );

            if (reserved != 1)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Phiên OTP không tồn tại, đã hết hạn, "
                        + "đã sử dụng hoặc đã vượt quá 5 lần thử. "
                        + "Vui lòng đăng nhập để nhận mã mới."
                });
            }

            var challenge = await _context.LoginOtpChallenges
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.Id == request.ChallengeId
                );

            if (challenge == null || challenge.IsConsumed)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Phiên OTP không còn hợp lệ."
                });
            }

            var hasher = new PasswordHasher<LoginOtpChallenge>();

            var verification = hasher.VerifyHashedPassword(
                challenge,
                challenge.CodeHash,
                request.Code
            );

            if (verification == PasswordVerificationResult.Failed)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "OTP không đúng. "
                        + "Mỗi phiên chỉ được kiểm tra tối đa 5 lần."
                });
            }

            var user = await _userManager.FindByIdAsync(
                challenge.UserId
            );

            if (user == null ||
                !user.IsActive ||
                await _userManager.IsLockedOutAsync(user))
            {
                return Unauthorized(new
                {
                    success = false,
                    message = "Tài khoản không được phép đăng nhập."
                });
            }

            var roles = await _userManager.GetRolesAsync(user);

            if (roles.Count == 0)
            {
                return StatusCode(403, new
                {
                    success = false,
                    message = "Tài khoản chưa được gán vai trò."
                });
            }

            var jwt = jwtService.CreateToken(user, roles);

            // Chỉ một yêu cầu được sử dụng phiên OTP thành công.
            var consumedAt = DateTime.UtcNow;

            var consumed = await _context.LoginOtpChallenges
                .Where(item =>
                    item.Id == request.ChallengeId &&
                    !item.IsConsumed &&
                    item.ExpiresAtUtc > consumedAt
                )
                .ExecuteUpdateAsync(setters =>
                    setters.SetProperty(
                        item => item.IsConsumed,
                        true
                    )
                );

            if (consumed != 1)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "OTP đã được sử dụng hoặc đã hết hạn."
                });
            }

            return Ok(new
            {
                success = true,
                message = "Đăng nhập thành công.",
                token = jwt.Token,
                expiresAtUtc = jwt.ExpiresAtUtc,
                user = new
                {
                    user.Id,
                    user.FullName,
                    username = user.UserName,
                    user.Email,
                    roles
                }
            });
        }
    }
}