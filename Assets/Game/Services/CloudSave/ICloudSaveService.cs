using System.Threading;
using System.Threading.Tasks;

namespace ShanhaiDingGuard.Services.CloudSave
{
    public enum CloudSaveStatus
    {
        Ok = 0,
        NotSignedIn = 1,
        NotFound = 2,
        Failed = 3,
    }

    public enum CloudSaveOrigin
    {
        None = 0,
        LocalCache = 1,
        FakeRemote = 2,
        Remote = 3,
    }

    public readonly struct CloudSaveLoadResult
    {
        public CloudSaveLoadResult(CloudSaveStatus status, CloudSaveOrigin origin, PlayerProfile profile, string error)
        {
            Status = status;
            Origin = origin;
            Profile = profile;
            Error = error ?? string.Empty;
        }

        public CloudSaveStatus Status { get; }

        public CloudSaveOrigin Origin { get; }

        public PlayerProfile Profile { get; }

        public string Error { get; }

        public static CloudSaveLoadResult NotSignedIn()
        {
            return new CloudSaveLoadResult(CloudSaveStatus.NotSignedIn, CloudSaveOrigin.None, null, "未登录");
        }
    }

    public readonly struct CloudSaveWriteResult
    {
        public CloudSaveWriteResult(CloudSaveStatus status, CloudSaveOrigin origin, string error)
        {
            Status = status;
            Origin = origin;
            Error = error ?? string.Empty;
        }

        public CloudSaveStatus Status { get; }

        public CloudSaveOrigin Origin { get; }

        public string Error { get; }
    }

    /// <summary>
    /// 按 UGS Anonymous / Guest 的玩家 id 读写一份 shdg.save。
    /// 生产实现调用 CloudSaveService.Instance.Data.Player 的 LoadAsync / SaveAsync，
    /// 键为 <see cref="CloudSaveKeys.PlayerProfile"/>。
    /// 当前桩写本地缓存，并写一份假远端；假远端才是桩里的进度来源。
    /// 没有玩家 id 时不把缓存当成进度。PlayFab 仅为应急，MVP 不并行实现。
    /// </summary>
    public interface ICloudSaveService
    {
        Task<CloudSaveLoadResult> LoadAsync(string playerId, CancellationToken cancellationToken);

        Task<CloudSaveWriteResult> SaveAsync(PlayerProfile profile, CancellationToken cancellationToken);
    }
}
