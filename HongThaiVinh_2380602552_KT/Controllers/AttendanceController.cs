using HongThaiVinh_2380602552_KT.Data;
using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AttendanceController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public AttendanceController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        private static DateOnly VietnamDate(DateTimeOffset time)
        {
            return DateOnly.FromDateTime(
                time.ToOffset(TimeSpan.FromHours(7)).DateTime
            );
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

        // POST: api/Attendance/check-in
        [Authorize(Roles = "Employee")]
        [HttpPost("check-in")]
        public async Task<IActionResult> CheckIn()
        {
            var user = await GetActiveUser();

            if (user == null)
            {
                return Unauthorized();
            }

            var now = DateTimeOffset.UtcNow;
            var today = VietnamDate(now);

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
                message = "Chấm công vào thành công."
            });
        }

        // POST: api/Attendance/check-out
        [Authorize(Roles = "Employee")]
        [HttpPost("check-out")]
        public async Task<IActionResult> CheckOut()
        {
            var user = await GetActiveUser();

            if (user == null)
            {
                return Unauthorized();
            }

            var now = DateTimeOffset.UtcNow;
            var today = VietnamDate(now);

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
                message = "Chấm công ra thành công."
            });
        }

        // GET: api/Attendance/me
        [Authorize(Roles = "Employee")]
        [HttpGet("me")]
        public async Task<IActionResult> GetMine()
        {
            var user = await GetActiveUser();

            if (user == null)
            {
                return Unauthorized();
            }

            var today = VietnamDate(DateTimeOffset.UtcNow);
            var from = today.AddDays(-29);

            var history = await _context.AttendanceRecords
                .AsNoTracking()
                .Where(item =>
                    item.UserId == user.Id &&
                    item.WorkDate >= from &&
                    item.WorkDate <= today
                )
                .OrderByDescending(item => item.WorkDate)
                .Select(item => new
                {
                    id = item.Id,
                    workDate = item.WorkDate,
                    checkInUtc = item.CheckInUtc,
                    checkOutUtc = item.CheckOutUtc
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                data = new
                {
                    workDate = today,
                    today = history.FirstOrDefault(
                        item => item.workDate == today
                    ),
                    history
                }
            });
        }

        // GET: api/Attendance/all
        [Authorize(Roles = "Admin")]
        [HttpGet("all")]
        public async Task<IActionResult> GetAll()
        {
            var user = await GetActiveUser();

            if (user == null)
            {
                return Unauthorized();
            }

            var today = VietnamDate(DateTimeOffset.UtcNow);
            var from = today.AddDays(-29);

            var records = await _context.AttendanceRecords
                .AsNoTracking()
                .Where(item =>
                    item.WorkDate >= from &&
                    item.WorkDate <= today
                )
                .OrderByDescending(item => item.WorkDate)
                .ThenBy(item => item.User.FullName)
                .Select(item => new
                {
                    id = item.Id,
                    userId = item.UserId,
                    fullName = item.User.FullName,
                    username = item.User.UserName,
                    departmentName = item.User.Department == null
                        ? null
                        : item.User.Department.Name,
                    workDate = item.WorkDate,
                    checkInUtc = item.CheckInUtc,
                    checkOutUtc = item.CheckOutUtc
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                data = records
            });
        }
    }
}