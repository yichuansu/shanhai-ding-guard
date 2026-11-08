using ShanhaiDingGuard.Services.Analytics;
using ShanhaiDingGuard.Services.Auth;
using ShanhaiDingGuard.Services.CloudSave;

namespace ShanhaiDingGuard.App
{
    /// <summary>
    /// 组合根。当前接上 UGS Anonymous / Guest 桩和假远端云存档。
    /// 首发是海外 / 非大陆 iOS 与 Android。这里不注册中国大陆渠道 SDK，也不做大陆合规桩。
    /// </summary>
    public static class GameServices
    {
        public static IAuthService Auth { get; private set; }

        public static ICloudSaveService CloudSave { get; private set; }

        public static IAnalyticsService Analytics { get; private set; }

        public static void ConfigureStubs()
        {
            Auth = new DevAuthService();
            CloudSave = new FakeRemoteCloudSaveService();
            Analytics = new NoOpAnalyticsService();
        }
    }
}
