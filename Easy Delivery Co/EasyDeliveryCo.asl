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

    settings.Add("splitOnRestoreGoalCompleted", false, "Split when the \"Restore\" goal is completed (checked off in the goals menu)");
    vars.mainGoalNames = new string[] { // names and indexes match the game
        "Make a Delivery",
        "Energy Drink",
        "Lighter",
        "Cabin in Snowy Peaks",
        "Snow Tires",
        "Fishing Town",
        "Radio Towers",
        "Security Gate",
        "Bumper Bar",
        "Hydro Dam",
        "Supplies",
        "Ice Chains",
        "Factory",
        "Restore",
    };
    vars.sideGoalNames = new string[] {
        "Cooking Pot",
        "Brew Coffee",
        "Fishing Rod",
        "Fish Soup",
    };
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
        IntPtr goalsManager = jitSave.AddInst("sGoals");
        IntPtr goalsCompleteGoalFlag = jitSave.AddFlag("sGoals", "CompleteGoal");
        jitSave.ProcessQueue();

        vars.Helper["loadIntro"] = vars.Helper.Make<int>(loadIntroFlag);
        vars.Helper["enableSnowcat"] = vars.Helper.Make<int>(enableSnowcatFlag);
        vars.Helper["displayBobble"] = vars.Helper.Make<int>(snowcatManager, 0x70); // SnowcatManager -> displayBobble

        vars.Helper["upgradeMakePaymentCallCount"] = vars.Helper.Make<int>(truckUpgradeMakePaymentFlag);
        vars.truckUpgradeWatchers = new MemoryWatcher[vars.possibleTruckUpgrades.Length];
        vars.truckUpgradeWatchers[0] = vars.Helper["truckHasTires"] = vars.Helper.Make<bool>(truckUpgradesManager, 0x58); // TruckUpgrades -> .hasTires
        vars.truckUpgradeWatchers[1] = vars.Helper["truckHasBumper"] = vars.Helper.Make<bool>(truckUpgradesManager, 0x59); // TruckUpgrades -> .hasBumper
        vars.truckUpgradeWatchers[2] = vars.Helper["truckHasChains"] = vars.Helper.Make<bool>(truckUpgradesManager, 0x5B); // TruckUpgrades -> .hasChains

        vars.Helper["goalsCompleteGoalCallCount"] = vars.Helper.Make<int>(goalsCompleteGoalFlag);
        vars.mainGoalsCompletedWatchers = new MemoryWatcher[vars.mainGoalNames.Length];
        for (var i = 0; i < vars.mainGoalNames.Length; i++) {
            vars.mainGoalsCompletedWatchers[i] = vars.Helper["mainGoalCompleted_" + i] = vars.Helper.Make<bool>(goalsManager, 0x38, 0x20 + i * 0x8, 0x41); // sGoals -> goals -> [i] -> complete
        }

        vars.sideGoalsCompletedWatchers = new MemoryWatcher[vars.sideGoalNames.Length];
        for (var i = 0; i < vars.sideGoalNames.Length; i++) {
            vars.sideGoalsCompletedWatchers[i] = vars.Helper["sideGoalCompleted_" + i] = vars.Helper.Make<bool>(goalsManager, 0x40, 0x20 + i * 0x8, 0x41); // sGoals -> sideGoals -> [i] -> complete
        }

        return true;
    });

    vars.endingsAchieved = new List<int>();
    vars.bobblesCollected = new List<int>();
    vars.shouldTrackNextBobble = false;
    vars.upgradesAcquired = new bool[vars.possibleTruckUpgrades.Length];
    vars.shouldTrackNextTruckUpgrade = false;
    vars.mainGoalsCompleted = new List<int>();
    vars.shouldTrackNextGoalCompletion = false;
}

onStart {
    vars.endingsAchieved.Clear();
    vars.bobblesCollected.Clear();
    vars.shouldTrackNextBobble = false;
    for (var i = 0; i < vars.upgradesAcquired.Length; i++) {
        vars.upgradesAcquired[i] = false;
    }
    vars.shouldTrackNextTruckUpgrade = false;
    vars.mainGoalsCompleted.Clear();
    vars.shouldTrackNextGoalCompletion = false;
    vars.Log("Run started");
}

