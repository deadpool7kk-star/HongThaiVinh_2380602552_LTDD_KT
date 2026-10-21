using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace HongThaiVinh_2380602552_KT.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AccountController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;

        public AccountController(
            UserManager<ApplicationUser> userManager)
        {
            _userManager = userManager;
        }

        // GET: api/Account/me
        [HttpGet("me")]
        public async Task<IActionResult> GetCurrentAccount()
        {
            var user = await _userManager.GetUserAsync(User);

            if (user == null ||
                !user.IsActive ||
                await _userManager.IsLockedOutAsync(user))
            {
                return Unauthorized(new
                {
                    success = false,
                    message = "Tài khoản không được phép truy cập."
                });
            }

            var roles = await _userManager.GetRolesAsync(user);

            return Ok(new
            {
                success = true,
                data = new
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