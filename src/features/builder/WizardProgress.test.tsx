// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { render } from "@testing-library/react";
import { WizardProgress } from "./WizardProgress";
import { WIZARD_STEP_LABELS } from "@/lib/constants";

describe("WizardProgress", () => {
  it("現在のステップに aria-current とラベルが付く", () => {
    const { container, getAllByText } = render(<WizardProgress currentStep={2} />);
    const current = container.querySelector('[aria-current="step"]');
    expect(current?.textContent).toContain(WIZARD_STEP_LABELS[2]);
    // ラベルの視覚表示は現在ステップのみ（他は sr-only で読み上げにだけ残る）
    expect(getAllByText(WIZARD_STEP_LABELS[1])[0].className).toContain("sr-only");
  });

  it("完了ステップは ✓、未着手は番号で表示される", () => {
    const { getAllByText, getByText } = render(<WizardProgress currentStep={3} />);
    expect(getAllByText("[✓/4]", { exact: false })).toHaveLength(2); // ステップ 1・2 が完了
    expect(getByText("[4/4]", { exact: false })).toBeTruthy();
  });

  it("4 区画すべてが常に描画される", () => {
    const { container } = render(<WizardProgress currentStep={1} />);
    expect(container.querySelectorAll("li")).toHaveLength(4);
  });
});
