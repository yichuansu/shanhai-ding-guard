using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ShanhaiDingGuard.Services.Ugs;
using Unity.Services.Authentication;
using Unity.Services.CloudSave.Models;
using Unity.Services.Core;

namespace ShanhaiDingGuard.Services.CloudSave
{
    /// <summary>
    /// UGS Cloud Save 玩家数据。键是 <see cref="CloudSaveKeys.PlayerProfile"/>（shdg.save）。
    /// 值是 PlayerProfileJson 的整段文本。读回用 Item.Value.GetAs&lt;string&gt;()，
    /// 不用 GetAsString()（那是带引号的原始 token）。
    /// 没有玩家 id 时不读本地缓存。PlayFab 不在这里实现。
    /// </summary>
    public sealed class UgsCloudSaveService : ICloudSaveService
    {
        private const int MaxProfileBytes = 1024 * 1024;

        private readonly UgsConfig _config;

        public UgsCloudSaveService(UgsConfig config)
        {
            _config = config;
        }

        public async Task<CloudSaveLoadResult> LoadAsync(string playerId, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(playerId))
            {
                return CloudSaveLoadResult.NotSignedIn();
            }

            try
            {
                var problem = await PrepareAsync(playerId, cancellationToken);
                if (problem != null)
                {
                    return problem == "未登录"
                        ? CloudSaveLoadResult.NotSignedIn()
                        : FailedLoad(problem);
                }

                var keys = new HashSet<string> { CloudSaveKeys.PlayerProfile };
                var loaded = await Unity.Services.CloudSave.CloudSaveService.Instance.Data.Player.LoadAsync(keys);
                cancellationToken.ThrowIfCancellationRequested();

                Item item = null;
                if (loaded != null)
                {
                    loaded.TryGetValue(CloudSaveKeys.PlayerProfile, out item);
                }

                if (item == null || item.Value == null)
                {
                    return new CloudSaveLoadResult(
                        CloudSaveStatus.NotFound,
                        CloudSaveOrigin.None,
                        null,
                        "云端没有这份游客档案。");
                }

                string json;
                try
                {
                    json = item.Value.GetAs<string>();
                }
                catch (Exception exception)
                {
                    return FailedLoad("云端档案无法按字符串读取，已保留原文件：" + exception.Message);
                }

                if (json != null && json.Length > MaxProfileBytes)
                {
                    return FailedLoad("档案过大，已保留原文件");
                }

                PlayerProfile profile;
                string error;
                if (!PlayerProfileJson.TryRead(json, out profile, out error))
                {
                    return FailedLoad(error);
                }

                if (profile.AccountId != playerId)
                {
                    return FailedLoad("档案账号与当前游客不一致，已保留原文件");
                }

                return new CloudSaveLoadResult(CloudSaveStatus.Ok, CloudSaveOrigin.Remote, profile, string.Empty);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (RequestFailedException exception)
            {
                return FailedLoad("读取 Cloud Save 失败：" + exception.Message);
            }
            catch (ServicesInitializationException exception)
            {
                return FailedLoad("Unity Services 不可用：" + exception.Message);
            }
        }

        public async Task<CloudSaveWriteResult> SaveAsync(PlayerProfile profile, CancellationToken cancellationToken)
        {
            // OPEN: 多设备同时写入的冲突策略尚未锁定。
            // 临时行为只写在本注释里：SaveAsync(IDictionary<string, object>) 不带 writeLock，
            // 后写覆盖整份 shdg.save。下一次 Load 读到的是服务端当前值，
            // 其 Item.Modified 即 updated_at。客户端不按字段合并，也不比较时间戳。
            if (profile == null || string.IsNullOrEmpty(profile.AccountId))
            {
                return new CloudSaveWriteResult(CloudSaveStatus.NotSignedIn, CloudSaveOrigin.None, "未登录");
            }

            try
            {
                var problem = await PrepareAsync(profile.AccountId, cancellationToken);
                if (problem != null)
                {
                    if (problem == "未登录")
                    {
                        return new CloudSaveWriteResult(CloudSaveStatus.NotSignedIn, CloudSaveOrigin.None, "未登录");
                    }

                    return FailedWrite(problem);
                }

                string json;
                string error;
                if (!PlayerProfileJson.TryWrite(profile, out json, out error))
                {
                    return FailedWrite(error);
                }

                if (json.Length > MaxProfileBytes)
                {
                    return FailedWrite("档案过大，已保留原文件");
                }

                var payload = new Dictionary<string, object> { { CloudSaveKeys.PlayerProfile, json } };
                await Unity.Services.CloudSave.CloudSaveService.Instance.Data.Player.SaveAsync(payload);
                cancellationToken.ThrowIfCancellationRequested();
                return new CloudSaveWriteResult(CloudSaveStatus.Ok, CloudSaveOrigin.Remote, string.Empty);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (RequestFailedException exception)
            {
                return FailedWrite("写入 Cloud Save 失败：" + exception.Message);
            }
            catch (ServicesInitializationException exception)
            {
                return FailedWrite("Unity Services 不可用：" + exception.Message);
            }
        }

        private async Task<string> PrepareAsync(string playerId, CancellationToken cancellationToken)
        {
            var setupError = await UgsSession.EnsureReadyAsync(_config, cancellationToken);
            if (setupError != null)
            {
                return setupError;
            }

            var auth = AuthenticationService.Instance;
            if (!auth.IsSignedIn)
            {
                return "未登录";
            }

            if (auth.IsExpired)
            {
                // 只恢复已有 session token。没有 token 时不新建另一个游客。
                await auth.SignInAnonymouslyAsync(new SignInOptions { CreateAccount = false });
                cancellationToken.ThrowIfCancellationRequested();
            }

            if (string.IsNullOrEmpty(auth.PlayerId))
            {
                return "未登录";
            }

            if (!string.Equals(auth.PlayerId, playerId, StringComparison.Ordinal))
            {
                return "档案账号与当前游客不一致";
            }

            return null;
        }

        private static CloudSaveLoadResult FailedLoad(string error)
        {
            return new CloudSaveLoadResult(CloudSaveStatus.Failed, CloudSaveOrigin.None, null, error);
        }

        private static CloudSaveWriteResult FailedWrite(string error)
        {
            return new CloudSaveWriteResult(CloudSaveStatus.Failed, CloudSaveOrigin.None, error);
        }
    }
}
