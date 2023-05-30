:: TODO: Use build.zig instead of this
@echo off


"./deps/sokol-tools/bin/win32/sokol-shdc.exe" --input ./src/shaders/basic_shader.glsl --output ./src/shaders/basic_shader.zig --slang glsl330:hlsl5 --format sokol_zig