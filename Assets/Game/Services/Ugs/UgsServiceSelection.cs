namespace ShanhaiDingGuard.Services.Ugs
{
    /// <summary>
    /// 选择 UGS 还是 Dev/Fake。有 Dashboard Project ID 时默认走 UGS。
    /// 脚本定义符号 SHDG_FORCE_DEV_SERVICES 由调用方折成 forceDevServices。
    /// </summary>
    public static class UgsServiceSelection
    {
        public const string UgsMode = "ugs";

        public const string DevMode = "dev";

        public static bool PreferUgs(bool forceDevServices, bool forceOfflineStubs, string projectId)
        {
            if (forceDevServices || forceOfflineStubs)
            {
                return false;
            }

            return UgsProjectIds.IsDashboardProjectId(projectId);
        }
    }
}
