using System;
using System.Collections.Generic;
using ShanhaiDingGuard.Gameplay.CombatSimulation;
using ShanhaiDingGuard.Gameplay.Path;
using UnityEngine;

namespace ShanhaiDingGuard.Presentation
{
    /// <summary>
    /// 飞剑只读模拟快照。水平位置不用 px/s。
    /// 飞行中：α = SimClock.InterpolationAlpha（倍速已经折进累计墙钟）。
    /// 段起点 = 上一拍结束的模拟坐标，段终点 = 按同一规则预测的下一拍坐标
    /// （敌人先沿路径走一步，飞剑再朝该点移动 projectileSpeed；距离 ≤ 速度则落在该点）。
    /// 显示坐标 = lerp(段起点, 段终点, α)。
    /// 命中或消散那一拍把飞剑钉在本拍模拟落点，α 不再把它拉回段起点。
    /// 竖直偏移用 progress = 已飞距离 ÷（已飞 + 剩余），从塔顶 0.6 world 收到身体中心 0.37 world。
    /// progress 到 1 时偏移落在身体中心，和命中特效、扣血同一帧。
    /// 拖尾 Time = 0.25s / 倍速，1 倍速下长度仍约 126 px。
    /// </summary>
    public sealed class BattleProjectileView
    {
        private const float SpawnLift = 0.6f;
        private const float HitLift = 0.37f;
        private const float TrailSeconds = 0.25f;
        private const float TrailWidth = 0.20f;
        private const float TrailMinVertex = 0.05f;
        private const float HiltLocalX = -0.183f;
        private const float ShimmerFps = 12f;
        private const float HitFps = 20f;
        private const float FadeSeconds = 0.2f;
        private const float FadeInSeconds = 0.05f;

        private sealed class SwordVisual
        {
            public int Id;
            public Transform Root;
            public SpriteRenderer Sword;
            public SpriteRenderer Afterimage;
            public TrailRenderer Trail;
            public Material TrailMaterial;
            public float SpawnAnim;
            public float FadeStart = -1f;
            public bool Ending;
            public Vector3 LastWorld;
            public bool HasLast;
            public float Facing;
        }

        private sealed class HitVisual
        {
            public SpriteRenderer Renderer;
            public float Start;
        }

        private readonly List<SwordVisual> _swords = new List<SwordVisual>();
        private readonly List<HitVisual> _hits = new List<HitVisual>();
        private readonly List<SwordImpact> _impacts = new List<SwordImpact>();
        private readonly List<Material> _materials = new List<Material>();
        private readonly HashSet<string> _flashed = new HashSet<string>();
        private readonly SwordCueTrack _cues = new SwordCueTrack();
        private CombatSimulation _trackedSim;
        private Transform _root;
        private Func<double, double, Vector3> _toWorld;
        private Sprite _pixel;

        public void Build(Transform root, Func<double, double, Vector3> toWorld, Sprite pixel)
        {
            _root = root;
            _toWorld = toWorld;
            _pixel = pixel;
        }

        public void DestroyRuntimeArt()
        {
            for (var i = 0; i < _swords.Count; i++)
            {
                if (_swords[i].Root != null)
                {
                    UnityEngine.Object.Destroy(_swords[i].Root.gameObject);
                }
            }

            for (var i = 0; i < _hits.Count; i++)
            {
                if (_hits[i].Renderer != null)
                {
                    UnityEngine.Object.Destroy(_hits[i].Renderer.gameObject);
                }
            }

            for (var i = 0; i < _materials.Count; i++)
            {
                if (_materials[i] != null)
                {
                    UnityEngine.Object.Destroy(_materials[i]);
                }
            }

            _materials.Clear();
            _swords.Clear();
            _hits.Clear();
            _cues.Clear();
            _trackedSim = null;
        }