update
{
    current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;

    if (old.activeScene != current.activeScene) {
        vars.Log("[Watcher] activeScene: " + old.activeScene + " -> " + current.activeScene);
    }
    if (old.currentEnding != current.currentEnding) {
        vars.Log("[Watcher] currentEnding: " + old.currentEnding + " -> " + current.currentEnding);
    }
    if (old.loadIntro != current.loadIntro) {
        vars.Log("[Watcher] loadIntro: " + old.loadIntro + " -> " + current.loadIntro);
    }
    if (old.enableSnowcat != current.enableSnowcat) {
        vars.Log("[Watcher] enableSnowcat: " + old.enableSnowcat + " -> " + current.enableSnowcat);
        if (current.enableSnowcat > 0 && current.enableSnowcat > old.enableSnowcat) {
            vars.shouldTrackNextBobble = true;
        } else {
            vars.shouldTrackNextBobble = false;
        }
    }
    if (old.displayBobble != current.displayBobble) {
        vars.Log("[Watcher] displayBobble: " + old.displayBobble + " -> " + current.displayBobble);
    }
    if (old.truckHasTires != current.truckHasTires) {
        vars.Log("[Watcher] truckHasTires: " + old.truckHasTires + " -> " + current.truckHasTires);
    }
    if (old.truckHasBumper != current.truckHasBumper) {
        vars.Log("[Watcher] truckHasBumper: " + old.truckHasBumper + " -> " + current.truckHasBumper);
    }
    if (old.truckHasChains != current.truckHasChains) {
        vars.Log("[Watcher] truckHasChains: " + old.truckHasChains + " -> " + current.truckHasChains);
    }
    if (old.upgradeMakePaymentCallCount != current.upgradeMakePaymentCallCount) {
        vars.Log("[Watcher] upgradeMakePaymentCallCount: " + old.upgradeMakePaymentCallCount + " -> " + current.upgradeMakePaymentCallCount);
        if (
            current.upgradeMakePaymentCallCount > 0 && current.upgradeMakePaymentCallCount > old.upgradeMakePaymentCallCount
            && (current.activeScene == "MountainTown" || current.activeScene == "FishingTown" || current.activeScene == "SnowyPeaks")
        ) {
            vars.shouldTrackNextTruckUpgrade = true;
        } else {
            vars.shouldTrackNextTruckUpgrade = false;
        }
    }

    if (old.goalsCompleteGoalCallCount != current.goalsCompleteGoalCallCount) {
        vars.Log("[Watcher] goalsCompleteGoalCallCount: " + old.goalsCompleteGoalCallCount + " -> " + current.goalsCompleteGoalCallCount);
        if (current.goalsCompleteGoalCallCount > 0 && current.goalsCompleteGoalCallCount > old.goalsCompleteGoalCallCount) {
            vars.shouldTrackNextGoalCompletion = true;
        } else {
            vars.shouldTrackNextGoalCompletion = false;
        }
    }

    for (var i = 0; i < vars.mainGoalsCompletedWatchers.Length; i++) {
        if (vars.mainGoalsCompletedWatchers[i] != null && vars.mainGoalsCompletedWatchers[i].Old != vars.mainGoalsCompletedWatchers[i].Current) {
            vars.Log("[Watcher] Goal completed [" + i + "] (" + vars.mainGoalNames[i] + "): " + vars.mainGoalsCompletedWatchers[i].Old + " -> " + vars.mainGoalsCompletedWatchers[i].Current);
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
        vars.bobblesCollected.Add(current.displayBobble);
        vars.shouldTrackNextBobble = false;
        vars.Log("Collected bobble #" + current.displayBobble + ", total collected: " + vars.bobblesCollected.Count + "/13");

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

    if (
        settings["splitOnRestoreGoalCompleted"]
        && vars.shouldTrackNextGoalCompletion == true
    ) {
        for (var i = 0; i < vars.mainGoalsCompletedWatchers.Length; i++) {
            if (
                vars.mainGoalsCompletedWatchers[i] != null
                && vars.mainGoalsCompletedWatchers[i].Old != vars.mainGoalsCompletedWatchers[i].Current
                && vars.mainGoalsCompletedWatchers[i].Current == true
                && !vars.mainGoalsCompleted.Contains(i)
            ) {
                vars.mainGoalsCompleted.Add(i);
                vars.shouldTrackNextGoalCompletion = false;
                vars.Log("Completed main goal #" + i + " (" + vars.mainGoalNames[i] + "), total completed: " + vars.mainGoalsCompleted.Count + "/" + vars.mainGoalNames.Length);

                if (i == 13) { // "Restore" is the last main goal
                    return true;
                }
            }
        }
        for (var i = 0; i < vars.sideGoalsCompletedWatchers.Length; i++) {
            if (
                vars.sideGoalsCompletedWatchers[i] != null
                && vars.sideGoalsCompletedWatchers[i].Old != vars.sideGoalsCompletedWatchers[i].Current
                && vars.sideGoalsCompletedWatchers[i].Current == true
                && !vars.sideGoalsCompleted.Contains(i)
            ) {
                vars.sideGoalsCompleted.Add(i);
                vars.shouldTrackNextGoalCompletion = false;
                vars.Log("Completed side goal #" + i + " (" + vars.sideGoalNames[i] + "), total completed: " + vars.sideGoalsCompleted.Count + "/" + vars.sideGoalNames.Length);
            }
        }
    }
}
