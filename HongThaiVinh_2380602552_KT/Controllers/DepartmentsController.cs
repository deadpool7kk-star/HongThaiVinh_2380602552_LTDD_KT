using HongThaiVinh_2380602552_KT.Data;
using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = "Admin")]
    public class DepartmentsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public DepartmentsController(ApplicationDbContext context)
        {
            _context = context;
        }

        // GET: api/Departments
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var departments = await _context.Departments
                .AsNoTracking()
                .OrderBy(item => item.Name)
                .ToListAsync();

            return Ok(new
            {
                success = true,
                data = departments
            });
        }

        // GET: api/Departments/1
        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            var department = await _context.Departments
                .AsNoTracking()
                .SingleOrDefaultAsync(item => item.Id == id);

            if (department == null)
            {
                return NotFound(new
                {
                    success = false,
                    message = "Không tìm thấy phòng ban."
                });
            }

            return Ok(new
            {
                success = true,
                data = department
            });
        }

        // POST: api/Departments
        [HttpPost]
        public async Task<IActionResult> Create(
            [FromBody] DepartmentRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Vui lòng nhập tên phòng ban."
                });
            }

            var department = new Department
            {
                Name = request.Name.Trim(),
                Description = request.Description?.Trim()
            };

            _context.Departments.Add(department);
            await _context.SaveChangesAsync();

            return CreatedAtAction(
                nameof(GetById),
                new { id = department.Id },
                new
                {
                    success = true,
                    message = "Thêm phòng ban thành công.",
                    data = department
                }
            );
        }

        // PUT: api/Departments/1
        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(
            int id,
            [FromBody] DepartmentRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Vui lòng nhập tên phòng ban."
                });
            }

            var department = await _context.Departments.FindAsync(id);

            if (department == null)
            {
                return NotFound(new
                {
                    success = false,
                    message = "Không tìm thấy phòng ban."
                });
            }

            department.Name = request.Name.Trim();
            department.Description = request.Description?.Trim();

            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Cập nhật phòng ban thành công.",
                data = department
            });
        }

        // DELETE: api/Departments/1
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var department = await _context.Departments.FindAsync(id);

            if (department == null)
            {
                return NotFound(new
                {
                    success = false,
                    message = "Không tìm thấy phòng ban."
                });
            }

            _context.Departments.Remove(department);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Xóa phòng ban thành công."
            });
        }
    }
}