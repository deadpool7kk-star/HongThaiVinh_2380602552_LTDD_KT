using MailKit.Security;
using MimeKit;

namespace HongThaiVinh_2380602552_KT.Services
{
    public class EmailService
    {
        private readonly IConfiguration _configuration;

        public EmailService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task SendAsync(
            string recipient,
            string subject,
            string content)
        {
            var settings =
                _configuration.GetSection("MailSettings");

            var host = settings["Host"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình MailSettings:Host."
                );

            var senderEmail = settings["SenderEmail"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình email gửi."
                );

            var password = settings["Password"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình mật khẩu ứng dụng."
                );

            var senderName = settings["SenderName"]
                ?? "Ứng dụng chấm công";

            var port = settings.GetValue<int>("Port", 587);

            var message = new MimeMessage();

            message.From.Add(
                new MailboxAddress(senderName, senderEmail)
            );

            message.To.Add(
                MailboxAddress.Parse(recipient)
            );

            message.Subject = subject;

            message.Body = new TextPart("plain")
            {
                Text = content
            };

            using var client = new MailKit.Net.Smtp.SmtpClient();

            client.Timeout = 30000;

            await client.ConnectAsync(
                host,
                port,
                SecureSocketOptions.StartTls
            );

            await client.AuthenticateAsync(
                senderEmail,
                password
            );

            await client.SendAsync(message);

            await client.DisconnectAsync(true);
        }
    }
}