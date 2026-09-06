# Apply to the existing config, not a replacement template. Doctor owns the
# agents.list -> agents.entries migration and preserves channel ownership.
.agents.defaults.model = {
  primary: "openai/gpt-6-astra",
  fallbacks: ["openai/gpt-5.6-luna"]
}
| .agents.defaults.thinkingDefault = "low"
| .agents.defaults.models["openai/gpt-6-astra"] = (
    (.agents.defaults.models["openai/gpt-6-astra"] // {})
    * {alias: "openai-gpt-6-astra", params: {thinking: "low"}, agentRuntime: {id: "codex"}}
  )
| .agents.defaults.models["openai/gpt-5.6-luna"].params.thinking = "low"
| .agents.defaults.utilityModel = "openai/gpt-5.6-luna"
| .agents.defaults.pdfModel = {primary: "openai/gpt-5.6-luna"}
| .agents.defaults.subagents.model = "openai/gpt-5.6-luna"
| .agents.defaults.subagents.thinking = "low"
# Codex performs compaction natively; Doctor removes external model overrides.
| del(.agents.defaults.compaction.model)
| .agents.defaults.compaction.thinkingLevel = "low"
| .agents.defaults.heartbeat.model = "openai/gpt-5.6-luna"
| (if .agents.list then
    .agents.list |= map(
      if .id == "main" then
        .model = {primary: "openai/gpt-6-astra", fallbacks: ["openai/gpt-5.6-luna"]}
        | .thinkingDefault = "low"
      elif .id == "heartbeat" then
        .model = "openai/gpt-5.6-luna" | .thinkingDefault = "low"
      else . end)
   else . end)
| (if .agents.entries then
    .agents.entries.main.model = {primary: "openai/gpt-6-astra", fallbacks: ["openai/gpt-5.6-luna"]}
    | .agents.entries.main.thinkingDefault = "low"
    | (if .agents.entries.heartbeat then
        .agents.entries.heartbeat.model = "openai/gpt-5.6-luna"
        | .agents.entries.heartbeat.thinkingDefault = "low"
      else . end)
   else . end)
# Fields retired by the target release; retain the image-generation model.
| (if .agents.defaults.imageGenerationModel then
    .agents.defaults.mediaModels.image //= .agents.defaults.imageGenerationModel
    | del(.agents.defaults.imageGenerationModel)
   else . end)
| del(.agents.defaults.contextLimits.memoryGetDefaultLines,
      .agents.defaults.contextLimits.toolResultMaxChars,
      .logging.redactSensitive)
