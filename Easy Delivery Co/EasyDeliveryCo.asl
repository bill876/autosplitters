state("EasyDeliveryCo") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.LoadSceneManager = true;
    Assembly.Load(File.ReadAllBytes("Components/uhara7")).CreateInstance("Main");

    settings.Add("resetOnMainMenu", false, "Reset when returning to the main menu (you don't want this for 100%+ runs)");
    settings.Add("splitEndings", true, "Split when a different ending is triggered");
    settings.Add("splitBobbles", false, "Split when a new bobblehead is collected (2 cats under the bridge count as 1 split)");
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var endingManager = mono["EndingManager"];
        vars.Helper["currentEnding"] = mono.Make<int>(
            endingManager,
            "instance",
            endingManager["currentEnding"]
        );

        var jitSave = vars.Uhara.CreateTool("Unity", "DotNet", "JitSave");
        IntPtr loadIntroFlag = jitSave.AddFlag("IntroDotExe", "LoadIntro");
        var snowcatManager = jitSave.AddInst("SnowcatManager");
        jitSave.ProcessQueue();

        vars.Helper["loadIntro"] = vars.Helper.Make<int>(loadIntroFlag);
        vars.Helper["displayBobble"] = vars.Helper.Make<int>(snowcatManager, 0x70); // .displayBobble

        return true;
    });

    vars.bobblesCollected = new List<int>();
}

onStart {
    vars.Log("Run started");
    vars.bobblesCollected.Clear();
}

update
{
    current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;

    if (old.activeScene != current.activeScene) {
        vars.Log("activeScene: " + old.activeScene + " -> " + current.activeScene);
    }

    if (old.currentEnding != current.currentEnding) {
        vars.Log("currentEnding: " + old.currentEnding + " -> " + current.currentEnding);
    }

    if (old.loadIntro != current.loadIntro) {
        vars.Log("loadIntro: " + old.loadIntro + " -> " + current.loadIntro);
    }

    if (old.displayBobble != current.displayBobble) {
        vars.Log("displayBobble: " + old.displayBobble + " -> " + current.displayBobble);
    }
}

reset
{
    if (settings["resetOnMainMenu"] && current.activeScene == "TitleScreen" && old.activeScene != "TitleScreen") {
        return true;
    }
}

start
{
    if (current.activeScene == "TitleScreen" && current.loadIntro > 0 && current.loadIntro > old.loadIntro) {
        return true;
    }
}

split
{
    if (settings["splitEndings"] && current.activeScene == "Ending" && current.currentEnding != old.currentEnding) {
        return true;
    }
    if (
        settings["splitBobbles"]
        && current.activeScene != "TitleScreen"
        && current.displayBobble != old.displayBobble
        && current.displayBobble >= 0 && current.displayBobble <= 12
        && !vars.bobblesCollected.Contains(current.displayBobble)
    ) {
        vars.Log("Collected bobble #" + current.displayBobble);
        vars.bobblesCollected.Add(current.displayBobble);

        // For most bobbles, we just split
        if (current.displayBobble != 2 && current.displayBobble != 3) {
            return true;
        }
        // For the pair under the bridge, we only split if we have both
        if (vars.bobblesCollected.Contains(2) && vars.bobblesCollected.Contains(3)) {
            return true;
        }

        // 0 = MT Upton
        // 1 = MT Weston Buildings
        // 2 = FT Bridge (left)
        // 3 = FT Bridge (right)
        // 4 = SP Munton
        // 5 = MT Radio Tower
        // 6 = FT Gate
        // 7 = SP Winton
        // 8 = SP Lopton
        // 9 = MT Easton Roof
        // 10 = FT Lake
        // 11 = MT Depot Roof
        // 12 = SP Radio Tower
    }
}
