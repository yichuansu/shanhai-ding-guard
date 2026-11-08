using System.Threading;
using System.Threading.Tasks;

namespace ShanhaiDingGuard.Services.Auth
{
    /// <summary>
    /// UGS Anonymous / Guest（设备）登录桩。不访问网络，也不调用 UGS。
    /// Spike 改为 AuthenticationService.Instance.SignInAnonymouslyAsync()，
    /// 并用返回的 PlayerId 替换 <see cref="DevGuestPlayerId"/>。
    /// Apple / Google Sign-In 与账号绑定为 POST-MVP / M2+，不进 M1 验收。
    /// </summary>
    public sealed class DevAuthService : IAuthService
    {
        public const string DevGuestPlayerId = "dev.guest";

        public AuthSession Current { get; private set; } = AuthSession.SignedOut;

        public Task<AuthResult> SignInGuestAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Current = new AuthSession(DevGuestPlayerId);
            return Task.FromResult(AuthResult.SignedIn(Current));
        }

        public Task SignOutAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Current = AuthSession.SignedOut;
            return Task.CompletedTask;
        }

        public Task<AuthResult> SignInWithAppleAsync(CancellationToken cancellationToken)
        {
            return Unavailable(cancellationToken, "Apple Sign-In 为 POST-MVP / M2+，不进 M1 验收。");
        }

        public Task<AuthResult> SignInWithGoogleAsync(CancellationToken cancellationToken)
        {
            return Unavailable(cancellationToken, "Google Sign-In 为 POST-MVP / M2+，不进 M1 验收。");
        }

        public Task<AuthResult> LinkAccountAsync(ExternalAuthProvider provider, CancellationToken cancellationToken)
        {
            return Unavailable(cancellationToken, "账号绑定（" + provider + "）为 POST-MVP / M2+，不进 M1 验收。");
        }

        private static Task<AuthResult> Unavailable(CancellationToken cancellationToken, string error)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult(AuthResult.Unavailable(error));
        }
    }
}
