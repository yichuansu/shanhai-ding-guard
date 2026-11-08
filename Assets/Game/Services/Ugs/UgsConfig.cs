using UnityEngine;

namespace ShanhaiDingGuard.Services.Ugs
{
    /// <summary>
    /// UGS 工程与环境。Project ID 留占位，直到有人把 Dashboard 上的 id 贴进来。
    /// 运行时用 Resources.Load("UgsConfig")。资产在本目录的 Resources/UgsConfig.asset。
    /// SDK 实际连的工程仍是 Player Settings 的 cloudProjectId，两边必须是同一个 GUID。
    /// </summary>
    [CreateAssetMenu(fileName = "UgsConfig", menuName = "Shanhai Ding Guard/UGS Config")]
    public sealed class UgsConfig : ScriptableObject
    {
        [SerializeField]
        [Tooltip("Unity Dashboard Project ID（GUID）。占位符表示尚未配置，Boot 使用 Dev/Fake。不要写入虚构的 id。")]
        string projectId = UgsProjectIds.Placeholder;

        [SerializeField]
        [Tooltip("Dashboard Environment 名称。默认 production。")]
        string environmentName = UgsProjectIds.DefaultEnvironment;

        [SerializeField]
        [Tooltip("为真时即使填了 Project ID 也使用 DevAuthService 与 FakeRemoteCloudSaveService。")]
        bool forceOfflineStubs = false;

        public string ProjectId
        {
            get { return projectId ?? string.Empty; }
        }

        public string EnvironmentName
        {
            get
            {
                if (string.IsNullOrWhiteSpace(environmentName))
                {
                    return UgsProjectIds.DefaultEnvironment;
                }

                return environmentName.Trim();
            }
        }

        public bool ForceOfflineStubs
        {
            get { return forceOfflineStubs; }
        }

        public bool HasDashboardProjectId
        {
            get { return UgsProjectIds.IsDashboardProjectId(projectId); }
        }

        public static UgsConfig LoadOrDefault()
        {
            var loaded = Resources.Load<UgsConfig>("UgsConfig");
            if (loaded != null)
            {
                return loaded;
            }

            return CreateInstance<UgsConfig>();
        }
    }
}