        public void Sync(
            CombatSimulation sim,
            BattleSnapshot snapshot,
            float alpha,
            float anim,
            BattleArt art,
            double projectileSpeed,
            int speed,
            Action<string, float> onTowerFlash)
        {
            if (_root == null || sim == null || snapshot == null)
            {
                return;
            }

            if (!ReferenceEquals(sim, _trackedSim) || snapshot.Phase == BattlePhase.Ready)
            {
                DropAllSwords();
                _cues.Clear();
                _trackedSim = sim;
            }

            _impacts.Clear();
            sim.CopySwordImpacts(_impacts);
            _flashed.Clear();
            _cues.BeginFrame();
            var trailTime = TrailSeconds / Mathf.Max(1, speed);

            if (snapshot.Swords != null)
            {
                for (var i = 0; i < snapshot.Swords.Count; i++)
                {
                    var sword = snapshot.Swords[i];
                    var decision = _cues.Observe(sword.Id, sword.HitThisTick, sword.DissipatedThisTick, anim);
                    if (!decision.Show)
                    {
                        continue;
                    }

                    var visual = FindOrCreate(sword.Id, art);
                    float progress;
                    var world = DisplayWorld(sword, snapshot, sim.Path, projectileSpeed, alpha, out progress);
                    Place(visual, world, sword, art, anim, trailTime);
                    ApplyCue(visual, decision, world, anim, art);
                }
            }

            for (var i = 0; i < _impacts.Count; i++)
            {
                var impact = _impacts[i];
                if (impact.Spawned && onTowerFlash != null && _flashed.Add(impact.CellId ?? string.Empty))
                {
                    onTowerFlash(impact.CellId, anim);
                }

                if (!impact.Hit && !impact.Dissipated)
                {
                    continue;
                }

                var decision = _cues.Observe(impact.Id, impact.Hit, impact.Dissipated, anim);
                if (!decision.Show || (!decision.BeginHit && !decision.BeginFade))
                {
                    continue;
                }

                var visual = FindOrCreate(impact.Id, art);
                var world = Lifted(impact.X, impact.Y, 1f);
                Place(visual, world, null, art, anim, trailTime);
                ApplyCue(visual, decision, world, anim, art);
            }

            var drop = _cues.EndFrame(anim);
            for (var i = 0; i < drop.Count; i++)
            {
                DropSword(drop[i]);
            }

            UpdateFades(anim);
            UpdateHits(anim, art);
        }

        private void ApplyCue(SwordVisual visual, SwordCueTrack.Decision decision, Vector3 world, float anim, BattleArt art)
        {
            if (decision.BeginHit)
            {
                BeginHit(visual, world, anim, art);
            }
            else if (decision.BeginFade)
            {
                BeginFade(visual, anim);
            }
        }

        private Vector3 DisplayWorld(
            SwordView sword,
            BattleSnapshot snapshot,
            PathCurve path,
            double projectileSpeed,
            float alpha,
            out float progress)
        {
            var arrived = sword.HitThisTick || sword.DissipatedThisTick || !sword.Active;
            double nextX = sword.X;
            double nextY = sword.Y;
            var aimX = sword.AimX;
            var aimY = sword.AimY;
            if (!arrived && path != null)
            {
                Predict(sword, snapshot, path, projectileSpeed, out nextX, out nextY, out aimX, out aimY);
            }

            var t = arrived ? 1f : Mathf.Clamp01(alpha);
            var x = sword.X + ((nextX - sword.X) * t);
            var y = sword.Y + ((nextY - sword.Y) * t);
            var step = Distance(sword.X, sword.Y, x, y);
            var remain = Distance(x, y, aimX, aimY);
            var traveled = sword.Traveled + step;
            var denom = traveled + remain;
            progress = denom <= 1e-8 ? 1f : (float)(traveled / denom);
            if (arrived)
            {
                progress = 1f;
            }

            return Lifted(x, y, progress);
        }

        private Vector3 Lifted(double x, double y, float progress)
        {
            var world = _toWorld(x, y);
            var lift = SpawnLift + ((HitLift - SpawnLift) * Mathf.Clamp01(progress));
            world.y += lift;
            return world;
        }

        private static void Predict(
            SwordView sword,
            BattleSnapshot snapshot,
            PathCurve path,
            double projectileSpeed,
            out double nextX,
            out double nextY,
            out double aimX,
            out double aimY)
        {
            aimX = sword.AimX;
            aimY = sword.AimY;
            if (!sword.TargetLost)
            {
                EnemyView enemy = null;
                var enemies = snapshot.Enemies;
                for (var i = 0; i < enemies.Count; i++)
                {
                    if (enemies[i].InstanceId == sword.TargetId)
                    {
                        enemy = enemies[i];
                        break;
                    }
                }

                if (enemy != null)
                {
                    var distance = enemy.Distance + enemy.Speed;
                    if (distance + 1e-6 >= path.Length)
                    {
                        var end = path.Sample(path.Length);
                        aimX = end.X;
                        aimY = end.Y;
                    }
                    else
                    {
                        var point = path.Sample(distance);
                        aimX = point.X;
                        aimY = point.Y;
                    }
                }
            }

            var dx = aimX - sword.X;
            var dy = aimY - sword.Y;
            var dist = Math.Sqrt((dx * dx) + (dy * dy));
            if (dist <= projectileSpeed + 1e-9)
            {
                nextX = aimX;
                nextY = aimY;
                return;
            }

            var scale = projectileSpeed / dist;
            nextX = sword.X + (dx * scale);
            nextY = sword.Y + (dy * scale);
        }

