# rice

Hyprland com o [illogical-impulse do end-4](https://github.com/end-4/dots-hyprland) modificado, para CachyOS.

## Instalar

1. Instale o CachyOS normalmente.
2. No terminal:
   ```sh
   git clone https://github.com/jeffer1312/rice ~/rice && ~/rice/bootstrap.sh
   ```
3. Reinicie e entre na sessão **Hyprland**.

## Ajustar pra sua máquina

- Suas mudanças no Hyprland vão em `~/.config/hypr/custom/*.lua` (carrega por último e não faz parte do repo).
- Monitores: Control Center (Super+U) > Tela.
- O teclado vem como `br` / `abnt2`; para trocar, sobrescreva `input.kb_layout` em `custom/general.lua`.
- Atalhos: Super+/ mostra a lista.
