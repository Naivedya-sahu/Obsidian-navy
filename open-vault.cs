// open-vault.cs — Obsidian Context Menu runtime handler
// Invoked directly by: HKCR\Directory\shell\Obsidian\shell\*\command, as:
//   open-vault.exe "<folder>"              plain vault — bare .obsidian, no plugins
//   open-vault.exe --template "<folder>"   seeded vault — plugins + theme from {app}\Template
// Registers the target folder as a permanent Obsidian vault, makes it the sole
// "open": true vault, restarts Obsidian into it.
//
// Native compiled exe, not a script — this machine's PowerShell is unreliable
// (broken module autoloading, .ps1 execution generally flaky), so the runtime
// handler is a plain .NET Framework console/winexe binary instead. Build with
// csc.exe (ships with every Windows .NET Framework install), see README.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class OpenVault
{
    private static void ShowError(string msg)
    {
        MessageBox.Show(msg, "Obsidian Context Menu", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    // Seeds <dst> from <src>, never overwriting a file that already exists. The
    // no-clobber rule is the whole safety story: right-clicking an existing vault
    // with "with plugins" tops up what's missing and leaves the user's own
    // appearance.json / plugin settings / installed plugins untouched.
    internal static void SeedMissing(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (string f in Directory.GetFiles(src))
        {
            string target = Path.Combine(dst, Path.GetFileName(f));
            if (!File.Exists(target)) File.Copy(f, target);
        }
        foreach (string d in Directory.GetDirectories(src))
            SeedMissing(d, Path.Combine(dst, Path.GetFileName(d)));
    }

    private static int Main(string[] args)
    {
        bool useTemplate = false;
        string vp = null;
        foreach (string a in args)
        {
            if (string.Equals(a, "--template", StringComparison.OrdinalIgnoreCase)) useTemplate = true;
            else if (vp == null) vp = a;
        }
        if (string.IsNullOrWhiteSpace(vp)) return 1;
        vp = vp.TrimEnd('\\');

        // Obsidian.exe path is read from the registry Icon value written at install
        // time — single source of truth, not duplicated across binary + registry + installer.
        string obsExe = null;
        using (RegistryKey key = Registry.ClassesRoot.OpenSubKey(@"Directory\shell\Obsidian"))
        {
            if (key != null) obsExe = key.GetValue("Icon") as string;
        }
        if (string.IsNullOrEmpty(obsExe) || !File.Exists(obsExe))
        {
            ShowError("Obsidian.exe not found at:\n" + obsExe + "\n\nReinstall Obsidian Context Menu.");
            return 1;
        }

        string appData = Environment.GetEnvironmentVariable("APPDATA");
        string jsonDir = Path.Combine(appData, "obsidian");
        string jsonPath = Path.Combine(jsonDir, "obsidian.json");
        Directory.CreateDirectory(jsonDir);
        if (!File.Exists(jsonPath))
            File.WriteAllText(jsonPath, "{\"vaults\":{}}", new UTF8Encoding(false));

        // Kill running Obsidian — it must fully exit before obsidian.json is safe to
        // edit, otherwise it overwrites our changes with its own in-memory state on
        // close. Poll for real exit instead of a fixed sleep (old tool's fixed 1s
        // timeout was flaky on slow machines per its own README).
        foreach (Process p in Process.GetProcessesByName("Obsidian"))
        {
            try { p.Kill(); } catch { /* already exiting */ }
        }
        DateTime deadline = DateTime.Now.AddSeconds(10);
        while (Process.GetProcessesByName("Obsidian").Length > 0 && DateTime.Now < deadline)
            Thread.Sleep(300);
        Thread.Sleep(500);

        // .obsidian is written only after Obsidian has fully exited — same reason
        // obsidian.json is: a live Obsidian flushes its own in-memory config on close
        // and would overwrite a seed dropped in underneath it.
        string dotObsidian = Path.Combine(vp, ".obsidian");
        Directory.CreateDirectory(dotObsidian);
        if (useTemplate)
        {
            string template = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Template");
            if (Directory.Exists(template))
            {
                try { SeedMissing(template, dotObsidian); }
                catch (Exception ex)
                {
                    // Partial seed still opens fine as a vault — report and carry on
                    // rather than stranding the user with no Obsidian at all.
                    ShowError("Could not copy the plugin template into:\n" + dotObsidian +
                              "\n\n" + ex.Message + "\n\nOpening the vault anyway.");
                }
            }
            else
                ShowError("Plugin template missing at:\n" + template +
                          "\n\nReinstall Obsidian Context Menu.\n\nOpening the vault without plugins.");
        }

        var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        var config = (Dictionary<string, object>)serializer.DeserializeObject(File.ReadAllText(jsonPath));

        object vaultsObj;
        Dictionary<string, object> vaults;
        if (config.TryGetValue("vaults", out vaultsObj) && vaultsObj != null)
            vaults = (Dictionary<string, object>)vaultsObj;
        else
        {
            vaults = new Dictionary<string, object>();
            config["vaults"] = vaults;
        }

        string targetId = null;
        foreach (string id in new List<string>(vaults.Keys))
        {
            var v = (Dictionary<string, object>)vaults[id];
            object pathObj;
            if (v.TryGetValue("path", out pathObj) && pathObj != null &&
                string.Equals(((string)pathObj).TrimEnd('\\'), vp, StringComparison.OrdinalIgnoreCase))
            {
                targetId = id;
                break;
            }
        }

        if (targetId == null)
        {
            byte[] bytes = new byte[8];
            using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(bytes);
            targetId = BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
            var entry = new Dictionary<string, object>
            {
                { "path", vp },
                { "ts", (double)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() }
            };
            vaults[targetId] = entry;
        }

        foreach (string id in new List<string>(vaults.Keys))
        {
            var v = (Dictionary<string, object>)vaults[id];
            if (id == targetId) v["open"] = true;
            else v.Remove("open");
        }

        File.WriteAllText(jsonPath, serializer.Serialize(config), new UTF8Encoding(false));

        Process.Start(obsExe);
        return 0;
    }
}
