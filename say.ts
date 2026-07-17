import { tool } from "@opencode-ai/plugin"
import path from "path"
import os from "node:os"
import { existsSync } from "fs"

function findPython(): string {
    const candidates = [
        path.join(os.homedir(), ".config", "opencode", "tools", "venv", "bin", "python3"),
        path.join(os.homedir(), ".config", "opencode", "tools", "venv", "bin", "python"),
        "python3",
        "python",
    ]
    for (const p of candidates) {
        try {
            const proc = Bun.spawnSync([p, "--version"])
            if (proc.exitCode === 0) return p
        } catch (_) {}
    }
    return candidates[0]
}

function findScript(dir: string): string {
    const candidates = [
        path.join(os.homedir(), ".config", "opencode", "tools", "say.py"),
        path.join(dir, "say.py"),
        path.join(dir, ".opencode", "tools", "say.py"),
    ]
    for (const p of candidates) {
        if (existsSync(p)) return p
    }
    return candidates[0]
}

async function callSay(text: string, directory: string) {
    const python = findPython()
    const script = findScript(directory)
    const payload = JSON.stringify({ command: "say", text })

    let stdout = ""
    let stderr = ""
    let exitCode = 0

    try {
        const proc = Bun.spawn([python, script], {
            stdin: "pipe",
            stdout: "pipe",
            stderr: "pipe",
        })
        proc.stdin.write(payload)
        proc.stdin.end()

        exitCode = await proc.exited
        stdout = await new Response(proc.stdout).text()
        stderr = await new Response(proc.stderr).text()
    } catch (e: any) {
        return `say: spawn failed: ${e.message || e}`
    }

    if (exitCode !== 0) {
        const detail = stderr.trim() || stdout.trim() || "(no output)"
        return `say: exit ${exitCode}: ${detail}`
    }
    return stdout.trim()
}

// ---------------------------------------------------------------------------
// Tool definition
// ---------------------------------------------------------------------------

export const say = tool({
    description:
        "Convert text to speech and play it to the user.\n" +
        "(IMPORTANT) The input text MUST be a concise summary if the content is long. " +
        "Only send the full original text if the user explicitly requests " +
        "to hear the entire text read aloud. " +
        "Keep spoken text brief, clear, and suitable for speech.",
    args: {
        text: tool.schema
            .string()
            .describe(
                "Text to speak aloud. MUST be a short summary for long content. " +
                "Only use full text when user explicitly asks to hear everything."
            ),
    },
    async execute(args, context) {
        return await callSay(args.text, context.directory)
    },
})
