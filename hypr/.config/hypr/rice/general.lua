-- Carregado DEPOIS de hyprland/general.lua, então sobrescreve os valores base.

-- Ordem dos monitores e RGB full range NAO ficam aqui: sao gerados em monitors.lua por
-- scripts/displaylayout.sh (Control Center > Display). Motivo de ser gerado:
--   * ordem: auto-right nao sabe a disposicao fisica da mesa, e dois monitores de
--     modelo identico tem a MESMA description no hyprctl - o automatico nao distingue.
--     O script recebe a ordem e calcula as posicoes considerando o scale de cada um.
--   * full range: o modeline CVT-RB e calculado por resolucao nativa de cada monitor
--     (cvt -r), em vez de um 1080p hardcoded que quebra em 1440p/4K.
-- Escrever daqui NAO funciona: monitors.lua carrega depois e a ultima regra para um
-- output vence, entao a regra daqui perdia e os monitores se sobrepunham em x=0.

-- Fallback pra monitor recem-plugado que ainda nao esta no monitors.lua gerado:
-- encaixa a direita em vez de empilhar em x=0. Regra nomeada vence o curinga.
hl.monitor({ output = "", position = "auto-right", scale = 1 })

hl.config({
    input = {
        kb_layout = "br",
        kb_model = "abnt2",
        accel_profile = "flat",
        sensitivity = 0.2,
    },
    general = {
        col = {
            active_border = "rgba(0DB7D499)",
        },
    },
})
