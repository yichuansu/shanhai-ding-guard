using System;

namespace ShanhaiDingGuard.Services.Ugs
{
    /// <summary>
    /// Dashboard Project ID 的占位与形状判断。不包含任何真实工程 id。
    /// </summary>
    public static class UgsProjectIds
    {
        public const string Placeholder = "REPLACE_WITH_DASHBOARD_PROJECT_ID";

        public const string DefaultEnvironment = "production";

        public static bool IsDashboardProjectId(string value)
        {
            Guid projectId;
            return TryParseProjectId(value, out projectId);
        }

        public static bool SameProject(string left, string right)
        {
            Guid a;
            Guid b;
            if (!TryParseProjectId(left, out a) || !TryParseProjectId(right, out b))
            {
                return false;
            }

            return a == b;
        }

        public static bool TryParseProjectId(string value, out Guid projectId)
        {
            projectId = Guid.Empty;
            if (string.IsNullOrWhiteSpace(value))
            {
                return false;
            }

            var trimmed = value.Trim();
            if (string.Equals(trimmed, Placeholder, StringComparison.Ordinal))
            {
                return false;
            }

            if (Guid.TryParseExact(trimmed, "D", out projectId) || Guid.TryParseExact(trimmed, "N", out projectId))
            {
                return projectId != Guid.Empty;
            }

            projectId = Guid.Empty;
            return false;
        }
    }
}