        private void Place(SwordVisual visual, Vector3 world, SwordView sword, BattleArt art, float anim, float trailTime)
        {
            if (visual.SpawnAnim <= -0.5f)
            {
                visual.SpawnAnim = anim;
            }

            var dx = world.x - visual.LastWorld.x;
            var dy = world.y - visual.LastWorld.y;
            if (visual.HasLast && (dx * dx) + (dy * dy) > 1e-8f)
            {
                visual.Facing = Mathf.Atan2(dy, dx) * Mathf.Rad2Deg;
            }

            visual.HasLast = true;
            visual.LastWorld = world;
            visual.Root.position = world;
            visual.Root.rotation = Quaternion.Euler(0f, 0f, visual.Facing);
            if (visual.Trail != null)
            {
                visual.Trail.time = trailTime;
            }

            var shown = sword == null || (!sword.HitThisTick && visual.FadeStart < 0f);
            var fadeIn = 1f;
            if (anim - visual.SpawnAnim < FadeInSeconds)
            {
                fadeIn = Mathf.Clamp01((anim - visual.SpawnAnim) / FadeInSeconds);
            }

            if (visual.Sword != null)
            {
                visual.Sword.enabled = shown;
                var frame = SwordSprite(art, anim - visual.SpawnAnim);
                if (frame != null)
                {
                    visual.Sword.sprite = frame;
                }

                var tint = visual.Sword.sprite == _pixel
                    ? new Color(0.96f, 0.82f, 0.28f, fadeIn)
                    : new Color(1f, 1f, 1f, fadeIn);
                visual.Sword.color = tint;
                visual.Sword.sortingOrder = BattleSpriteView.SortFx;
            }

            if (visual.Afterimage != null)
            {
                visual.Afterimage.enabled = shown && art != null && art.SwordAfterimage != null;
                visual.Afterimage.color = new Color(1f, 1f, 1f, fadeIn);
                visual.Afterimage.sortingOrder = BattleSpriteView.SortFx - 1;
            }
        }

        private static Sprite SwordSprite(BattleArt art, float age)
        {
            if (art != null && art.SwordShimmer != null && art.SwordShimmer.Length > 0)
            {
                var frame = Mathf.FloorToInt(age * ShimmerFps);
                if (frame < 0)
                {
                    frame = 0;
                }

                return art.SwordShimmer[frame % art.SwordShimmer.Length];
            }

            if (art != null && art.Sword != null)
            {
                return art.Sword;
            }

            return null;
        }

        private void BeginHit(SwordVisual visual, Vector3 world, float anim, BattleArt art)
        {
            visual.Ending = true;
            if (visual.Sword != null)
            {
                visual.Sword.enabled = false;
            }

            if (visual.Afterimage != null)
            {
                visual.Afterimage.enabled = false;
            }

            if (visual.Trail != null)
            {
                visual.Trail.emitting = false;
            }

            visual.FadeStart = anim;
            SpawnHit(world, anim, art);
        }

        private void BeginFade(SwordVisual visual, float anim)
        {
            if (visual.FadeStart >= 0f)
            {
                return;
            }

            visual.Ending = true;
            visual.FadeStart = anim;
            if (visual.Trail != null)
            {
                visual.Trail.emitting = false;
            }
        }

        private void UpdateFades(float anim)
        {
            for (var i = _swords.Count - 1; i >= 0; i--)
            {
                var visual = _swords[i];
                if (visual.FadeStart < 0f)
                {
                    continue;
                }

                var age = anim - visual.FadeStart;
                var alpha = 1f - (age / FadeSeconds);
                if (visual.Sword != null && visual.Sword.enabled)
                {
                    var rgb = visual.Sword.sprite == _pixel
                        ? new Color(0.96f, 0.82f, 0.28f, 1f)
                        : Color.white;
                    visual.Sword.color = new Color(rgb.r, rgb.g, rgb.b, Mathf.Clamp01(alpha));
                }

                if (visual.Afterimage != null && visual.Afterimage.enabled)
                {
                    visual.Afterimage.color = new Color(1f, 1f, 1f, Mathf.Clamp01(alpha));
                }
            }
        }

        private void DropSword(int id)
        {
            for (var i = _swords.Count - 1; i >= 0; i--)
            {
                if (_swords[i].Id != id)
                {
                    continue;
                }

                DestroySword(_swords[i]);
                _swords.RemoveAt(i);
            }
        }

        private void DropAllSwords()
        {
            for (var i = _swords.Count - 1; i >= 0; i--)
            {
                DestroySword(_swords[i]);
                _swords.RemoveAt(i);
            }
        }

