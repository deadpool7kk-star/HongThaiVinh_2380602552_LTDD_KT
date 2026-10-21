using HongThaiVinh_2380602552_KT.Models;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace HongThaiVinh_2380602552_KT.Services
{
    public class JwtService
    {
        private readonly IConfiguration _configuration;

        public JwtService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public (string Token, DateTime ExpiresAtUtc) CreateToken(
            ApplicationUser user,
            IList<string> roles)
        {
            var settings =
                _configuration.GetSection("JwtSettings");

            var secret = settings["Secret"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình JwtSettings:Secret."
                );

            var now = DateTime.UtcNow;

            var expiresAt = now.AddMinutes(
                settings.GetValue<int>("ExpiryMinutes", 60)
            );

            var claims = new List<Claim>
            {
                new Claim(
                    JwtRegisteredClaimNames.Sub,
                    user.Id
                ),
                new Claim(
                    JwtRegisteredClaimNames.Jti,
                    Guid.NewGuid().ToString()
                ),
                new Claim(
                    ClaimTypes.Name,
                    user.UserName ?? ""
                )
            };

            foreach (var role in roles)
            {
                claims.Add(
                    new Claim(ClaimTypes.Role, role)
                );
            }

            var key = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(secret)
            );

            var token = new JwtSecurityToken(
                issuer: settings["Issuer"],
                audience: settings["Audience"],
                claims: claims,
                notBefore: now,
                expires: expiresAt,
                signingCredentials: new SigningCredentials(
                    key,
                    SecurityAlgorithms.HmacSha256
                )
            );

            return (
                new JwtSecurityTokenHandler().WriteToken(token),
                expiresAt
            );
        }
    }
}