using ShanhaiDingGuard.Services.Analytics;
using ShanhaiDingGuard.Services.Auth;
using ShanhaiDingGuard.Services.CloudSave;
using ShanhaiDingGuard.Services.Ugs;

namespace ShanhaiDingGuard.App
{
    /// <summary>
    /// 组合根。有 Dashboard Project ID 时接 UgsAuthService 与 UgsCloudSaveService。
    /// 否则，或 UgsConfig.forceOfflineStubs / SHDG_FORCE_DEV_SERVICES 打开时，接 Dev 与假远端。
    /// 首发是海外 / 非大陆 iOS 与 Android。这里不注册中国大陆渠道 SDK。
    /// </summary>
    public static class GameServices
    {
        public static IAuthService Auth { get; private set; }

        public static ICloudSaveService CloudSave { get; private set; }

        public static IAnalyticsService Analytics { get; private set; }

        public static string Mode { get; private set; } = UgsServiceSelection.DevMode;

        public static void Configure()
        {
#if SHDG_FORCE_DEV_SERVICES
            const bool forceDevServices = true;
#else
            const bool forceDevServices = false;
#endif
            var config = UgsConfig.LoadOrDefault();
            if (!UgsServiceSelection.PreferUgs(forceDevServices, config.ForceOfflineStubs, config.ProjectId))
            {
                ConfigureStubs();
                return;
            }

            Auth = new UgsAuthService(config);
            CloudSave = new UgsCloudSaveService(config);
            Analytics = new NoOpAnalyticsService();
            Mode = UgsServiceSelection.UgsMode;
        }

        public static void ConfigureStubs()
        {
            Auth = new DevAuthService();
            CloudSave = new FakeRemoteCloudSaveService();
            Analytics = new NoOpAnalyticsService();
            Mode = UgsServiceSelection.DevMode;
        }
    }
}
