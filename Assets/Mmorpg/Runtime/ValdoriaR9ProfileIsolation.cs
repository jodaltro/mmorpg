using System.IO;
using UnityEngine;

namespace Mmorpg.Runtime
{
    [DefaultExecutionOrder(-10000)]
    public sealed class ValdoriaR9ProfileIsolation : MonoBehaviour
    {
        private string previous;
        private string assigned;

        private void Awake()
        {
            previous = LocalJourneyProfile.ValidationRootOverride;
            assigned = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "Temp/ValdoriaEnvironmentR9/IsolatedProfile"));
            Directory.CreateDirectory(assigned);
            LocalJourneyProfile.ValidationRootOverride = assigned;
        }

        private void OnDestroy()
        {
            if (LocalJourneyProfile.ValidationRootOverride == assigned)
                LocalJourneyProfile.ValidationRootOverride = previous;
        }
    }
}
