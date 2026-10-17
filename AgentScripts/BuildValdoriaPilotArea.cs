using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Mmorpg.AgentScripts
{
    // Phase 2 pilot area: reads Docs/Art/ValdoriaWorldBlueprint.json and builds the
    // physical layer for the drawn village centre. It adds colliders and occlusion
    // only - it never draws a second copy of the backdrop art.
    public static class BuildValdoriaPilotArea
    {
        private const string Blueprint = "Docs/Art/ValdoriaWorldBlueprint.json";
        private const string Root = "ValdoriaPilotArea";
        private const int ObstacleLayer = 8;

        public static string Build()
        {
            if (EditorApplication.isPlaying) throw new System.InvalidOperationException("Stop Play before building the pilot area");
            if (!File.Exists(Blueprint)) throw new FileNotFoundException("Blueprint missing", Blueprint);

            var json = JObject.Parse(File.ReadAllText(Blueprint));
            var objects = (JArray)json["objects"] ?? new JArray();

            var existing = GameObject.Find(Root);
            if (existing != null) Object.DestroyImmediate(existing);

            var parent = new GameObject(Root);
            var report = new List<string>();

            foreach (var o in objects)
            {
                string id = (string)o["id"];
                var pos = (JArray)o["position"];
                if (pos == null || pos.Type != JTokenType.Array)
                {
                    report.Add(id + ": no static position (route/terrain) - skipped");
                    continue;
                }

                var anchor = new Vector2((float)pos[0], (float)pos[1]);
                var footprint = o["collisionFootprint"];
                var go = new GameObject(id);
                go.transform.SetParent(parent.transform, false);
                go.transform.position = new Vector3(anchor.x, anchor.y, 0f);
                go.layer = ObstacleLayer;

                int order = (int?)o["sortingOrder"] ?? 0;
                string note = (string)footprint?["collisionNote"] ?? (string)o["collisionNote"];

                string shape = (string)footprint?["shape"];
                if (shape == "circle")
                {
                    var col = go.AddComponent<CircleCollider2D>();
                    col.radius = (float)footprint["radius"];
                    var off = footprint["offset"];
                    if (off != null) col.offset = new Vector2((float)off[0], (float)off[1]);
                    report.Add($"{id}: CircleCollider2D r={col.radius} at {anchor}");
                }
                else if (shape == "box")
                {
                    var col = go.AddComponent<BoxCollider2D>();
                    var he = (JArray)footprint["halfExtents"];
                    col.size = new Vector2((float)he[0] * 2f, (float)he[1] * 2f);
                    var off = footprint["offset"];
                    if (off != null) col.offset = new Vector2((float)off[0], (float)off[1]);
                    report.Add($"{id}: BoxCollider2D size={col.size} offset={col.offset} at {anchor}");
                }
                else
                {
                    report.Add($"{id}: no collider ({shape ?? "none"})");
                }

                var marker = go.AddComponent<WorldObjectMarker>();
                marker.Configure(id, (string)o["type"], order, note);
            }

            EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
            return string.Join("\n", report);
        }
    }

    // Lightweight tag so the pilot objects stay identifiable and re-buildable.
    public sealed class WorldObjectMarker : MonoBehaviour
    {
        [SerializeField] private string id;
        [SerializeField] private string kind;
        [SerializeField] private int sortingOrder;
        [SerializeField] private string note;
        public string Id => id;
        public string Kind => kind;
        public int SortingOrder => sortingOrder;
        public string Note => note;
        public void Configure(string value, string type, int order, string comment)
        { id = value; kind = type; sortingOrder = order; note = comment; }
    }
}
