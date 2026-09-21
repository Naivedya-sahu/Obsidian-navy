// seed-test.cs — regression guard for OpenVault.SeedMissing.
// The no-clobber rule is the only thing standing between "with plugins" and
// flattening someone's existing .obsidian config, so it gets a real test
// against the real function. Compiles the shipping source, picks this Main:
//
//   csc.exe /target:exe /main:SeedTest /out:seed-test.exe ^
//     /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll ^
//     open-vault.cs seed-test.cs
//   seed-test.exe

using System;
using System.IO;

internal static class SeedTest
{
    private static void Assert(bool ok, string what)
    {
        Console.WriteLine((ok ? "  ok   " : "  FAIL ") + what);
        if (!ok) Environment.Exit(1);
    }

    private static int Main()
    {
        string root = Path.Combine(Path.GetTempPath(), "seed-test-" + Guid.NewGuid().ToString("N"));
        string src = Path.Combine(root, "Template");
        string dst = Path.Combine(root, "dot-obsidian");
        try
        {
            Directory.CreateDirectory(Path.Combine(src, "plugins", "dataview"));
            Directory.CreateDirectory(Path.Combine(src, "themes", "Typewriter"));
            File.WriteAllText(Path.Combine(src, "appearance.json"), "TEMPLATE");
            File.WriteAllText(Path.Combine(src, "core-plugins.json"), "TEMPLATE");
            File.WriteAllText(Path.Combine(src, "plugins", "dataview", "main.js"), "TEMPLATE");
            File.WriteAllText(Path.Combine(src, "themes", "Typewriter", "theme.css"), "TEMPLATE");

            // Target already looks like a vault the user has configured themselves.
            Directory.CreateDirectory(dst);
            File.WriteAllText(Path.Combine(dst, "appearance.json"), "MINE");

            OpenVault.SeedMissing(src, dst);

            Assert(File.ReadAllText(Path.Combine(dst, "appearance.json")) == "MINE",
                   "existing file is not overwritten");
            Assert(File.Exists(Path.Combine(dst, "core-plugins.json")),
                   "missing top-level file is copied");
            Assert(File.Exists(Path.Combine(dst, "plugins", "dataview", "main.js")),
                   "nested plugin file is copied");
            Assert(File.Exists(Path.Combine(dst, "themes", "Typewriter", "theme.css")),
                   "nested theme file is copied");

            // Second run must be a no-op, not a crash: re-seeding an already-seeded
            // vault is the normal case once a folder has been opened before.
            File.WriteAllText(Path.Combine(dst, "plugins", "dataview", "main.js"), "PATCHED");
            OpenVault.SeedMissing(src, dst);
            Assert(File.ReadAllText(Path.Combine(dst, "plugins", "dataview", "main.js")) == "PATCHED",
                   "re-seed leaves an edited nested file alone");

            // Seeding a folder with no .obsidian at all must create the whole tree.
            string fresh = Path.Combine(root, "fresh");
            OpenVault.SeedMissing(src, fresh);
            Assert(File.ReadAllText(Path.Combine(fresh, "appearance.json")) == "TEMPLATE",
                   "fresh target gets the full template");

            Console.WriteLine("PASS");
            return 0;
        }
        finally
        {
            try { Directory.Delete(root, true); } catch { /* temp dir, leave it */ }
        }
    }
}