        private void SpawnHit(Vector3 world, float anim, BattleArt art)
        {
            var sprite = art != null && art.SwordHit != null && art.SwordHit.Length > 0 ? art.SwordHit[0] : _pixel;
            var go = new GameObject("ProjJinHit");
            go.transform.SetParent(_root, false);
            go.transform.position = world;
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.sortingOrder = BattleSpriteView.SortFx + 1;
            if (sprite == _pixel)
            {
                go.transform.localScale = new Vector3(0.45f, 0.45f, 1f);
                renderer.color = new Color(0.98f, 0.93f, 0.82f, 1f);
            }

            _hits.Add(new HitVisual { Renderer = renderer, Start = anim });
        }

        private void UpdateHits(float anim, BattleArt art)
        {
            var frames = art != null ? art.SwordHit : null;
            for (var i = _hits.Count - 1; i >= 0; i--)
            {
                var hit = _hits[i];
                if (hit.Renderer == null)
                {
                    _hits.RemoveAt(i);
                    continue;
                }

                var age = anim - hit.Start;
                var frame = Mathf.FloorToInt(age * HitFps);
                var count = frames != null && frames.Length > 0 ? frames.Length : 3;
                if (frame < 0 || frame >= count || age < 0f)
                {
                    UnityEngine.Object.Destroy(hit.Renderer.gameObject);
                    _hits.RemoveAt(i);
                    continue;
                }

                if (frames != null && frame < frames.Length)
                {
                    hit.Renderer.sprite = frames[frame];
                }
            }
        }

        private SwordVisual FindOrCreate(int id, BattleArt art)
        {
            for (var i = 0; i < _swords.Count; i++)
            {
                if (_swords[i].Id == id)
                {
                    return _swords[i];
                }
            }

            var root = new GameObject("ProjJinSword-" + id);
            root.transform.SetParent(_root, false);
            var swordRenderer = root.AddComponent<SpriteRenderer>();
            swordRenderer.sortingOrder = BattleSpriteView.SortFx;
            var swordSprite = art != null && art.Sword != null ? art.Sword : _pixel;
            swordRenderer.sprite = swordSprite;
            if (swordSprite == _pixel)
            {
                root.transform.localScale = new Vector3(0.8f, 0.233f, 1f);
                swordRenderer.color = new Color(0.96f, 0.82f, 0.28f, 1f);
            }

            SpriteRenderer after = null;
            if (art != null && art.SwordAfterimage != null)
            {
                var afterGo = new GameObject("Afterimage");
                afterGo.transform.SetParent(root.transform, false);
                after = afterGo.AddComponent<SpriteRenderer>();
                after.sprite = art.SwordAfterimage;
                after.sortingOrder = BattleSpriteView.SortFx - 1;
            }

            TrailRenderer trail = null;
            Material trailMaterial = null;
            if (art != null && art.SwordTrail != null)
            {
                var emit = new GameObject("TrailEmit");
                emit.transform.SetParent(root.transform, false);
                emit.transform.localPosition = new Vector3(HiltLocalX, 0f, 0f);
                trail = emit.AddComponent<TrailRenderer>();
                trail.time = TrailSeconds;
                trail.minVertexDistance = TrailMinVertex;
                trail.widthMultiplier = TrailWidth;
                trail.widthCurve = AnimationCurve.Linear(0f, 1f, 1f, 1f);
                trail.textureMode = LineTextureMode.Stretch;
                trail.alignment = LineAlignment.View;
                trail.numCapVertices = 0;
                trail.numCornerVertices = 0;
                trail.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                trail.receiveShadows = false;
                trail.sortingOrder = BattleSpriteView.SortFx - 2;
                var shader = swordRenderer.sharedMaterial != null ? swordRenderer.sharedMaterial.shader : Shader.Find("Sprites/Default");
                if (shader != null)
                {
                    trailMaterial = new Material(shader);
                    trailMaterial.mainTexture = art.SwordTrail;
                    trail.material = trailMaterial;
                    _materials.Add(trailMaterial);
                }
            }

            var visual = new SwordVisual
            {
                Id = id,
                Root = root.transform,
                Sword = swordRenderer,
                Afterimage = after,
                Trail = trail,
                TrailMaterial = trailMaterial,
                SpawnAnim = -1f,
            };
            _swords.Add(visual);
            return visual;
        }

        private void DestroySword(SwordVisual visual)
        {
            if (visual.TrailMaterial != null)
            {
                _materials.Remove(visual.TrailMaterial);
                UnityEngine.Object.Destroy(visual.TrailMaterial);
            }

            if (visual.Root != null)
            {
                UnityEngine.Object.Destroy(visual.Root.gameObject);
            }
        }

        private static double Distance(double ax, double ay, double bx, double by)
        {
            var dx = bx - ax;
            var dy = by - ay;
            return Math.Sqrt((dx * dx) + (dy * dy));
        }
    }
}
