state("EasyDeliveryCo") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.LoadSceneManager = true;
    Assembly.Load(File.ReadAllBytes("Components/uhara7")).CreateInstance("Main");

    settings.Add("resetOnMainMenu", false, "Reset when returning to the main menu (you don't want this for 100%+ runs)");
    settings.Add("splitOnEndings", true, "Split when a different ending is triggered");
    settings.Add("splitOnBobbles", false, "Split when a new bobblehead is collected (2 cats under the bridge count as 1 split)");

    settings.Add("splitOnTravel", false, "Split when traveling to a different area");
    var travelPairs = new List<Tuple<string, string>>()
    {
        Tuple.Create("MountainTown", "SnowyPeaks"),
        Tuple.Create("SnowyPeaks", "MountainTown"),
        Tuple.Create("MountainTown", "FishingTown"),
        Tuple.Create("FishingTown", "MountainTown"),
        Tuple.Create("MountainTown", "Factory"),
        Tuple.Create("Factory", "MountainTown"),
        Tuple.Create("Factory", "FactoryInside"),
        Tuple.Create("FactoryInside", "Factory"),
        Tuple.Create("FishingTown", "DamInside"),
        Tuple.Create("DamInside", "FishingTown"),
    };
    foreach (var pair in travelPairs)
    {
        settings.Add("travel_" + pair.Item1 + "_" + pair.Item2, false, "From " + pair.Item1 + " to " + pair.Item2, "splitOnTravel");
    }

    settings.Add("splitOnTruckUpgrades", false, "Split when a truck upgrade is acquired");
    vars.possibleTruckUpgrades = new string[] { "SnowTires", "Bumper", "IceChains" };
    for (var i = 0; i < vars.possibleTruckUpgrades.Length; i++) {
        settings.Add("truckUpgrade_" + vars.possibleTruckUpgrades[i], false, vars.possibleTruckUpgrades[i], "splitOnTruckUpgrades");
    }
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
        IntPtr enableSnowcatFlag = jitSave.AddFlag("SnowcatManager", "EnableSnowcat");
        IntPtr snowcatManager = jitSave.AddInst("SnowcatManager");
        IntPtr truckUpgradesManager = jitSave.AddInst("TruckUpgrades", "LateUpdate");
        IntPtr truckUpgradeMakePaymentFlag = jitSave.AddFlag("UpgradeCheckout", "MakePayment");
        jitSave.ProcessQueue();

        vars.Helper["loadIntro"] = vars.Helper.Make<int>(loadIntroFlag);
        vars.Helper["enableSnowcat"] = vars.Helper.Make<int>(enableSnowcatFlag);
        vars.Helper["displayBobble"] = vars.Helper.Make<int>(snowcatManager, 0x70); // SnowcatManager -> displayBobble

        vars.truckUpgradeWatchers = new MemoryWatcher[vars.possibleTruckUpgrades.Length];
        vars.Helper["upgradeMakePaymentCallCount"] = vars.Helper.Make<int>(truckUpgradeMakePaymentFlag);
        vars.truckUpgradeWatchers[0] = vars.Helper["truckHasTires"] = vars.Helper.Make<bool>(truckUpgradesManager, 0x58); // TruckUpgrades -> .hasTires
        vars.truckUpgradeWatchers[1] = vars.Helper["truckHasBumper"] = vars.Helper.Make<bool>(truckUpgradesManager, 0x59); // TruckUpgrades -> .hasBumper
        vars.truckUpgradeWatchers[2] = vars.Helper["truckHasChains"] = vars.Helper.Make<bool>(truckUpgradesManager, 0x5B); // TruckUpgrades -> .hasChains

        return true;
    });

    vars.endingsAchieved = new List<int>();
    vars.bobblesCollected = new List<int>();
    vars.shouldTrackNextBobble = false;
    vars.upgradesAcquired = new bool[vars.possibleTruckUpgrades.Length];
    vars.shouldTrackNextTruckUpgrade = false;
}

