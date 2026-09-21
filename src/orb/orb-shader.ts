import type { OrbUniforms } from './frame';
import type { SessionMode } from '../../electron/types';

import type { OrbPalette } from './palette';

/**
 * The orb, drawn by one fragment shader on one fullscreen triangle pair.
 *
 * The silhouette is a flame, not a disc: rising noise pushes the outline out,
 * hardest at the top, so tongues lick upward and the base stays round. Voice
 * feeds the fire: `uLow` makes the tongues taller and pushes the colour lobes
 * apart, `uHigh` adds flicker and brightens the rim and specular. Output is
 * premultiplied alpha, which is what a transparent Electron window composites
 * correctly.
 */

const VERTEX = `
attribute vec2 aPosition;
varying vec2 vUv;
void main() {
  vUv = aPosition;
  gl_Position = vec4(aPosition, 0.0, 1.0);
}`;

const FRAGMENT = `
precision highp float;
varying vec2 vUv;
uniform float uFlow, uLow, uHigh, uFrom, uTo, uMix, uCalm;
uniform vec3 uAurora[3];
uniform vec3 uDone;
uniform vec3 uError;

// 2D simplex noise, Ian McEwan / Ashima Arts, MIT licence.
vec3 permute(vec3 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }
float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

mat2 rotate(float angle) {
  float s = sin(angle), c = cos(angle);
  return mat2(c, -s, s, c);
}

float isPhase(float phase, float index) {
  return step(index - 0.5, phase) * step(phase, index + 0.5);
}

// One phase's look, premultiplied. Phase 0 (cancelled) draws nothing.
vec4 look(float phase, vec2 uv) {
  if (phase < 0.5) return vec4(0.0);
  float listening = isPhase(phase, 1.0);
  float transcribing = isPhase(phase, 2.0);
  float done = isPhase(phase, 3.0);
  float failed = isPhase(phase, 4.0);

  float low = uLow * listening;
  float high = uHigh * listening;

  float edge = length(uv);
  // Smaller and lower than the canvas centre: the room above is the flame's.
  float radius = 0.38 * (1.0 + 0.05 * low);
  vec2 seat = uv + vec2(0.0, 0.35);

  // Transcribing: the field winds inward, tighter toward the centre.
  vec2 p = rotate(transcribing * (uFlow * 0.8 + (1.0 - edge) * 2.5)) * seat;
  vec2 q = p / radius;

  // The flame outline. Sampled in unrotated space so the tongues always rise,
  // even while the inside swirls. Noise scrolls down, so its features move up.
  vec2 s = seat / radius;
  float upness = pow(smoothstep(-0.2, 1.0, s.y / max(length(s), 0.001)), 1.5);
  float lick = 0.75 * snoise(vec2(s.x * 1.5, s.y * 1.1 - uFlow * 0.8))
    + 0.25 * snoise(vec2(s.x * 3.0 + 3.1, s.y * 2.2 - uFlow * 1.3));
  // Only ever outward, and sharpened, so tongues come to a point instead of
  // the outline wobbling in and out like a blob.
  float tongue = pow(clamp(lick * 0.5 + 0.5, 0.0, 1.0), 1.6);
  float motion = 1.0 - 0.7 * uCalm;
  float energy = 0.18 + low * 0.25 + high * 0.04;
  float outline = 1.0
    + motion * upness * (0.06 + low * 0.06 + energy * tongue)
    + motion * 0.03 * lick;
  // Everything below measures against the outline, so the colour, the
  // lighting and the glow stretch into the tongues instead of cutting a
  // circle through them.
  q /= outline;
  float r = length(q);

  // The colour field drifts upward with the fire.
  vec2 warp = vec2(
    snoise(q * 1.3 + vec2(uFlow, -uFlow * 0.5)),
    snoise(q * 1.3 + vec2(7.3, -uFlow * 0.7))
  );
  vec2 w = q + warp * 0.35 * (1.0 + low * 1.2);

  vec3 colour = vec3(0.0);
  for (int i = 0; i < 3; i++) {
    float offset = float(i) * 2.094;
    vec2 centre = 0.45 * (0.6 + low * 0.8)
      * vec2(cos(uFlow * 0.7 + offset), sin(uFlow * 0.9 + offset));
    vec3 tint = mix(mix(uAurora[i], uDone, done), uError, failed);
    vec2 delta = w - centre;
    colour += tint * exp(-dot(delta, delta) * 3.2);
  }

  // Fake sphere lighting.
  float z = sqrt(max(0.0, 1.0 - r * r));
  vec3 normal = vec3(q, z);
  vec3 light = normalize(vec3(0.5 * cos(uFlow * 0.5), 0.6 + 0.2 * sin(uFlow * 0.4), 0.8));
  float diffuse = 0.55 + 0.45 * max(dot(normal, light), 0.0);
  float specular = pow(max(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0), 24.0);
  float fresnel = pow(1.0 - z, 2.5);
  vec3 rimTint = mix(uAurora[1], uAurora[2], 0.5 + 0.5 * sin(uFlow + atan(q.y, q.x)));
  rimTint = mix(mix(rimTint, uDone, done), uError, failed);

  colour = colour * diffuse
    + vec3(specular) * (0.35 + high * 0.9)
    + rimTint * fresnel * (0.5 + high * 1.2);
  // Flicker scales the light that is there. Added instead, the same grain
  // swamps the dark parts of a linear-light field and reads as black specks.
  colour *= 1.0 + high * (1.0 - uCalm) * 0.15 * snoise(q * 4.0 + vec2(0.0, -uFlow * 1.2));
  colour *= 1.0 - 0.25 * transcribing;
  // Error: one slow pulse.
  colour *= 1.0 - failed * 0.25 * (0.5 + 0.5 * sin(uFlow * 4.0));

  // Crisp at the base, feathered where the tongues thin out.
  float body = 1.0 - smoothstep(mix(0.96, 0.8, upness * motion), 1.0, r);
  float halo = exp(-max(r - 1.0, 0.0) * 5.0) * (0.25 + low * 0.35 + done * 0.3) * (1.0 - body);
  // Reaches zero before the canvas edge, so the window never clips the glow.
  float fade = 1.0 - smoothstep(0.85, 1.0, edge);

  float alpha = clamp(body + halo, 0.0, 1.0) * fade;
  vec3 lit = mix(rimTint, colour, body);
  return vec4(lit * alpha, alpha);
}

void main() {
  vec4 colour = mix(look(uFrom, vUv), look(uTo, vUv), uMix);
  // Linear to sRGB on the premultiplied colour's straight component.
  vec3 straight = colour.a > 0.0 ? colour.rgb / colour.a : vec3(0.0);
  gl_FragColor = vec4(pow(straight, vec3(1.0 / 2.2)) * colour.a, colour.a);
}`;

