// Vibrance (SweetFX) + temperatura de cor.
// Ajustar e: hyprctl eval 'hl.config({ decoration = { screen_shader = HOME .. "/.config/hypr/shaders/vibrance.glsl" } })'

#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float VIBRANCE    = 0.20;   // 0.0 neutro | 0.15 sutil | 0.30 forte
const float TEMPERATURE = 0.0;    // 0.0 neutro | >0 aquenta (amarelo), <0 esfria (azul)

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 c = pix.rgb;

    // vibrance
    float luma = dot(LUMA, c);
    float maxc = max(c.r, max(c.g, c.b));
    float minc = min(c.r, min(c.g, c.b));
    float sat  = maxc - minc;
    vec3 coeff = vec3(-VIBRANCE);
    vec3 p = (sign(coeff) * sat - 1.0) * coeff + 1.0;
    c = mix(vec3(luma), c, p);

    // temperatura
    c.r += TEMPERATURE;
    c.b -= TEMPERATURE;

    fragColor = vec4(clamp(c, 0.0, 1.0), pix.a);
}
