using System;
using System.Collections.Generic;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Gameplay.CombatSimulation;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace ShanhaiDingGuard.Presentation
{
    /// <summary>
    /// 冀州 01 战斗桩：开战、放置剑阵、胜、负、1x/2x。表现只读快照，不改生命。
    /// 倍速交给 SimClock，不乘进伤害。
    /// 建造格按表顺序对应数字键 1/2/3（以及小键盘），也可直接点格子。
    /// T 或「放置剑阵」放到下一个空闲格。余额不足时模拟拒绝，这里只显示快照里的短提示。
    /// </summary>
    public sealed class BattleHud : MonoBehaviour
    {
        public readonly struct BattleFinished
        {
            public BattleFinished(string levelId, bool won, int leakCount)
            {
                LevelId = levelId;
                Won = won;
                LeakCount = leakCount;
            }

            public string LevelId { get; }

            public bool Won { get; }

            public int LeakCount { get; }
        }

        private const float WorldUnitsPerHeight = 9f;
        private const float PlayfieldWorldWidth = 16f;
        private const float PlayfieldWorldHeight = 9f;
        private const float BattleCameraSize = 4.5f;
        private const float RefWidth = 1920f;
        private const float RefHeight = 1080f;

        private readonly SimClock _clock = new SimClock();
        private SliceBattleContent _content;
        private CombatSimulation _sim;
        private string _error = "读取切片表…";
        private bool _started;
        private bool _reported;
        private Transform _viewRoot;
        private BattleSpriteView _sprites;
        private readonly List<SpriteRenderer> _pathDebug = new List<SpriteRenderer>();
        private bool _showPathDebug;
        private int _cellCursor;
        private Sprite _pixel;

        public event Action<BattleFinished> Finished;

        private void Awake()
        {
            FitBattleCamera();
        }

        private async void Start()
        {
            FitBattleCamera();
            var loaded = await SliceContentLoader.LoadSliceAsync();
            if (!isActiveAndEnabled)
            {
                return;
            }

            if (!loaded.Success)
            {
                _error = loaded.Error;
                return;
            }

            CombatSimulation sim;
            string error;
            if (!CombatSimulation.TryCreate(loaded.Content, out sim, out error))
            {
                _error = error;
                return;
            }

            _content = loaded.Content;
            _sim = sim;
            _error = null;
            BuildView();
        }

        private void Update()
        {
            if (Pressed(BackRect()) || PressedKey(Key.Escape))
            {
                SceneManager.LoadScene("Hub");
                return;
            }

            if (_sim == null)
            {
                return;
            }

            if (!_started && (Pressed(StartRect()) || PressedKey(Key.Enter) || PressedKey(Key.Space) || PressedKey(Key.NumpadEnter)))
            {
                _started = true;
                _sim.Begin();
            }

            if (PressedKey(Key.Digit1) || PressedKey(Key.Numpad1))
            {
                PlaceCell(0);
            }
            else if (PressedKey(Key.Digit2) || PressedKey(Key.Numpad2))
            {
                PlaceCell(1);
            }
            else if (PressedKey(Key.Digit3) || PressedKey(Key.Numpad3))
            {
                PlaceCell(2);
            }
            else if (Pressed(PlaceRect()) || PressedKey(Key.T))
            {
                PlaceNextFree();
            }
            else
            {
                int clicked;
                if (ClickedCell(out clicked))
                {
                    PlaceCell(clicked);
                }
            }

            if (Pressed(SpeedRect()) || PressedKey(Key.X))
            {
                _clock.ToggleSpeed();
            }

            if (PressedKey(Key.P))
            {
                _showPathDebug = !_showPathDebug;
                ApplyPathDebug();
            }

            if (_started && _sim.Phase == BattlePhase.Running)
            {
                var ticks = _clock.ConsumeTicks(Time.deltaTime);
                for (var i = 0; i < ticks; i++)
                {
                    _sim.Tick();
                }
            }

            SyncView();
            ReportIfFinished();
        }

        private void OnDestroy()
        {
            if (_sprites != null)
            {
                _sprites.DestroyRuntimeArt();
                _sprites = null;
            }
        }

        private void OnGUI()
        {
            DrawButton(StartRect(), _started ? "进行中" : "开战");
            DrawButton(PlaceRect(), PlaceLabel());
            DrawButton(SpeedRect(), "倍速 " + _clock.Speed + "x");
            DrawButton(BackRect(), "回枢纽");

            var style = Style(18, TextAnchor.UpperLeft);
            var status = _error;
            string note = null;
            BattleSnapshot snapshot = null;
            if (_sim != null && _content != null)
            {
                snapshot = _sim.Snapshot;
                note = snapshot.Note;
                var icons = _sprites != null && _sprites.Art.Ready;
                status = _content.Level.DisplayName
                    + "\n"
                    + PhaseLabel(snapshot.Phase)
                    + "  tick "
                    + snapshot.Tick
                    + (icons ? string.Empty : "  波次 " + snapshot.WaveNumber + "/" + snapshot.WaveCount)
                    + "  场上 "
                    + snapshot.Enemies.Count
                    + (icons
                        ? string.Empty
                        : "\n灵石 " + snapshot.Balance + "\n" + DingHearts(snapshot.LeakCount, snapshot.LoseLeakCount)
                            + "  漏怪 " + snapshot.LeakCount + "/" + snapshot.LoseLeakCount);
            }

            GUI.Label(StatusRect(), status ?? string.Empty, style);
            if (snapshot != null && _sprites != null && _sprites.Art.Ready)
            {
                DrawResourceRow(snapshot);
            }

            if (!string.IsNullOrEmpty(note))
            {
                var hint = Style(16, TextAnchor.MiddleLeft);
                hint.normal.textColor = new Color(1f, 0.86f, 0.45f, 1f);
                GUI.Label(NoteRect(), note, hint);
            }

            DrawCellLabels();
            GUI.Label(
                HelpRect(),
                "数字键 1/2/3 或点击建造格放置剑阵，T 放到下一个空格。开战前放 1 座可清完 8 波。不放塔则第 3 只漏出即失败。灵石不足会拒绝放置且不扣费。X 倍速，P 开关路径调试线，Enter 开战，Esc 回枢纽。",
                Style(16, TextAnchor.UpperLeft));

            if (_sim != null && (_sim.Phase == BattlePhase.Won || _sim.Phase == BattlePhase.Lost))
            {
                var banner = _sim.Phase == BattlePhase.Won ? "胜利" : "失败";
                var rect = BannerRect();
                GUI.Box(rect, GUIContent.none);
                GUI.Label(rect, banner, Style(40, TextAnchor.MiddleCenter));
            }
        }

        private string PlaceLabel()
        {
            if (_sim == null || _content == null || _sim.Snapshot == null)
            {
                return "放置剑阵";
            }

            var used = 0;
            var cells = _sim.Snapshot.Cells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (cells[i].Occupied || cells[i].Queued)
                {
                    used++;
                }
            }

            return "放置剑阵 " + used + "/" + _content.Level.BuildCells.Count;
        }

        private void PlaceNextFree()
        {
            if (_sim == null || _content == null)
            {
                return;
            }

            var count = _content.Level.BuildCells.Count;
            if (count == 0)
            {
                return;
            }

            for (var n = 0; n < count; n++)
            {
                var index = (_cellCursor + n) % count;
                if (CellFree(index))
                {
                    _cellCursor = (index + 1) % count;
                    PlaceCell(index);
                    return;
                }
            }

            PlaceCell(_cellCursor % count);
        }

        private void PlaceCell(int index)
        {
            if (_sim == null || _content == null)
            {
                return;
            }

            var cells = _content.Level.BuildCells;
            if (index < 0 || index >= cells.Count)
            {
                return;
            }

            _sim.EnqueuePlace(_content.Tower.Id, cells[index].Id);
        }

        private bool CellFree(int index)
        {
            if (_sim == null || _sim.Snapshot == null || _content == null)
            {
                return false;
            }

            var id = _content.Level.BuildCells[index].Id;
            var cells = _sim.Snapshot.Cells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (cells[i].Id == id)
                {
                    return !cells[i].Occupied && !cells[i].Queued;
                }
            }

            return true;
        }

        private bool ClickedCell(out int index)
        {
            index = -1;
            Vector2 gui;
            if (!TryPointerDown(out gui) || _content == null)
            {
                return false;
            }

            if (StartRect().Contains(gui) || PlaceRect().Contains(gui) || SpeedRect().Contains(gui) || BackRect().Contains(gui))
            {
                return false;
            }

            var camera = Camera.main;
            if (camera == null)
            {
                return false;
            }

            var best = 36f * 36f;
            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                var screen = camera.WorldToScreenPoint(ToWorld(cells[i].X, cells[i].Y));
                var dx = screen.x - gui.x;
                var dy = (Screen.height - screen.y) - gui.y;
                var distance = (dx * dx) + (dy * dy);
                if (distance <= best)
                {
                    best = distance;
                    index = i;
                }
            }

            return index >= 0;
        }

        private void DrawCellLabels()
        {
            if (_content == null)
            {
                return;
            }

            var camera = Camera.main;
            if (camera == null)
            {
                return;
            }

            var style = Style(16, TextAnchor.MiddleCenter);
            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                var screen = camera.WorldToScreenPoint(ToWorld(cells[i].X, cells[i].Y));
                GUI.Label(new Rect(screen.x - 18f, (Screen.height - screen.y) - 36f, 36f, 22f), (i + 1).ToString(), style);
            }
        }

        private static string DingHearts(int leaks, int max)
        {
            var left = max - leaks;
            if (left < 0)
            {
                left = 0;
            }

            if (left > max)
            {
                left = max;
            }

            return "铜鼎 " + new string('♥', left) + new string('♡', max - left) + " " + left + "/" + max;
        }

        private void ReportIfFinished()
        {
            if (_reported || _sim == null)
            {
                return;
            }

            if (_sim.Phase != BattlePhase.Won && _sim.Phase != BattlePhase.Lost)
            {
                return;
            }

            _reported = true;
            var handler = Finished;
            if (handler != null)
            {
                handler(new BattleFinished(_content.Level.Id, _sim.Phase == BattlePhase.Won, _sim.LeakCount));
            }
        }

        private void BuildView()
        {
            FitBattleCamera();
            _pixel = Pixel();
            _viewRoot = new GameObject("SliceView").transform;
            if (GameObject.Find("BattleBackground") == null)
            {
                var board = CreateSprite("Playfield", new Color(0.1f, 0.12f, 0.14f, 1f), 0);
                var legacySquare = _content.Level.Space == SliceRules.SpaceNormalizedPlayfield;
                board.localScale = legacySquare
                    ? new Vector3(PlayfieldWorldHeight, PlayfieldWorldHeight, 1f)
                    : new Vector3(PlayfieldWorldWidth, PlayfieldWorldHeight, 1f);
            }

            var waypoints = _content.Level.Waypoints;
            for (var i = 1; i < waypoints.Count; i++)
            {
                var from = ToWorld(waypoints[i - 1].X, waypoints[i - 1].Y);
                var to = ToWorld(waypoints[i].X, waypoints[i].Y);
                var segment = CreateSprite("Path", new Color(0.93f, 0.84f, 0.55f, 0.45f), BattleSpriteView.SortPath);
                var delta = to - from;
                var length = delta.magnitude;
                segment.position = (from + to) * 0.5f;
                if (length > 0.001f)
                {
                    segment.right = delta;
                }

                segment.localScale = new Vector3(length, 0.08f, 1f);
                _pathDebug.Add(segment.GetComponent<SpriteRenderer>());
            }

            var exit = waypoints[waypoints.Count - 1];
            var exitMark = CreateSprite("Exit", new Color(0.85f, 0.25f, 0.22f, 0.45f), BattleSpriteView.SortExit);
            exitMark.position = ToWorld(exit.X, exit.Y);
            exitMark.localScale = new Vector3(0.28f, 0.28f, 1f);
            _pathDebug.Add(exitMark.GetComponent<SpriteRenderer>());
            ApplyPathDebug();
            _sprites = new BattleSpriteView();
            _sprites.Build(_viewRoot, _content, ToWorld, _pixel);
        }

        private void SyncView()
        {
            if (_sim == null || _viewRoot == null)
            {
                return;
            }

            if (_sprites != null)
            {
                _sprites.Sync(_sim, _clock, _started, _cellCursor);
            }
        }

        private void DrawResourceRow(BattleSnapshot snapshot)
        {
            var art = _sprites.Art;
            var size = ResourceIconSize();
            var x = ResourceOriginX();
            var y = ResourceOriginY();
            var gap = Sx(8f);
            var style = Style(18, TextAnchor.MiddleLeft);
            DrawIcon(art.Lingshi, new Rect(x, y, size, size));
            var text = new Rect(x + size + gap, y, Sx(150f), size);
            GUI.Label(text, "灵石 " + snapshot.Balance, style);
            x = text.xMax + Sx(16f);
            DrawIcon(art.Wave, new Rect(x, y, size, size));
            text = new Rect(x + size + gap, y, Sx(170f), size);
            GUI.Label(text, "波次 " + snapshot.WaveNumber + "/" + snapshot.WaveCount, style);
            x = text.xMax + Sx(16f);
            var hearts = snapshot.LoseLeakCount;
            if (hearts < 0)
            {
                hearts = 0;
            }

            var left = hearts - snapshot.LeakCount;
            if (left < 0)
            {
                left = 0;
            }

            for (var i = 0; i < hearts; i++)
            {
                var previous = GUI.color;
                if (i >= left)
                {
                    GUI.color = new Color(0.65f, 0.65f, 0.7f, 0.4f);
                }

                DrawIcon(art.Heart, new Rect(x, y, size, size));
                GUI.color = previous;
                x += size + Sx(4f);
            }

            GUI.Label(new Rect(x + gap, y, Sx(140f), size), snapshot.LeakCount + "/" + snapshot.LoseLeakCount, style);
        }

        private static void DrawIcon(Sprite sprite, Rect rect)
        {
            if (sprite == null || sprite.texture == null)
            {
                return;
            }

            var texture = sprite.texture;
            var texRect = sprite.textureRect;
            if (texture.width < 1 || texture.height < 1 || texRect.width < 1f || texRect.height < 1f)
            {
                return;
            }

            // 用切片在纹理里的矩形，进图集后不会把整张图都画出来。
            var coords = new Rect(
                texRect.x / texture.width,
                texRect.y / texture.height,
                texRect.width / texture.width,
                texRect.height / texture.height);
            GUI.DrawTextureWithTexCoords(rect, texture, coords, true);
        }

        private Transform CreateSprite(string name, Color color, int order)
        {
            var go = new GameObject(name);
            go.transform.SetParent(_viewRoot, false);
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = _pixel;
            renderer.color = color;
            renderer.sortingOrder = order;
            return go.transform;
        }

        private Sprite Pixel()
        {
            var texture = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            texture.SetPixel(0, 0, Color.white);
            texture.Apply();
            texture.filterMode = FilterMode.Point;
            return Sprite.Create(texture, new Rect(0f, 0f, 1f, 1f), new Vector2(0.5f, 0.5f), 1f);
        }

        /// <summary>
        /// height_units_16x9：ToWorld(x,y) = ((x − 0.889) * 9, (y − 0.5) * 9)，战场 16×9，正交相机 size 4.5。
        /// 旧 normalized_playfield 仍映射成 9×9 方场，方便对照迁移前的表。
        /// </summary>
        private Vector3 ToWorld(double x, double y)
        {
            if (_content != null && _content.Level.Space == SliceRules.SpaceNormalizedPlayfield)
            {
                return new Vector3((float)((x - 0.5) * WorldUnitsPerHeight), (float)((y - 0.5) * WorldUnitsPerHeight), 0f);
            }

            return new Vector3((float)((x - 0.889) * WorldUnitsPerHeight), (float)((y - 0.5) * WorldUnitsPerHeight), 0f);
        }

        private static void FitBattleCamera()
        {
            var camera = Camera.main;
            if (camera == null)
            {
                return;
            }

            camera.orthographic = true;
            var aspect = camera.aspect;
            if (aspect < 0.01f)
            {
                aspect = PlayfieldWorldWidth / PlayfieldWorldHeight;
            }

            // 16:9 正好 size 4.5。更宽（含 21:9）保持 4.5，多出来的宽由出血图盖住。
            // 更窄时抬高 size，让 16 world 宽留在画面里：4:3 时 size 为 6，上下由 12 world 高的出血图盖住。
            var sizeForWidth = (PlayfieldWorldWidth * 0.5f) / aspect;
            camera.orthographicSize = Mathf.Max(BattleCameraSize, sizeForWidth);
            camera.backgroundColor = new Color(0.6156863f, 0.6980392f, 0.1647059f, 1f);
            camera.transform.position = new Vector3(0f, 0f, -10f);
        }

        private void ApplyPathDebug()
        {
            for (var i = 0; i < _pathDebug.Count; i++)
            {
                _pathDebug[i].enabled = _showPathDebug;
            }
        }

        private static string PhaseLabel(BattlePhase phase)
        {
            switch (phase)
            {
                case BattlePhase.Ready:
                    return "准备";
                case BattlePhase.Running:
                    return "战斗中";
                case BattlePhase.Won:
                    return "胜利";
                case BattlePhase.Lost:
                    return "失败";
                default:
                    return phase.ToString();
            }
        }

        /// <summary>
        /// 按钮和说明按 1920×1080 参考缩放。资源行在按钮右侧，状态文字排在资源行下面，避免和灵石/波次/心叠在一起。
        /// 有刘海或圆角时整块 HUD 跟着 Screen.safeArea 内缩。比 16:9 更宽（含 21:9）时正交 size 仍是 4.5；更窄时抬高 size。
        /// </summary>
        private static Rect StartRect()
        {
            return new Rect(SafeLeft() + Sx(24f), SafeTop() + Sy(28f), Sx(200f), Sy(64f));
        }

        private static Rect PlaceRect()
        {
            return new Rect(SafeLeft() + Sx(240f), SafeTop() + Sy(28f), Sx(250f), Sy(64f));
        }

        private static Rect SpeedRect()
        {
            return new Rect(SafeLeft() + Sx(506f), SafeTop() + Sy(28f), Sx(170f), Sy(64f));
        }

        private static Rect BackRect()
        {
            return new Rect(SafeLeft() + Sx(692f), SafeTop() + Sy(28f), Sx(170f), Sy(64f));
        }

        private static float ResourceOriginX()
        {
            return SafeLeft() + Sx(880f);
        }

        private static float ResourceOriginY()
        {
            return SafeTop() + Sy(56f);
        }

        private static float ResourceIconSize()
        {
            return Sy(42f);
        }

        private static Rect StatusRect()
        {
            var x = ResourceOriginX();
            var y = ResourceOriginY() + ResourceIconSize() + Sy(16f);
            var right = Screen.width - SafeRight() - Sx(24f);
            return new Rect(x, y, Mathf.Max(120f, right - x), Sy(72f));
        }

        private static Rect NoteRect()
        {
            var x = SafeLeft() + Sx(24f);
            var width = Mathf.Max(120f, Screen.width - SafeLeft() - SafeRight() - Sx(48f));
            return new Rect(x, Screen.height - SafeBottom() - Sy(100f), width, Sy(30f));
        }

        private static Rect HelpRect()
        {
            var x = SafeLeft() + Sx(24f);
            var width = Mathf.Max(120f, Screen.width - SafeLeft() - SafeRight() - Sx(48f));
            return new Rect(x, Screen.height - SafeBottom() - Sy(68f), width, Sy(60f));
        }

        private static Rect SafeArea()
        {
            var safe = Screen.safeArea;
            if (safe.width < 1f || safe.height < 1f)
            {
                return new Rect(0f, 0f, Mathf.Max(1f, Screen.width), Mathf.Max(1f, Screen.height));
            }

            return safe;
        }

        private static float SafeTop()
        {
            var safe = SafeArea();
            return Mathf.Max(0f, Screen.height - (safe.y + safe.height));
        }

        private static float SafeBottom()
        {
            return Mathf.Max(0f, SafeArea().y);
        }

        private static float SafeLeft()
        {
            return Mathf.Max(0f, SafeArea().x);
        }

        private static float SafeRight()
        {
            var safe = SafeArea();
            return Mathf.Max(0f, Screen.width - (safe.x + safe.width));
        }

        private static Rect BannerRect()
        {
            var width = Sx(320f);
            var height = Sy(80f);
            return new Rect((Screen.width - width) * 0.5f, (Screen.height - height) * 0.5f, width, height);
        }

        private static float Sx(float referenceX)
        {
            return referenceX * Screen.width / RefWidth;
        }

        private static float Sy(float referenceY)
        {
            return referenceY * Screen.height / RefHeight;
        }

        private static float UiScale()
        {
            var scale = Mathf.Min(Screen.width / RefWidth, Screen.height / RefHeight);
            if (scale < 0.65f)
            {
                return 0.65f;
            }

            return scale;
        }

        private static void DrawButton(Rect rect, string label)
        {
            GUI.Box(rect, GUIContent.none);
            GUI.Label(rect, label, Style(18, TextAnchor.MiddleCenter));
        }

        private static GUIStyle Style(int size, TextAnchor anchor)
        {
            var style = new GUIStyle(GUI.skin.label);
            style.fontSize = Mathf.Max(10, Mathf.RoundToInt(size * UiScale()));
            style.alignment = anchor;
            style.normal.textColor = Color.white;
            style.wordWrap = true;
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
