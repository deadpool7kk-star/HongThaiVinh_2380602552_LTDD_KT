using HongThaiVinh_2380602552_KT.Models;
using Microsoft.AspNetCore.Identity;

namespace HongThaiVinh_2380602552_KT.Services
{
    public static class AdminAccountSeeder
    {
        public static async Task SeedAsync(
            IServiceProvider services)
        {
            using var scope = services.CreateScope();

            var configuration = scope.ServiceProvider
                .GetRequiredService<IConfiguration>();

            var userManager = scope.ServiceProvider
                .GetRequiredService<UserManager<ApplicationUser>>();

            var roleManager = scope.ServiceProvider
                .GetRequiredService<RoleManager<IdentityRole>>();

            var fullName = configuration["AdminAccount:FullName"];
            var username = configuration["AdminAccount:Username"];
            var email = configuration["AdminAccount:Email"];
            var password = configuration["AdminAccount:Password"];

            if (string.IsNullOrWhiteSpace(fullName) ||
                string.IsNullOrWhiteSpace(username) ||
                string.IsNullOrWhiteSpace(email) ||
                string.IsNullOrWhiteSpace(password))
            {
                throw new InvalidOperationException(
                    "Chưa cấu hình đủ thông tin AdminAccount "
                    + "trong Manage User Secrets."
                );
            }

            fullName = fullName.Trim();
            username = username.Trim();
            email = email.Trim();

            // Tạo vai trò Admin nếu chưa có.
            if (!await roleManager.RoleExistsAsync("Admin"))
            {
                var roleResult = await roleManager.CreateAsync(
                    new IdentityRole("Admin")
                );

                EnsureSucceeded(
                    roleResult,
                    "Không tạo được vai trò Admin"
                );
            }

            var user = await userManager.FindByNameAsync(username);

            if (user == null)
            {
                // Không dùng email đang thuộc tài khoản khác.
                var existingEmail =
                    await userManager.FindByEmailAsync(email);

                if (existingEmail != null)
                {
                    throw new InvalidOperationException(
                        "Email Admin đã thuộc tài khoản khác. "
                        + "Hãy dùng email khác trong AdminAccount."
                    );
                }

                user = new ApplicationUser
                {
                    FullName = fullName,
                    UserName = username,
                    Email = email,
                    IsActive = true
                };

                var createResult = await userManager.CreateAsync(
                    user,
                    password
                );

                EnsureSucceeded(
                    createResult,
                    "Không tạo được tài khoản Admin"
                );
            }
            else
            {
                // Kiểm tra đúng tài khoản đã cấu hình.
                if (!string.Equals(
                    user.Email,
                    email,
                    StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException(
                        "Tên đăng nhập Admin đã tồn tại "
                        + "nhưng có email khác."
                    );
                }

                if (!user.IsActive)
                {
                    throw new InvalidOperationException(
                        "Tài khoản Admin đang bị vô hiệu hóa."
                    );
                }
            }

            // Chạy lại API không tạo trùng tài khoản hoặc vai trò.
            if (!await userManager.IsInRoleAsync(user, "Admin"))
            {
                var assignResult = await userManager.AddToRoleAsync(
                    user,
                    "Admin"
                );

                EnsureSucceeded(
                    assignResult,
                    "Không gán được vai trò Admin"
                );
            }
        }

        private static void EnsureSucceeded(
            IdentityResult result,
            string message)
        {
            if (result.Succeeded)
            {
                return;
            }

            var details = string.Join(
                "; ",
                result.Errors.Select(error => error.Description)
            );

            throw new InvalidOperationException(
                $"{message}: {details}"
            );
        }
    }
}