export interface OrbRenderer {
  /** `mode` picks the hue: indigo for dictation, lilac for a voice edit. */
  render(uniforms: OrbUniforms, mode?: SessionMode): void;
  dispose(): void;
}

function compile(gl: WebGLRenderingContext, type: number, source: string) {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error('orb shader failed to compile', gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

export function createOrbRenderer(
  canvas: HTMLCanvasElement,
  palette: OrbPalette
): OrbRenderer | null {
  const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: true, antialias: false });
  if (!gl) return null;

  const vertex = compile(gl, gl.VERTEX_SHADER, VERTEX);
  const fragment = compile(gl, gl.FRAGMENT_SHADER, FRAGMENT);
  const program = gl.createProgram();
  if (!vertex || !fragment || !program) {
    if (vertex) gl.deleteShader(vertex);
    if (fragment) gl.deleteShader(fragment);
    if (program) gl.deleteProgram(program);
    return null;
  }
  gl.attachShader(program, vertex);
  gl.attachShader(program, fragment);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error('orb program failed to link', gl.getProgramInfoLog(program));
    gl.deleteShader(vertex);
    gl.deleteShader(fragment);
    gl.deleteProgram(program);
    return null;
  }
  gl.useProgram(program);

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
  const position = gl.getAttribLocation(program, 'aPosition');
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

  const location = (name: string) => gl.getUniformLocation(program, name);
  const auroraLocation = location('uAurora[0]');
  const hues: Record<SessionMode, Float32Array> = {
    dictate: new Float32Array(palette.aurora.flat()),
    edit: new Float32Array(palette.lilac.flat()),
  };
  let worn: SessionMode = 'dictate';
  gl.uniform3fv(auroraLocation, hues[worn]);
  gl.uniform3fv(location('uDone'), new Float32Array(palette.done));
  gl.uniform3fv(location('uError'), new Float32Array(palette.error));

  const scalars = {
    uFlow: location('uFlow'),
    uLow: location('uLow'),
    uHigh: location('uHigh'),
    uFrom: location('uFrom'),
    uTo: location('uTo'),
    uMix: location('uMix'),
    uCalm: location('uCalm'),
  };

  gl.clearColor(0, 0, 0, 0);

  return {
    render(uniforms, mode = 'dictate') {
      if (mode !== worn) {
        worn = mode;
        gl.uniform3fv(auroraLocation, hues[worn]);
      }
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.uniform1f(scalars.uFlow, uniforms.flow);
      gl.uniform1f(scalars.uLow, uniforms.low);
      gl.uniform1f(scalars.uHigh, uniforms.high);
      gl.uniform1f(scalars.uFrom, uniforms.from);
      gl.uniform1f(scalars.uTo, uniforms.to);
      gl.uniform1f(scalars.uMix, uniforms.mix);
      gl.uniform1f(scalars.uCalm, uniforms.calm);
      gl.drawArrays(gl.TRIANGLES, 0, 6);
    },
    dispose() {
      gl.deleteBuffer(buffer);
      gl.deleteProgram(program);
      gl.deleteShader(vertex);
      gl.deleteShader(fragment);
    },
  };
}
