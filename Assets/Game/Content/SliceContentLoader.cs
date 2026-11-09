using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;

namespace ShanhaiDingGuard.Content
{
    public readonly struct SliceLoadResult
    {
        public SliceLoadResult(bool success, SliceBattleContent content, string error)
        {
            Success = success;
            Content = content;
            Error = error ?? string.Empty;
        }

        public bool Success { get; }

        public SliceBattleContent Content { get; }

        public string Error { get; }

        public static SliceLoadResult Ok(SliceBattleContent content)
        {
            return new SliceLoadResult(true, content, string.Empty);
        }

        public static SliceLoadResult Failed(string error)
        {
            return new SliceLoadResult(false, null, error);
        }
    }

    /// <summary>
    /// M1 直接读 JSON。编辑器优先读仓库 content/，玩家包读 StreamingAssets/shdg。
    /// 不使用 Addressables。源表仍在 content/，StreamingAssets 只是进包副本。
    /// 可玩表的 slice 接受 m1 与 jizhou_01_formal。content/examples 的 placeholder 仍拒绝。
    /// </summary>
    public static class SliceContentLoader
    {
        public const string TowerRelativePath = "towers/tower_jin.json";
        public const string EnemyRelativePath = "enemies/enemy_dangkang.json";
        public const string LevelRelativePath = "levels/level_jizhou_01.json";

        public static async Task<SliceLoadResult> LoadSliceAsync()
        {
            var tower = await ReadTextAsync(TowerRelativePath);
            if (!tower.Ok)
            {
                return SliceLoadResult.Failed(tower.Error);
            }

            var enemy = await ReadTextAsync(EnemyRelativePath);
            if (!enemy.Ok)
            {
                return SliceLoadResult.Failed(enemy.Error);
            }

            var level = await ReadTextAsync(LevelRelativePath);
            if (!level.Ok)
            {
                return SliceLoadResult.Failed(level.Error);
            }

            SliceBattleContent content;
            string error;
            if (!SliceTables.TryParse(tower.Text, enemy.Text, level.Text, SliceRules.SliceLevelId, out content, out error))
            {
                return SliceLoadResult.Failed(error);
            }

            return SliceLoadResult.Ok(content);
        }

        private readonly struct TextRead
        {
            public TextRead(bool ok, string text, string error)
            {
                Ok = ok;
                Text = text;
                Error = error ?? string.Empty;
            }

            public bool Ok { get; }

            public string Text { get; }

            public string Error { get; }
        }

        private static Task<TextRead> ReadTextAsync(string relative)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            return ReadAndroidAsync(relative);
#else
            return Task.FromResult(ReadFile(relative));
#endif
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        private static async Task<TextRead> ReadAndroidAsync(string relative)
        {
            using (var request = UnityEngine.Networking.UnityWebRequest.Get(StreamingUrl(relative)))
            {
                var operation = request.SendWebRequest();
                while (!operation.isDone)
                {
                    await Task.Yield();
                }

                if (request.result != UnityEngine.Networking.UnityWebRequest.Result.Success)
                {
                    return new TextRead(false, null, "读不到切片表 " + relative + "：" + request.error);
                }

                return new TextRead(true, request.downloadHandler.text, null);
            }
        }

        private static string StreamingUrl(string relative)
        {
            var root = Application.streamingAssetsPath.Replace('\\', '/');
            if (!root.EndsWith("/", StringComparison.Ordinal))
            {
                root += "/";
            }

            return root + "shdg/" + relative;
        }
#else
        private static TextRead ReadFile(string relative)
        {
            var path = ResolvePath(relative);
            if (string.IsNullOrEmpty(path) || !File.Exists(path))
            {
                return new TextRead(false, null, "读不到切片表 " + relative);
            }

            try
            {
                return new TextRead(true, File.ReadAllText(path), null);
            }
            catch (Exception exception)
            {
                return new TextRead(false, null, "读切片表失败：" + exception.Message);
            }
        }

        private static string ResolvePath(string relative)
        {
#if UNITY_EDITOR
            var authored = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "content", relative));
            if (File.Exists(authored))
            {
                return authored;
            }
#endif
            return Path.Combine(Application.streamingAssetsPath, "shdg", relative.Replace('/', Path.DirectorySeparatorChar));
        }
#endif
    }
}
