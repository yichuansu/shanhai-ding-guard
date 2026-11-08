using System;
using System.Threading;
using ShanhaiDingGuard.Services.CloudSave;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ShanhaiDingGuard.App
{
    /// <summary>
    /// 启动时只走 UGS Anonymous / Guest（设备）桩，再按该玩家 id 读云存档桩。
    /// 不调用 Apple / Google Sign-In 或账号绑定（POST-MVP / M2+）。
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
            GameServices.ConfigureStubs();
            var auth = await GameServices.Auth.SignInGuestAsync(cancellationToken);
            if (!auth.Session.IsSignedIn)
            {
                Debug.LogWarning("[Boot] 游客登录未完成。云存档不可用，本地缓存不会当作进度。");
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
