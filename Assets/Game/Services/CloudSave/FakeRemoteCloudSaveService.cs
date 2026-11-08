using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;

namespace ShanhaiDingGuard.Services.CloudSave
{
    /// <summary>
    /// 编辑器与离线回退。读假远端，并把同一份 JSON 写入本地缓存。
    /// 假远端只存在于本机 persistentDataPath，不是 UGS Cloud Save。
    /// 有 Dashboard Project ID 且未强制离线时，Boot 改用 UgsCloudSaveService，键仍是 <see cref="CloudSaveKeys.PlayerProfile"/>。
    /// 只有缓存、没有假远端时，不把缓存当成进度。PlayFab 仅为应急，这里不实现。
    /// </summary>
    public sealed class FakeRemoteCloudSaveService : ICloudSaveService
    {
        private readonly string _root;

        public FakeRemoteCloudSaveService()
            : this(Path.Combine(Application.persistentDataPath, "shdg-cache"))
        {
        }

        public FakeRemoteCloudSaveService(string root)
        {
            _root = root ?? string.Empty;
        }

        public Task<CloudSaveLoadResult> LoadAsync(string playerId, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult(Load(_root, playerId));
        }

        public Task<CloudSaveWriteResult> SaveAsync(PlayerProfile profile, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult(Save(_root, profile));
        }

        public static CloudSaveLoadResult Load(string root, string playerId)
        {
            if (string.IsNullOrEmpty(playerId))
            {
                return CloudSaveLoadResult.NotSignedIn();
            }

            if (!IsSafePlayerId(playerId))
            {
                return FailedLoad("玩家 id 无法映射到存档路径");
            }

            var remotePath = RemotePath(root, playerId);
            if (!File.Exists(remotePath))
            {
                return new CloudSaveLoadResult(
                    CloudSaveStatus.NotFound,
                    CloudSaveOrigin.None,
                    null,
                    "假远端没有这份游客档案。本地缓存不是进度。");
            }

            PlayerProfile profile;
            string error;
            if (!TryReadFile(remotePath, playerId, out profile, out error))
            {
                return FailedLoad(error);
            }

            try
            {
                var json = File.ReadAllText(remotePath);
                WriteAtomic(CachePath(root, playerId), json);
            }
            catch (Exception exception)
            {
                return FailedLoad("刷新本地缓存失败：" + exception.Message);
            }

            return new CloudSaveLoadResult(CloudSaveStatus.Ok, CloudSaveOrigin.FakeRemote, profile, string.Empty);
        }

        public static CloudSaveWriteResult Save(string root, PlayerProfile profile)
        {
            if (profile == null || string.IsNullOrEmpty(profile.AccountId))
            {
                return new CloudSaveWriteResult(CloudSaveStatus.NotSignedIn, CloudSaveOrigin.None, "未登录");
            }

            if (!IsSafePlayerId(profile.AccountId))
            {
                return FailedWrite("玩家 id 无法映射到存档路径");
            }

            string json;
            string error;
            if (!PlayerProfileJson.TryWrite(profile, out json, out error))
            {
                return FailedWrite(error);
            }

            try
            {
                WriteAtomic(RemotePath(root, profile.AccountId), json);
                WriteAtomic(CachePath(root, profile.AccountId), json);
            }
            catch (Exception exception)
            {
                return FailedWrite("写入假远端失败：" + exception.Message);
            }

            return new CloudSaveWriteResult(CloudSaveStatus.Ok, CloudSaveOrigin.FakeRemote, string.Empty);
        }

        public static bool IsSafePlayerId(string playerId)
        {
            if (string.IsNullOrEmpty(playerId) || playerId.Length > 128)
            {
                return false;
            }

            for (var i = 0; i < playerId.Length; i++)
            {
                var c = playerId[i];
                var ok = char.IsLetterOrDigit(c) || c == '.' || c == '_' || c == '-';
                if (!ok)
                {
                    return false;
                }
            }

            return true;
        }

        private static bool TryReadFile(string path, string playerId, out PlayerProfile profile, out string error)
        {
            profile = null;
            error = null;
            string json;
            try
            {
                json = File.ReadAllText(path);
            }
            catch (Exception exception)
            {
                error = "读取假远端失败：" + exception.Message;
                return false;
            }

            if (json.Length > 1024 * 1024)
            {
                error = "档案过大，已保留原文件";
                return false;
            }

            if (!PlayerProfileJson.TryRead(json, out profile, out error))
            {
                return false;
            }

            if (profile.AccountId != playerId)
            {
                profile = null;
                error = "档案账号与当前游客不一致，已保留原文件";
                return false;
            }

            return true;
        }

        private static void WriteAtomic(string path, string json)
        {
            var directory = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var tempPath = path + ".tmp";
            File.WriteAllText(tempPath, json);
            if (File.Exists(path))
            {
                var backupPath = path + ".bak";
                File.Replace(tempPath, path, backupPath);
                if (File.Exists(backupPath))
                {
                    File.Delete(backupPath);
                }
            }
            else
            {
                File.Move(tempPath, path);
            }
        }

        private static string RemotePath(string root, string playerId)
        {
            return Path.Combine(root, playerId, "remote.json");
        }

        private static string CachePath(string root, string playerId)
        {
            return Path.Combine(root, playerId, "profile.json");
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
