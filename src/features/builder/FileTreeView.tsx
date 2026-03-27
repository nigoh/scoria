import { File, FolderOpen } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import { useExtensionStore } from "@/stores/extensionStore";

export function FileTreeView() {
  const { generatedExtension, selectedFilePath, setSelectedFilePath } = useExtensionStore();

  if (!generatedExtension || generatedExtension.files.length === 0) return null;

  const tree = buildTree(generatedExtension.files.map((f) => f.path));

  return (
    <div className="space-y-0.5">
      {tree.map((node) => (
        <TreeNode
          key={node.path}
          node={node}
          selectedPath={selectedFilePath}
          onSelect={setSelectedFilePath}
        />
      ))}
    </div>
  );
}

interface TreeNodeData {
  name: string;
  path: string;
  isFile: boolean;
  children: TreeNodeData[];
}

function buildTree(paths: string[]): TreeNodeData[] {
  const root: TreeNodeData[] = [];

  for (const path of paths) {
    const parts = path.split("/");
    let current = root;

    for (let i = 0; i < parts.length; i++) {
      const name = parts[i];
      const isFile = i === parts.length - 1;
      const fullPath = parts.slice(0, i + 1).join("/");

      let existing = current.find((n) => n.name === name);
      if (!existing) {
        existing = { name, path: fullPath, isFile, children: [] };
        current.push(existing);
      }
      current = existing.children;
    }
  }

  return root;
}

function TreeNode({
  node,
  selectedPath,
  onSelect,
  depth = 0,
}: {
  node: TreeNodeData;
  selectedPath: string | null;
  onSelect: (path: string) => void;
  depth?: number;
}) {
  const isSelected = selectedPath === node.path;

  return (
    <>
      <button
        onClick={() => node.isFile && onSelect(node.path)}
        className={cn(
          "flex w-full items-center gap-1.5 rounded px-2 py-1 text-left text-sm transition-colors",
          node.isFile ? "cursor-pointer hover:bg-muted" : "cursor-default",
          isSelected && "bg-primary/10 text-primary",
        )}
        style={{ paddingLeft: `${depth * 16 + 8}px` }}
      >
        {node.isFile ? (
          <File size={14} className="shrink-0" />
        ) : (
          <FolderOpen size={14} className="shrink-0 text-muted-foreground" />
        )}
        <span className="truncate">{node.name}</span>
      </button>
      {node.children.map((child) => (
        <TreeNode
          key={child.path}
          node={child}
          selectedPath={selectedPath}
          onSelect={onSelect}
          depth={depth + 1}
        />
      ))}
    </>
  );
}
