# codex: OpenAI lightweight coding agent (terminal-based)
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.codex ];
}
