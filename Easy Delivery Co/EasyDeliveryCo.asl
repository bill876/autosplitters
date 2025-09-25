state("EasyDeliveryCo") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.LoadSceneManager = true;
    Assembly.Load(File.ReadAllBytes("Components/uhara7")).CreateInstance("Main");
}

init
{
    var jitSave = vars.Uhara.CreateTool("Unity", "DotNet", "JitSave");
    IntPtr loadIntroFlag = jitSave.AddFlag("IntroDotExe", "LoadIntro");
    jitSave.ProcessQueue();

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var endingManager = mono["EndingManager"];
        vars.Helper["currentEnding"] = mono.Make<int>(
            endingManager,
            "instance",
            endingManager["currentEnding"]
        );

        vars.Helper["loadIntro"] = vars.Helper.Make<int>(loadIntroFlag);

        return true;
    });
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
}

start
{
    if (current.activeScene == "TitleScreen" && current.loadIntro > old.loadIntro) {
        return true;
    }
}

split
{
    if (current.activeScene == "Ending" && current.currentEnding != old.currentEnding) {
        return true;
    }
}
