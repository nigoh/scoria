import { describe, it, expect, beforeEach } from "vitest";
import { useWizardStore } from "./wizardStore";

const store = () => useWizardStore.getState();

beforeEach(() => {
  useWizardStore.getState().reset();
});

describe("ステップの遷移", () => {
  it("初期状態は1ステップ目", () => {
    expect(store().currentStep).toBe(1);
  });

  it("nextStep で進む", () => {
    store().nextStep();
    expect(store().currentStep).toBe(2);
  });

  it("最終ステップから先へは進まない", () => {
    for (let i = 0; i < 10; i += 1) store().nextStep();
    expect(store().currentStep).toBe(4);
  });

  it("最初のステップより手前へは戻らない", () => {
    store().prevStep();
    expect(store().currentStep).toBe(1);
  });

  it("進んでから戻れる", () => {
    store().nextStep();
    store().nextStep();
    store().prevStep();
    expect(store().currentStep).toBe(2);
  });

  it("setStep で任意のステップへ飛べる", () => {
    store().setStep(4);
    expect(store().currentStep).toBe(4);
  });
});

describe("入れ子の設定を更新しても兄弟のフィールドを壊さない", () => {
  it("skillConfig の1項目を変えても他の項目は残る", () => {
    const before = store().formData.skillConfig;
    store().setSkillModel("opus");
    const after = store().formData.skillConfig;

    expect(after.model).toBe("opus");
    expect(after.allowedTools).toEqual(before.allowedTools);
    expect(after.argumentHint).toBe(before.argumentHint);
    expect(after.shell).toBe(before.shell);
  });

  it("agentConfig の更新が skillConfig に波及しない", () => {
    const skillBefore = store().formData.skillConfig;
    store().setAgentMaxTurns(99);

    expect(store().formData.agentConfig.maxTurns).toBe(99);
    expect(store().formData.skillConfig).toEqual(skillBefore);
  });

  it("トップレベルの更新が入れ子の設定を消さない", () => {
    store().setSkillPaths("src/**");
    store().setName("my-skill");

    expect(store().formData.name).toBe("my-skill");
    expect(store().formData.skillConfig.paths).toBe("src/**");
  });
});

describe("togglePluginComponent", () => {
  it("真偽値を反転する", () => {
    const before = store().formData.pluginConfig.includeHooks;
    store().togglePluginComponent("includeHooks");
    expect(store().formData.pluginConfig.includeHooks).toBe(!before);
  });

  it("2回反転すると元に戻る", () => {
    const before = store().formData.pluginConfig.includeSkills;
    store().togglePluginComponent("includeSkills");
    store().togglePluginComponent("includeSkills");
    expect(store().formData.pluginConfig.includeSkills).toBe(before);
  });

  it("他のコンポーネント設定を巻き込まない", () => {
    const before = store().formData.pluginConfig.includeReadme;
    store().togglePluginComponent("includeMcp");
    expect(store().formData.pluginConfig.includeReadme).toBe(before);
  });
});

describe("reset", () => {
  it("ステップとフォームを初期状態へ戻す", () => {
    store().setStep(4);
    store().setExtensionType("plugin");
    store().setName("dirty");
    store().setSkillModel("opus");
    store().setAgentIsolation("worktree");
    store().setHookEntries([
      {
        id: "h1",
        event: "Stop",
        matcher: "*",
        hookType: "command",
        command: "./x.sh",
        url: "",
        prompt: "",
        timeout: 30,
      },
    ]);

    store().reset();

    expect(store().currentStep).toBe(1);
    expect(store().formData.extensionType).toBeNull();
    expect(store().formData.name).toBe("");
    expect(store().formData.skillConfig.model).toBe("sonnet");
    expect(store().formData.agentConfig.isolation).toBe("none");
    expect(store().formData.hookEntries).toEqual([]);
  });

  it("編集と reset を繰り返しても既定値が汚れない", () => {
    // reset は初期値を浅くコピーする。入れ子を共有したまま書き換えが起きると、
    // 2回目以降の reset が「汚れた既定値」を返す。周回して固定しておく。
    const pristine = JSON.parse(JSON.stringify(store().formData));

    for (let i = 0; i < 3; i += 1) {
      store().setSkillAllowedTools(["Bash"]);
      store().setAgentTools([]);
      store().togglePluginComponent("includeClaudeMd");
      store().setMcpEntries([{ id: "m1", name: "x", command: "npx", args: "y", env: "" }]);
      store().reset();

      expect(store().formData).toEqual(pristine);
    }
  });
});

describe("setFormData", () => {
  it("履歴から読み戻した内容で丸ごと置き換える", () => {
    const restored = {
      ...store().formData,
      name: "restored",
      extensionType: "agent" as const,
      templateId: "meta_analysis" as const,
    };

    store().setFormData(restored);

    expect(store().formData.name).toBe("restored");
    expect(store().formData.extensionType).toBe("agent");
    expect(store().formData.templateId).toBe("meta_analysis");
  });
});
