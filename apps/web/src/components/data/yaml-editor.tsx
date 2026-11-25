import Editor, { DiffEditor, loader } from "@monaco-editor/react";
import * as monaco from "monaco-editor/esm/vs/editor/editor.api";
import "monaco-editor/esm/vs/basic-languages/yaml/yaml.contribution";
import EditorWorker from "monaco-editor/esm/vs/editor/editor.worker?worker";
import { useEffect, useRef } from "react";
import { useTheme } from "@/lib/theme";

window.MonacoEnvironment = { getWorker: () => new EditorWorker() };
loader.config({ monaco });

export interface EditorMarker {
  line: number;
  column?: number;
  message: string;
}

export function YamlEditor({
  value,
  onChange,
  markers = [],
  height = 520,
  readOnly,
  ariaLabel,
}: {
  value: string;
  onChange?: (v: string) => void;
  markers?: EditorMarker[];
  height?: number | string;
  readOnly?: boolean;
  ariaLabel?: string;
}) {
  const { resolvedTheme } = useTheme();
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);

  useEffect(() => {
    const model = editorRef.current?.getModel();
    if (!model) return;
    monaco.editor.setModelMarkers(
      model,
      "satops",
      markers.map((m) => ({
        startLineNumber: m.line,
        endLineNumber: m.line,
        startColumn: m.column ?? 1,
        endColumn: model.getLineMaxColumn(Math.min(m.line, model.getLineCount())),
        message: m.message,
        severity: monaco.MarkerSeverity.Error,
      })),
    );
  }, [markers, value]);

  return (
    <div className="overflow-hidden rounded-md border border-border">
      <Editor
        height={height}
        language="yaml"
        theme={resolvedTheme === "dark" ? "vs-dark" : "vs"}
        value={value}
        onChange={(v) => onChange?.(v ?? "")}
        onMount={(editor) => {
          editorRef.current = editor;
        }}
        options={{
          readOnly,
          minimap: { enabled: false },
          fontSize: 13,
          tabSize: 2,
          insertSpaces: true,
          scrollBeyondLastLine: false,
          wordWrap: "on",
          ariaLabel,
          renderWhitespace: "boundary",
        }}
      />
    </div>
  );
}

export function YamlDiff({ original, modified, height = 360 }: { original: string; modified: string; height?: number }) {
  const { resolvedTheme } = useTheme();
  return (
    <div className="overflow-hidden rounded-md border border-border">
      <DiffEditor
        height={height}
        language="yaml"
        theme={resolvedTheme === "dark" ? "vs-dark" : "vs"}
        original={original}
        modified={modified}
        options={{ readOnly: true, renderSideBySide: true, minimap: { enabled: false }, fontSize: 12, scrollBeyondLastLine: false }}
      />
    </div>
  );
}
