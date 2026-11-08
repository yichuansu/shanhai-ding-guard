using System;
using System.Threading;
using ShanhaiDingGuard.Services.CloudSave;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ShanhaiDingGuard.App
{
    /// <summary>
    /// 启动时走游客登录，再按该玩家 id 读云存档。
    /// 有 Dashboard Project ID 时用 UGS Anonymous 与 Cloud Save，否则用 Dev/Fake。
    /// 切换方式见 docs/UGS_SETUP.md。不调用 Apple / Google Sign-In 或账号绑定（POST-MVP / M2+）。
    /// </summary>
    public sealed class BootEntry : MonoBehaviour
    {
        private async void Start()
        {
            try
            {
                await BootAsync(destroyCancellationToken);
            }
            catch (OperationCanceledException)
            {
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        private static async System.Threading.Tasks.Task BootAsync(CancellationToken cancellationToken)
        {
            GameServices.Configure();
            Debug.Log("[Boot] services=" + GameServices.Mode);
            var auth = await GameServices.Auth.SignInGuestAsync(cancellationToken);
            if (!auth.Session.IsSignedIn)
            {
                Debug.LogWarning("[Boot] 游客登录未完成。云存档不可用，本地缓存不会当作进度。status=" + auth.Status + " " + auth.Error);
                return;
            }

            var loaded = await GameServices.CloudSave.LoadAsync(auth.Session.PlayerId, cancellationToken);
            Debug.Log("[Boot] guest=" + auth.Session.PlayerId + " save=" + loaded.Status + " origin=" + loaded.Origin);
            if (!string.IsNullOrEmpty(loaded.Error))
            {
                Debug.Log("[Boot] " + loaded.Error);
            }

            if (loaded.Status == CloudSaveStatus.Failed || cancellationToken.IsCancellationRequested)
            {
                return;
            }

            SceneManager.LoadScene("Hub");
        }
    }
}
