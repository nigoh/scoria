/**
 * テスト用のメモリ実装 Storage。
 *
 * 永続化ストア（extensionStore / historyStore）は localStorage・sessionStorage を使うが、
 * Vitest は node 環境で走るため実体が無い。ストアを import する前にこれを差し込む
 * （import はモジュール評価時にストレージへ触るので、import より前に呼ぶこと）。
 */
export function installMemoryStorage(): void {
  const make = (): Storage => {
    const map = new Map<string, string>();
    return {
      get length() {
        return map.size;
      },
      key: (i: number) => Array.from(map.keys())[i] ?? null,
      getItem: (k: string) => map.get(k) ?? null,
      setItem: (k: string, v: string) => void map.set(k, String(v)),
      removeItem: (k: string) => void map.delete(k),
      clear: () => map.clear(),
    };
  };

  Object.defineProperty(globalThis, "localStorage", { value: make(), configurable: true });
  Object.defineProperty(globalThis, "sessionStorage", { value: make(), configurable: true });
}
