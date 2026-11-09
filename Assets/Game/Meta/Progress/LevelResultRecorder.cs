using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Services.Auth;
using ShanhaiDingGuard.Services.CloudSave;

namespace ShanhaiDingGuard.Meta
{
    /// <summary>
    /// 把一局胜负写进已有档案的 levelProgress。不改 Auth / CloudSave 实现。
    /// 形状：{ "level_jizhou_01": { "result": "win", "leakCount": 0 } }。
    /// 已经胜利过的关卡不会被后来的失败覆盖。
    /// </summary>
    public static class LevelResultRecorder
    {
        public static async Task<string> RecordAsync(
            IAuthService auth,
            ICloudSaveService cloudSave,
            string levelId,
            bool won,
            int leakCount,
            CancellationToken cancellationToken)
        {
            if (auth == null || cloudSave == null)
            {
                return "[Meta] 云存档跳过：Boot 尚未配置服务。战斗结果只留在本局。";
            }

            if (!auth.Current.IsSignedIn)
            {
                return "[Meta] 云存档跳过：没有游客账号。本地缓存不是进度。";
            }

            var loaded = await cloudSave.LoadAsync(auth.Current.PlayerId, cancellationToken);
            PlayerProfile profile;
            if (loaded.Status == CloudSaveStatus.NotFound)
            {
                profile = PlayerProfile.CreateEmpty(auth.Current.PlayerId);
            }
            else if (loaded.Status == CloudSaveStatus.Ok && loaded.Profile != null)
            {
                profile = loaded.Profile;
            }
            else
            {
                return "[Meta] 云存档未写入：" + (string.IsNullOrEmpty(loaded.Error) ? loaded.Status.ToString() : loaded.Error);
            }

            string updated;
            string error;
            bool keptWin;
            if (!TryUpsert(profile.LevelProgressJson, levelId, won, leakCount, out updated, out error, out keptWin))
            {
                return "[Meta] 云存档未写入：" + error;
            }

            if (keptWin)
            {
                return "[Meta] 已保留 " + levelId + " 的胜利记录，不因本局失败覆盖。";
            }

            profile.LevelProgressJson = updated;
            var written = await cloudSave.SaveAsync(profile, cancellationToken);
            if (written.Status != CloudSaveStatus.Ok)
            {
                return "[Meta] 云存档写入失败：" + written.Error;
            }

            return "[Meta] 已写入 " + levelId + " result=" + (won ? "win" : "lose") + " leakCount=" + leakCount.ToString(CultureInfo.InvariantCulture) + " origin=" + written.Origin;
        }

        public static bool TryUpsert(
            string levelProgressJson,
            string levelId,
            bool won,
            int leakCount,
            out string updated,
            out string error,
            out bool keptExistingWin)
        {
            updated = null;
            error = null;
            keptExistingWin = false;
            if (!IsSafeId(levelId))
            {
                error = "关卡 id 无法写入 levelProgress，已保留原文件";
                return false;
            }

            if (leakCount < 0)
            {
                error = "leakCount 无法识别，已保留原文件";
                return false;
            }

            var source = string.IsNullOrEmpty(levelProgressJson) ? "{}" : levelProgressJson;
            JsonNode root;
            if (!JsonReader.TryParse(source, out root, out error) || root.Kind != ShanhaiDingGuard.Content.JsonKind.Object)
            {
                error = "levelProgress 无法识别，已保留原文件";
                return false;
            }

            var book = new SortedDictionary<string, Entry>(StringComparer.Ordinal);
            foreach (var pair in root.Object)
            {
                Entry existing;
                if (!TryReadEntry(pair.Value, out existing, out error))
                {
                    error = "levelProgress 无法识别，已保留原文件";
                    return false;
                }

                book.Add(pair.Key, existing);
            }

            var result = won ? "win" : "lose";
            Entry current;
            if (book.TryGetValue(levelId, out current) && current.Result == "win" && !won)
            {
                keptExistingWin = true;
                updated = source;
                error = null;
                return true;
            }

            book[levelId] = new Entry { Result = result, LeakCount = leakCount };
            updated = Write(book);
            error = null;
            return true;
        }

        private static bool TryReadEntry(JsonNode node, out Entry entry, out string error)
        {
            entry = null;
            error = null;
            if (node == null || node.Kind != ShanhaiDingGuard.Content.JsonKind.Object)
            {
                error = "levelProgress 无法识别，已保留原文件";
                return false;
            }

            if (node.Object.Count != 2 || !node.Object.ContainsKey("result") || !node.Object.ContainsKey("leakCount"))
            {
                error = "levelProgress 有未识别字段，已保留原文件";
                return false;
            }

            var resultNode = node.Object["result"];
            var leakNode = node.Object["leakCount"];
            int leaks;
            if (resultNode.Kind != ShanhaiDingGuard.Content.JsonKind.String || (resultNode.String != "win" && resultNode.String != "lose") || !leakNode.TryGetInt(out leaks) || leaks < 0)
            {
                error = "levelProgress 无法识别，已保留原文件";
                return false;
            }

            entry = new Entry { Result = resultNode.String, LeakCount = leaks };
            return true;
        }

        private static string Write(SortedDictionary<string, Entry> book)
        {
            var builder = new StringBuilder();
            builder.Append('{');
            var first = true;
            foreach (var pair in book)
            {
                if (!first)
                {
                    builder.Append(',');
                }

                first = false;
                builder.Append(JsonReader.Quote(pair.Key));
                builder.Append(":{\"result\":");
                builder.Append(JsonReader.Quote(pair.Value.Result));
                builder.Append(",\"leakCount\":");
                builder.Append(pair.Value.LeakCount.ToString(CultureInfo.InvariantCulture));
                builder.Append('}');
            }

            builder.Append('}');
            return builder.ToString();
        }

        private static bool IsSafeId(string levelId)
        {
            if (string.IsNullOrEmpty(levelId) || levelId.Length > 64)
            {
                return false;
            }

            for (var i = 0; i < levelId.Length; i++)
            {
                var c = levelId[i];
                var ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.';
                if (!ok)
                {
                    return false;
                }
            }

            return true;
        }

        private sealed class Entry
        {
            public string Result;
            public int LeakCount;
        }
    }
}