onStart {
    vars.endingsAchieved.Clear();
    vars.bobblesCollected.Clear();
    vars.shouldTrackNextBobble = false;
    for (var i = 0; i < vars.upgradesAcquired.Length; i++) {
        vars.upgradesAcquired[i] = false;
    }
    vars.shouldTrackNextTruckUpgrade = false;
    vars.Log("Run started");
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
    if (old.enableSnowcat != current.enableSnowcat) {
        vars.Log("enableSnowcat: " + old.enableSnowcat + " -> " + current.enableSnowcat);
        if (current.enableSnowcat > 0 && current.enableSnowcat > old.enableSnowcat) {
            vars.shouldTrackNextBobble = true;
        } else {
            vars.shouldTrackNextBobble = false;
        }
    }
    if (old.displayBobble != current.displayBobble) {
        vars.Log("displayBobble: " + old.displayBobble + " -> " + current.displayBobble);
    }
    if (old.truckHasTires != current.truckHasTires) {
        vars.Log("truckHasTires: " + old.truckHasTires + " -> " + current.truckHasTires);
    }
    if (old.truckHasBumper != current.truckHasBumper) {
        vars.Log("truckHasBumper: " + old.truckHasBumper + " -> " + current.truckHasBumper);
    }
    if (old.truckHasChains != current.truckHasChains) {
        vars.Log("truckHasChains: " + old.truckHasChains + " -> " + current.truckHasChains);
    }
    if (old.upgradeMakePaymentCallCount != current.upgradeMakePaymentCallCount) {
        vars.Log("upgradeMakePaymentCallCount: " + old.upgradeMakePaymentCallCount + " -> " + current.upgradeMakePaymentCallCount);
        if (
            current.upgradeMakePaymentCallCount > 0 && current.upgradeMakePaymentCallCount > old.upgradeMakePaymentCallCount
            && (current.activeScene == "MountainTown" || current.activeScene == "FishingTown" || current.activeScene == "SnowyPeaks")
        ) {
            vars.shouldTrackNextTruckUpgrade = true;
        } else {
            vars.shouldTrackNextTruckUpgrade = false;
        }
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
    if (
        settings["splitOnEndings"]
        && current.activeScene == "Ending"
        && current.currentEnding != old.currentEnding
        && current.currentEnding >= 1 && current.currentEnding <= 3
        && !vars.endingsAchieved.Contains(current.currentEnding)
    ) {
        vars.endingsAchieved.Add(current.currentEnding);
        vars.Log("Achieved ending #" + current.currentEnding + ", total achieved: " + vars.endingsAchieved.Count + "/3");
        return true;
    }

    if (
        settings["splitOnBobbles"]
        && vars.shouldTrackNextBobble == true
        && (current.activeScene == "MountainTown" || current.activeScene == "FishingTown" || current.activeScene == "SnowyPeaks")
        && current.displayBobble != old.displayBobble
        && current.displayBobble >= 0 && current.displayBobble <= 12
        && !vars.bobblesCollected.Contains(current.displayBobble)
    ) {
        vars.Log("Collected bobble #" + current.displayBobble);
        vars.bobblesCollected.Add(current.displayBobble);
        vars.shouldTrackNextBobble = false;

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

    if (settings["splitOnTravel"] && current.activeScene != old.activeScene) {
        var travelKey = "travel_" + old.activeScene + "_" + current.activeScene;
        if (settings.ContainsKey(travelKey) && settings[travelKey]) {
            return true;
        }
    }

    if (
        settings["splitOnTruckUpgrades"]
        && vars.shouldTrackNextTruckUpgrade == true
    ) {
        for (var idx = 0; idx < vars.possibleTruckUpgrades.Length; idx++) {
            if (
                vars.truckUpgradeWatchers[idx] != null
                && vars.truckUpgradeWatchers[idx].Current != vars.truckUpgradeWatchers[idx].Old
                && vars.truckUpgradeWatchers[idx].Current == true
                && vars.upgradesAcquired[idx] == false
            ) {
                vars.shouldTrackNextTruckUpgrade = false;

                vars.upgradesAcquired[idx] = true;
                vars.Log("Acquired truck upgrade " + vars.possibleTruckUpgrades[idx]);
                var upgradeKey = "truckUpgrade_" + vars.possibleTruckUpgrades[idx];
                if (settings.ContainsKey(upgradeKey) && settings[upgradeKey]) {
                    return true;
                }
            }
        }
    }
}
