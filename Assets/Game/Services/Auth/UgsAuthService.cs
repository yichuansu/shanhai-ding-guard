using System;
using System.Threading;
using System.Threading.Tasks;
using ShanhaiDingGuard.Services.Ugs;
using Unity.Services.Authentication;
using Unity.Services.Core;
using UnityEngine;

namespace ShanhaiDingGuard.Services.Auth
{
    /// <summary>
    /// UGS Anonymous / Guest。SignInGuestAsync 调用 SignInAnonymouslyAsync。
    /// 本机已有 session token 时，SDK 会恢复同一个 PlayerId，而不是新建账号。
    /// Apple / Google 与 LinkAccount 仍是 POST-MVP / M2+，这里不调用对应 SDK。
    /// </summary>
    public sealed class UgsAuthService : IAuthService
    {
        private readonly UgsConfig _config;

        public UgsAuthService(UgsConfig config)
        {
            _config = config;
        }

        public AuthSession Current { get; private set; } = AuthSession.SignedOut;

        public async Task<AuthResult> SignInGuestAsync(CancellationToken cancellationToken)
        {
            try
            {
                var setupError = await UgsSession.EnsureReadyAsync(_config, cancellationToken);
                if (setupError != null)
                {
                    Current = AuthSession.SignedOut;
                    return AuthResult.Unavailable(setupError);
                }

                var auth = AuthenticationService.Instance;
                if (!auth.IsSignedIn || auth.IsExpired)
                {
                    await auth.SignInAnonymouslyAsync();
                }

                cancellationToken.ThrowIfCancellationRequested();
                var playerId = auth.PlayerId;
                if (string.IsNullOrEmpty(playerId))
                {
                    Current = AuthSession.SignedOut;
                    return AuthResult.Failed("匿名登录没有返回 PlayerId。");
                }

                Current = new AuthSession(playerId);
                return AuthResult.SignedIn(Current);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (RequestFailedException exception)
            {
                Current = AuthSession.SignedOut;
                return AuthResult.Failed("游客登录失败：" + exception.Message);
            }
            catch (ServicesInitializationException exception)
            {
                Current = AuthSession.SignedOut;
                return AuthResult.Unavailable("Unity Services 不可用：" + exception.Message);
            }
        }

        public Task SignOutAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                if (UnityServices.State == ServicesInitializationState.Initialized)
                {
                    // clearCredentials: false 留下 session token。下次游客登录仍是这个设备账号。
                    AuthenticationService.Instance.SignOut(false);
                }
            }
            catch (ServicesInitializationException exception)
            {
                Debug.LogWarning("[Auth] 登出时 Unity Services 不可用，只清除本地会话：" + exception.Message);
            }

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
