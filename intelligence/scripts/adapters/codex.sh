#!/bin/bash
# intelligence-sync: OpenAI Codex CLI adapter
# Transforms source prompts to Codex format.
#
# Codex reads AGENTS.md natively for project context — the `agents` adapter
# inlines always-on rules into AGENTS.md, so this adapter only emits skills
# and subagent definitions.
#
# Skills: copy SKILL.md to .agents/skills/{name}/SKILL.md (Codex reads from
#   $REPO_ROOT/.agents/skills exclusively per official docs)
# Agents: -> .codex/agents/{name}.toml (name, description, model,
#   model_reasoning_effort, sandbox_mode, developer_instructions)

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Sync skills to Codex format (.agents/skills/{name}/SKILL.md)
sync_codex_skills() {
    local repo_root="$1"
    local config_file="$2"
    local output_dir="$3"

    local count=0
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        local dir="$repo_root/$src"
        [ -d "$dir" ] || continue
        for d in "$dir"/*/; do
            [ -d "$d" ] || continue
            local skill_name
            skill_name="$(basename "$d")"
            [ -f "$d/SKILL.md" ] || continue
            mkdir -p "$output_dir/$skill_name"
            # Codex CLI uses strict YAML — unquoted description/argument-hint
            # values silently break the skill. Adapter enforces quoting on copy.
            copy_md_with_quoted_frontmatter "$d/SKILL.md" "$output_dir/$skill_name/SKILL.md"
            normalize_file_to_lf "$output_dir/$skill_name/SKILL.md"
            count=$((count + 1))
            echo "  skill: $skill_name"
        done
    done < <(read_yaml_list "$config_file" "skills")

    echo "  -> Skills: $count"
}

# Sync agents to Codex format (.codex/agents/{name}.toml)
sync_codex_agents() {
    local repo_root="$1"
    local config_file="$2"
    local output_dir="$3"

    local count=0
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        local dir="$repo_root/$src"
        [ -d "$dir" ] || continue
        for f in "$dir"/*.md; do
            [ -f "$f" ] || continue
            local name
            name="$(basename "$f" .md)"

            local tier access description
            tier=$(get_frontmatter_value "tier" "$f")
            access=$(get_frontmatter_value "access" "$f")
            description=$(get_frontmatter_value "description" "$f")

            local model effort sandbox
            model=$(get_model "$config_file" "codex" "$tier")
            case "$tier" in
                heavy)    effort="high" ;;
                standard) effort="medium" ;;
                light)    effort="low" ;;
                *)        effort="medium" ;;
            esac
            case "$access" in
                readonly) sandbox="read-only" ;;
                *)        sandbox="workspace-write" ;;
            esac

            local body
            body=$(awk '
                BEGIN { in_fm=0; past_fm=0 }
                { sub(/\r$/, "") }
                /^---$/ {
                    if (!past_fm) { in_fm = !in_fm; if (!in_fm) { past_fm=1 }; next }
                }
                past_fm { print }
            ' "$f")

            # If the body contains the closing TOML triple-quote sequence,
            # neutralize it by escaping the third quote — keeps the file
            # parseable instead of bleeding raw markdown into the TOML grammar.
            local body_safe
            body_safe="${body//\"\"\"/\"\"\\\"}"

            local name_escaped description_escaped
            name_escaped=$(toml_escape "$name")
            description_escaped=$(toml_escape "$description")

            {
                echo "name = \"$name_escaped\""
                echo "description = \"$description_escaped\""
                echo "model = \"$model\""
                echo "model_reasoning_effort = \"$effort\""
                echo "sandbox_mode = \"$sandbox\""
                echo ""
                echo "developer_instructions = \"\"\""
                echo "$body_safe"
                echo "\"\"\""
            } > "$output_dir/$name.toml"
            normalize_file_to_lf "$output_dir/$name.toml"
            count=$((count + 1))
            echo "  agent: $name.toml"
        done
    done < <(read_yaml_list "$config_file" "agents")

    echo "  -> Agents: $count"
}

# Main entry point for Codex adapter
sync_to_codex() {
    local repo_root="$1"
    local config_file="$2"
    local output_dir="$3"

    echo "=== OpenAI Codex ==="

    # Skills -> .agents/skills/ (Codex reads from this fixed path)
    local skills_dir="$repo_root/.agents/skills"
    if [ -d "$skills_dir" ]; then
        find "$skills_dir" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
            rm -rf "$d"
        done
    fi
    mkdir -p "$skills_dir"
    sync_codex_skills "$repo_root" "$config_file" "$skills_dir"

    # Agents -> .codex/agents/
    local agents_dir="$repo_root/.codex/agents"
    rm -rf "$agents_dir"
    mkdir -p "$agents_dir"
    sync_codex_agents "$repo_root" "$config_file" "$agents_dir"
}
