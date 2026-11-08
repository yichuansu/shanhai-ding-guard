using System.Threading;
using System.Threading.Tasks;

namespace ShanhaiDingGuard.Services.Auth
{
    public enum AuthStatus
    {
        SignedOut = 0,
        SignedIn = 1,
        Failed = 2,
        Unavailable = 3,
    }

    public enum ExternalAuthProvider
    {
        Apple = 0,
        Google = 1,
    }

    public readonly struct AuthSession
    {
        public AuthSession(string playerId)
        {
            PlayerId = playerId ?? string.Empty;
        }

        public string PlayerId { get; }

        public bool IsSignedIn
        {
            get { return PlayerId.Length > 0; }
        }

        public static AuthSession SignedOut
        {
            get { return new AuthSession(string.Empty); }
        }
    }

    public readonly struct AuthResult
    {
        public AuthResult(AuthStatus status, AuthSession session, string error)
        {
            Status = status;
            Session = session;
            Error = error ?? string.Empty;
        }

        public AuthStatus Status { get; }

        public AuthSession Session { get; }

        public string Error { get; }

        public static AuthResult SignedIn(AuthSession session)
        {
            return new AuthResult(AuthStatus.SignedIn, session, string.Empty);
        }

        public static AuthResult Unavailable(string error)
        {
            return new AuthResult(AuthStatus.Unavailable, AuthSession.SignedOut, error);
        }
    }

    /// <summary>
    /// 登录边界。生产实现包 Unity.Services.Authentication.AuthenticationService。
    /// 默认路径是 UGS Anonymous / Guest（设备）登录，对应 SignInAnonymouslyAsync，再交给 Cloud Save。
    /// PlayerId 对应 AuthenticationService.PlayerId，并写入 shdg.save 的 accountId。
    /// 访问令牌留在未来的 UGS 实现内部。接口不暴露 UGS SDK 类型。
    /// PlayFab 仅为应急，MVP 不并行评估，这里不引用。
    /// 首发是海外 / 非大陆 iOS 与 Android，不含中国大陆渠道登录。
    /// </summary>
    public interface IAuthService
    {
        AuthSession Current { get; }

        Task<AuthResult> SignInGuestAsync(CancellationToken cancellationToken);

        Task SignOutAsync(CancellationToken cancellationToken);

        // POST-MVP / M2+。不进 M1 验收。Boot 不调用。
        Task<AuthResult> SignInWithAppleAsync(CancellationToken cancellationToken);

        // POST-MVP / M2+。不进 M1 验收。Boot 不调用。
        Task<AuthResult> SignInWithGoogleAsync(CancellationToken cancellationToken);

        // POST-MVP / M2+。把游客会话绑定到 Apple 或 Google。不进 M1 验收。
        Task<AuthResult> LinkAccountAsync(ExternalAuthProvider provider, CancellationToken cancellationToken);
    }
}
