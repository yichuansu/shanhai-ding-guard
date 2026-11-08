using ShanhaiDingGuard.Content;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace ShanhaiDingGuard.Presentation
{
    /// <summary>
    /// 枢纽桩：进入 level_jizhou_01。不登录，也不写云存档。
    /// </summary>
    public sealed class HubStartBattle : MonoBehaviour
    {
        private void Update()
        {
            if (Pressed(EnterRect()) || PressedKey(Key.Enter) || PressedKey(Key.Space) || PressedKey(Key.NumpadEnter))
            {
                SceneManager.LoadScene("Battle");
            }
        }

        private void OnGUI()
        {
            var title = Style(32, TextAnchor.MiddleCenter);
            var body = Style(18, TextAnchor.MiddleCenter);
            GUI.Label(new Rect(0f, 72f, Screen.width, 48f), "山海守鼎", title);
            GUI.Label(new Rect(0f, 128f, Screen.width, 32f), "冀州 · 01", body);
            DrawButton(EnterRect(), "进入战斗");
            GUI.Label(
                new Rect(40f, 320f, Screen.width - 80f, 64f),
                "开始 " + SliceRules.SliceLevelId + "\n点击按钮，或按 Enter",
                body);
        }

        private static Rect EnterRect()
        {
            return new Rect((Screen.width * 0.5f) - 140f, 220f, 280f, 56f);
        }

        private static void DrawButton(Rect rect, string label)
        {
            GUI.Box(rect, GUIContent.none);
            GUI.Label(rect, label, Style(20, TextAnchor.MiddleCenter));
        }

        private static GUIStyle Style(int size, TextAnchor anchor)
        {
            var style = new GUIStyle(GUI.skin.label);
            style.fontSize = size;
            style.alignment = anchor;
            style.normal.textColor = Color.white;
            return style;
        }

        private static bool Pressed(Rect rect)
        {
            Vector2 gui;
            return TryPointerDown(out gui) && rect.Contains(gui);
        }

        private static bool TryPointerDown(out Vector2 gui)
        {
            gui = default;
            var mouse = Mouse.current;
            if (mouse != null && mouse.leftButton.wasPressedThisFrame)
            {
                var position = mouse.position.ReadValue();
                gui = new Vector2(position.x, Screen.height - position.y);
                return true;
            }

            var touch = Touchscreen.current;
            if (touch != null && touch.primaryTouch.press.wasPressedThisFrame)
            {
                var position = touch.primaryTouch.position.ReadValue();
                gui = new Vector2(position.x, Screen.height - position.y);
                return true;
            }

            return false;
        }

        private static bool PressedKey(Key key)
        {
            var keyboard = Keyboard.current;
            return keyboard != null && keyboard[key].wasPressedThisFrame;
        }
    }
}
