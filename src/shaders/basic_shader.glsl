@header const m = @import("../math.zig")
@ctype mat4 m.Mat4

@vs vs

in vec3 aPos;
in vec4 aColor;
in vec2 aTexCoords;

out vec4 vColor;
out vec2 vTexCoords;

uniform vs_params {
    mat4 mvp;
};

void main() {
    gl_Position = mvp * vec4(aPos, 1.0);
    vTexCoords = aTexCoords;
    vColor = aColor;
}

@end

@fs fs
uniform sampler2D tex;

in vec4 vColor;
in vec2 vTexCoords;

out vec4 color;

void main() {
    color = texture(tex, vTexCoords) * vColor;
}

@end

@program basic_shader vs fs
