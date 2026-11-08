using System;
using System.Threading;
using ShanhaiDingGuard.Meta;
using ShanhaiDingGuard.Presentation;
using UnityEngine;

namespace ShanhaiDingGuard.App
{
    /// <summary>
    /// 对局结束后经 Meta 写入已有的 ICloudSaveService。
    /// 不改 Boot 登录，也不改 Auth / CloudSave 实现。没有游客会话时跳过。
    /// </summary>
    public sealed class BattleResultHook : MonoBehaviour
    {
        private BattleHud _hud;
        private bool _recorded;

        private void OnEnable()
        {
            _hud = GetComponent<BattleHud>();
            if (_hud == null)
            {
                _hud = FindFirstObjectByType<BattleHud>();
            }

            if (_hud != null)
            {
                _hud.Finished += OnFinished;
            }
        }

        private void OnDisable()
        {
            if (_hud != null)
            {
                _hud.Finished -= OnFinished;
            }
        }

        private async void OnFinished(BattleHud.BattleFinished finished)
        {
            if (_recorded)
            {
                return;
            }

            _recorded = true;
            try
            {
                var line = await LevelResultRecorder.RecordAsync(
                    GameServices.Auth,
                    GameServices.CloudSave,
                    finished.LevelId,
                    finished.Won,
                    finished.LeakCount,
                    CancellationToken.None);
                Debug.Log(line);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }
    }
}
