using System;
using System.Collections.Generic;
using ShanhaiDingGuard.Content;

namespace ShanhaiDingGuard.Gameplay.Path
{
    /// <summary>
    /// 折线路径。距离是关卡 space 上的欧氏长度（冀州 01 为 height_units_16x9 的高度单位），敌人只沿折线前进。
    /// </summary>
    public sealed class PathCurve
    {
        public readonly struct Point
        {
            public readonly double X;
            public readonly double Y;

            public Point(double x, double y)
            {
                X = x;
                Y = y;
            }
        }

        private readonly List<Point> _points;
        private readonly double[] _cumulative;

        public PathCurve(IReadOnlyList<WaypointDefinition> waypoints)
        {
            if (waypoints == null || waypoints.Count < 2)
            {
                throw new ArgumentException("路径至少需要两个点");
            }

            _points = new List<Point>(waypoints.Count);
            _cumulative = new double[waypoints.Count];
            _points.Add(new Point(waypoints[0].X, waypoints[0].Y));
            _cumulative[0] = 0;
            double length = 0;
            for (var i = 1; i < waypoints.Count; i++)
            {
                var dx = waypoints[i].X - waypoints[i - 1].X;
                var dy = waypoints[i].Y - waypoints[i - 1].Y;
                length += Math.Sqrt((dx * dx) + (dy * dy));
                _points.Add(new Point(waypoints[i].X, waypoints[i].Y));
                _cumulative[i] = length;
            }

            if (length <= 0)
            {
                throw new ArgumentException("路径长度必须大于 0");
            }

            Length = length;
        }

        public double Length { get; }

        public Point Sample(double distance)
        {
            if (distance <= 0)
            {
                return _points[0];
            }

            if (distance >= Length)
            {
                return _points[_points.Count - 1];
            }

            for (var i = 1; i < _cumulative.Length; i++)
            {
                if (distance <= _cumulative[i])
                {
                    var span = _cumulative[i] - _cumulative[i - 1];
                    var t = span <= 0 ? 0 : (distance - _cumulative[i - 1]) / span;
                    var a = _points[i - 1];
                    var b = _points[i];
                    return new Point(a.X + ((b.X - a.X) * t), a.Y + ((b.Y - a.Y) * t));
                }
            }

            return _points[_points.Count - 1];
        }
    }
}
