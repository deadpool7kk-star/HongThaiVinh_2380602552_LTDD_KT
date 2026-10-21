using HongThaiVinh_2380602552_KT.Data;
using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = "Admin")]
    public class EmployeesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public EmployeesController(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        // GET: api/Employees
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var employeeRole = await _context.Roles
                .AsNoTracking()
                .SingleOrDefaultAsync(role => role.Name == "Employee");

            if (employeeRole == null)
            {
                return Ok(new
                {
                    success = true,
                    data = Array.Empty<object>()
                });
            }

            var employees = await _context.Users
                .AsNoTracking()
                .Where(user =>
                    _context.UserRoles.Any(userRole =>
                        userRole.UserId == user.Id &&
                        userRole.RoleId == employeeRole.Id
                    )
                )
                .OrderBy(user => user.FullName)
                .Select(user => new
                {
                    id = user.Id,
                    fullName = user.FullName,
                    username = user.UserName,
                    email = user.Email,
                    isActive = user.IsActive,
                    departmentId = user.DepartmentId,
                    departmentName = user.Department == null
                        ? null
                        : user.Department.Name
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                data = employees
            });
        }

        // PUT: api/Employees/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(
            string id,
            [FromBody] UpdateEmployeeRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.FullName))
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Vui lòng nhập họ tên."
                });
            }

            var user = await _userManager.FindByIdAsync(id);

            if (user == null ||
                !await _userManager.IsInRoleAsync(user, "Employee"))
            {
                return NotFound(new
                {
                    success = false,
                    message = "Không tìm thấy nhân viên."
                });
            }

            if (request.DepartmentId.HasValue)
            {
                var departmentExists = await _context.Departments
                    .AnyAsync(department =>
                        department.Id == request.DepartmentId.Value
                    );

                if (!departmentExists)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Phòng ban không tồn tại."
                    });
                }
            }

            user.FullName = request.FullName.Trim();
            user.DepartmentId = request.DepartmentId;

            var result = await _userManager.UpdateAsync(user);

            if (!result.Succeeded)
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Không cập nhật được nhân viên.",
                    errors = result.Errors
                        .Select(error => error.Description)
                });
            }

            return Ok(new
            {
                success = true,
                message = "Cập nhật nhân viên thành công."
            });
        }
    }
}