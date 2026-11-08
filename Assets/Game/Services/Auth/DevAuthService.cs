using System.Threading;
using System.Threading.Tasks;

namespace ShanhaiDingGuard.Services.Auth
{
    /// <summary>
    /// 编辑器与离线回退。不访问网络，也不调用 UGS。玩家 id 固定为 <see cref="DevGuestPlayerId"/>。
    /// 有 Dashboard Project ID 且未强制离线时，Boot 改用 UgsAuthService。
    /// 强制回退：UgsConfig.forceOfflineStubs，或脚本定义符号 SHDG_FORCE_DEV_SERVICES。
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
