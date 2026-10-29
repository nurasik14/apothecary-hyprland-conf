# Learning Progress

## Pending decision
Decision: learning tour, stop 1b (predict the effect of `apothecary off` on gaps_out/rounding via override order)
Stage: awaiting reasoning
Asked: JaKooLit sets gaps_out = 6, rounding = 10 (UserDecorations.conf line 36); the theme's decorations.conf sets
gaps_out = 12, rounding = 8. Predict the values with active.conf -> on.conf and -> off.conf, and explain why (order).

## Hyprland basics
- Introduced (AI explained): compositor role; hyprland.conf is one file assembled from `source =` lines, read top to
  bottom, later values overriding earlier ones; `hyprctl reload` re-reads it live.
- Q "why is the theme sourced last": learner reasoned about project strategy (building on JaKooLit's features vs from
  scratch: less work, but coupled to JaKooLit) — valid dependency tradeoff, but did not address override order.
  Needs reinforcement: "later value wins" ordering.
- Q on/off switch: learner did not know the theme can be switched off; guessed the symlink flips between an "on" and an
  "off" file (correct in shape: on.conf / off.conf). AI then explained on.conf contents and that off.conf is empty.
