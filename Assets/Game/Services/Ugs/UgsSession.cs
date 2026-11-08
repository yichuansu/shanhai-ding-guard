using System.Threading;
using System.Threading.Tasks;
using Unity.Services.Core;
using Unity.Services.Core.Environments;
using UnityEngine;

namespace ShanhaiDingGuard.Services.Ugs
{
    /// <summary>
    /// 初始化 Unity Services，并核对 UgsConfig 与 Player Settings 的 cloudProjectId。
    /// Project ID 不能在运行时改写，SDK 读的是 Application.cloudProjectId。
    /// </summary>
    static class UgsSession
    {
        public static async Task<string> EnsureReadyAsync(UgsConfig config, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var linkError = DescribeProjectLink(config);
            if (linkError != null)
            {
                return linkError;
            }

            if (UnityServices.State == ServicesInitializationState.Initialized)
            {
                return null;
            }

            var options = new InitializationOptions();
            options.SetEnvironmentName(config.EnvironmentName);
            try
            {
                await UnityServices.InitializeAsync(options);
            }
            catch (ServicesInitializationException exception)
            {
                return "Unity Services 初始化失败：" + exception.Message;
            }

            cancellationToken.ThrowIfCancellationRequested();
            if (UnityServices.State != ServicesInitializationState.Initialized)
            {
                return "Unity Services 初始化未完成。";
            }

            return null;
        }

        public static string DescribeProjectLink(UgsConfig config)
        {
            if (config == null || !config.HasDashboardProjectId)
            {
                return "UgsConfig 没有可用的 Dashboard Project ID。见 docs/UGS_SETUP.md。";
            }

            if (!UgsProjectIds.IsDashboardProjectId(Application.cloudProjectId))
            {
                return "Player Settings 的 cloudProjectId 还是空的。把同一个 Dashboard Project ID 链到工程。见 docs/UGS_SETUP.md。";
            }

            if (!UgsProjectIds.SameProject(config.ProjectId, Application.cloudProjectId))
            {
                return "UgsConfig.projectId 与 Player Settings cloudProjectId 不是同一个工程。";
            }

            return null;
        }
    }
}
