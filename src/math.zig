const std = @import("std");
pub usingnamespace std.math;
const log = std.log.scoped(.math);

const math = @This();

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);

pub const Mat4 = [4]Vec4;

pub inline fn vec2(x: f32, y: f32) Vec2 {
    return Vec2{ x, y };
}

pub inline fn vec2IsZero(v: Vec2) bool {
    return v[0] == 0 and v[1] == 0;
}

pub inline fn vec2Mag(v: Vec2) f32 {
    return math.sqrt(v[0] * v[0] + v[1] * v[1]);
}

pub inline fn vec2Norm(v: Vec2) Vec2 {
    const mag = vec2Mag(v);
    if (mag == 0) return vec2(0, 0);
    return vec2(v[0] / mag, v[1] / mag);
}

pub inline fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{ x, y, z };
}

pub inline fn vec3IsZero(v: Vec3) bool {
    return v[0] == 0 and v[1] == 0 and v[2] == 0;
}

pub inline fn vec3Mag(v: Vec3) f32 {
    return math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

pub inline fn vec3Norm(v: Vec3) Vec3 {
    const mag = vec3Mag(v);
    if (mag == 0) return 0;
    return vec3(v[0] / mag, v[1] / mag, v[2] / mag);
}

pub inline fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return Vec4{ x, y, z, w };
}

pub inline fn vec4IsZero(v: Vec4) bool {
    return v[0] == 0 and v[1] == 0 and v[2] == 0 and v[3] == 0;
}

pub inline fn vec4Mag(v: Vec4) f32 {
    return math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]);
}

pub inline fn vec4Norm(v: Vec4) Vec4 {
    const mag = vec4Mag(v);
    if (mag == 0) return 0;
    return vec4(v[0] / mag, v[1] / mag, v[2] / mag, v[3] / mag);
}

pub inline fn vec4MulMat4(v: Vec4, m: Mat4) Vec4 {
    return vec4(
        v[0] * m[0][0] + v[1] * m[0][1] + v[2] * m[0][2] + v[3] * m[0][3],
        v[0] * m[1][0] + v[1] * m[1][1] + v[2] * m[1][2] + v[3] * m[1][3],
        v[0] * m[2][0] + v[1] * m[2][1] + v[2] * m[2][2] + v[3] * m[2][3],
        v[0] * m[3][0] + v[1] * m[3][1] + v[2] * m[3][2] + v[3] * m[3][3],
    );
}

pub inline fn mat4() Mat4 {
    return Mat4{
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(0, 0, 0, 1),
    };
}

pub inline fn mat4Mul(a: Mat4, b: Mat4) Mat4 {
    var mat = mat4();
    for (a, 0..) |a_row, i| {
        for (b, 0..) |b_col, j| {
            mat[i][j] = a_row[0] * b_col[0] + a_row[1] * b_col[1] + a_row[2] * b_col[2] + a_row[3] * b_col[3];
        }
    }
    return mat;
}

pub inline fn mat4MulVec4(m: Mat4, v: Vec4) Vec4 {
    return vec4(
        v[0] * m[0][0] + v[1] * m[1][0] + v[2] * m[2][0] + v[3] * m[3][0],
        v[0] * m[0][1] + v[1] * m[1][1] + v[2] * m[2][1] + v[3] * m[3][1],
        v[0] * m[0][2] + v[1] * m[1][2] + v[2] * m[2][2] + v[3] * m[3][2],
        v[0] * m[0][3] + v[1] * m[1][3] + v[2] * m[2][3] + v[3] * m[3][3],
    );
}

pub inline fn mat4Translate(v: Vec3) Mat4 {
    var mat = mat4();
    mat[3] = vec4(v[0], v[1], v[2], 1);

    return mat;
}

pub inline fn mat4RotateAxis(axis: Vec3, angle: f32) Mat4 {
    var mat = mat4();
    const c = math.cos(angle);
    const s = math.sin(angle);
    const t = 1 - c;
    const x = axis[0];
    const y = axis[1];
    const z = axis[2];
    mat[0] = vec4(t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0);
    mat[1] = vec4(t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0);
    mat[2] = vec4(t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0);
    return mat;
}

pub inline fn mat4Scale(v: Vec3) Mat4 {
    var mat = mat4();
    mat[0][0] = v[0];
    mat[1][1] = v[1];
    mat[2][2] = v[2];
    return mat;
}

pub inline fn mat4Ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
    var mat = mat4();
    mat[0][0] = 2 / (right - left);
    mat[1][1] = 2 / (top - bottom);
    mat[2][2] = -2 / (far - near);
    mat[3][0] = -(right + left) / (right - left);
    mat[3][1] = -(top + bottom) / (top - bottom);
    mat[3][2] = -(far + near) / (far - near);
    return mat;
}

pub inline fn vec2AsArray(v: Vec2) [2]f32 {
    return [2]f32{ v[0], v[1] };
}

pub inline fn vec3AsArray(v: Vec3) [3]f32 {
    return [3]f32{ v[0], v[1], v[2] };
}

pub inline fn vec4AsArray(v: Vec4) [4]f32 {
    return [4]f32{ v[0], v[1], v[2], v[3] };
}

// Arrange the matrix in column-major order
pub inline fn mat4AsArray(m: Mat4) [16]f32 {
    return [16]f32{
        m[0][0], m[1][0], m[2][0], m[3][0],
        m[0][1], m[1][1], m[2][1], m[3][1],
        m[0][2], m[1][2], m[2][2], m[3][2],
        m[0][3], m[1][3], m[2][3], m[3][3],
    };
}
