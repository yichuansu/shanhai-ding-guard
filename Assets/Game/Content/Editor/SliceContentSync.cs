using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace ShanhaiDingGuard.Content.EditorTools
{
    /// <summary>
    /// 把 content/ 下的切片表复制到 StreamingAssets/shdg，供玩家包读取。
    /// 编辑器 Play 仍直接读 content/，避免和形状样例的 .meta 混在一起。
    /// </summary>
    public sealed class SliceContentSync : IPreprocessBuildWithReport
    {
        public int callbackOrder
        {
            get { return 0; }
        }

        public void OnPreprocessBuild(BuildReport report)
        {
            CopySlice();
        }

        [MenuItem("山海守鼎/Sync M1 Slice Content")]
        public static void Sync()
        {
            CopySlice();
            AssetDatabase.Refresh();
        }

        private static void CopySlice()
        {
            var project = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
            var source = Path.Combine(project, "content");
            var destination = Path.Combine(Application.dataPath, "StreamingAssets", "shdg");
            CopyJson(Path.Combine(source, "towers"), Path.Combine(destination, "towers"));
            CopyJson(Path.Combine(source, "enemies"), Path.Combine(destination, "enemies"));
            CopyJson(Path.Combine(source, "levels"), Path.Combine(destination, "levels"));
        }

        private static void CopyJson(string fromDirectory, string toDirectory)
        {
            if (!Directory.Exists(fromDirectory))
            {
                return;
            }

            Directory.CreateDirectory(toDirectory);
            var files = Directory.GetFiles(fromDirectory, "*.json");
            for (var i = 0; i < files.Length; i++)
            {
                var name = Path.GetFileName(files[i]);
                File.Copy(files[i], Path.Combine(toDirectory, name), true);
            }
        }
    }
}
