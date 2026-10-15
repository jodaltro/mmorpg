using UnityEngine;
using UnityEngine.UI;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using Mmorpg.Runtime;

public static class ConfigureActionDebug
{
    public static string Main()
    {
        if(EditorApplication.isPlaying) throw new System.InvalidOperationException("Stop Play first.");
        var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        if(scene.path != "Assets/Mmorpg/Scenes/ActionVerticalSlice.unity")
            throw new System.InvalidOperationException("Open ActionVerticalSlice first.");
        if(Object.FindAnyObjectByType<ActionDebugPanel>() != null)
        {
            var existing = GameObject.Find("ActionDebug");
            existing.GetComponent<RectTransform>().sizeDelta = new Vector2(310,145);
            var existingText = existing.GetComponentInChildren<TMP_Text>();
            existingText.fontSize = 11;
            existingText.overflowMode = TextOverflowModes.Ellipsis;
            EditorUtility.SetDirty(existing);
            EditorUtility.SetDirty(existingText);
            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene);
            return "Debug resized to 310x145.";
        }
        var canvas = Object.FindAnyObjectByType<Canvas>();
        var font = Object.FindAnyObjectByType<TMP_Text>().font;
        var root = new GameObject("ActionDebug", typeof(RectTransform), typeof(Image));
        root.transform.SetParent(canvas.transform, false);
        var rect = root.GetComponent<RectTransform>();
        rect.anchorMin = rect.anchorMax = new Vector2(1,1);
        rect.pivot = new Vector2(1,1);
        rect.anchoredPosition = new Vector2(-12,-88);
        rect.sizeDelta = new Vector2(310,145);
        var image = root.GetComponent<Image>();
        image.color = new Color(.015f,.025f,.035f,.9f); image.raycastTarget = false;
        var label = new GameObject("Trace", typeof(RectTransform), typeof(TextMeshProUGUI));
        label.transform.SetParent(root.transform,false);
        var textRect = label.GetComponent<RectTransform>();
        textRect.anchorMin = Vector2.zero; textRect.anchorMax = Vector2.one;
        textRect.offsetMin = new Vector2(12,12); textRect.offsetMax = new Vector2(-12,-12);
        var text = label.GetComponent<TextMeshProUGUI>();
        text.font = font; text.fontSize = 11; text.color = new Color(.7f,1,.8f);
        text.overflowMode = TextOverflowModes.Ellipsis;
        text.raycastTarget = false; text.richText = false;
        text.text = "DEBUG ATIVO — F8 mostra/oculta";
        var host = new GameObject("ActionDebugController");
        host.AddComponent<ActionDebugPanel>().Configure(Object.FindAnyObjectByType<JourneySession>(), Object.FindAnyObjectByType<OfflineAuthority>(), root, text);
        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
        return "Debug installed and visible; F8 toggles.";
    }
}
