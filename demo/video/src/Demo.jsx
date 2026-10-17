import {AbsoluteFill, Easing, Freeze, OffthreadVideo, Sequence, interpolate, staticFile, useCurrentFrame} from 'remotion';
import timeline from './timeline.json';
import {color, font, fps, terminal} from './theme';

export const INTRO = 2.2; // seconds of title before the recording

// The recording plays straight through, except at a hold: a still frame where the eye needs time.
const HOLDS = [
  {at: timeline.events.exit, length: 2.2}, // the handoff text, on claude's last frame: it can end 0.1 s after the text shows
  {at: timeline.events.switch + 0.3, length: 1}, // the switch line
];
// Where a time in the recording lands in the video, after the holds before it.
const out = (t) => t + HOLDS.filter((h) => h.at < t).reduce((sum, h) => sum + h.length, 0);
const at = Object.fromEntries(Object.entries(timeline.events).map(([name, t]) => [name, out(t)]));
export const LENGTH = INTRO + out(timeline.duration);

// Each caption shows from its event until the next one.
const CAPTIONS = [
  ['ls', 'cleon ls: every account and its quota'],
  ['run', 'cleon starts on the first account with room'],
  ['handoff', 'At its 5% reserve, the agent writes a handoff'],
  ['switch', 'cleon resumes the same chat on the next account'],
  ['pickup', 'personal carries on from the handoff'],
];

// The list, then the switch line under it, before claude draws its screen again.
// x and y: the point that stays still, as a fraction of the terminal.
const ZOOMS = [
  {from: at.ls + 0.5, to: at.run - 0.2, scale: 1.12, x: 0.02, y: 0.05},
  {from: at.switch, to: at.switch + 3, scale: 1.4, x: 0.02, y: 0.47},
];

const frames = (seconds) => Math.round(seconds * fps);
// The recording as pieces in video order: {src: start in the recording, length, still}.
const PIECES = [...HOLDS, {at: timeline.duration}].flatMap((h, k, all) => {
  const from = k ? all[k - 1].at : 0;
  const play = {src: from, length: h.at - from};
  return h.length ? [play, {src: h.at, length: h.length, still: true}] : [play];
});

const fade = Easing.out(Easing.cubic);
const glide = Easing.inOut(Easing.cubic);
const ramp = (t, points, values, easing = fade) =>
  interpolate(t, points, values, {easing, extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

const Title = () => {
  const t = useCurrentFrame() / fps;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center',
      opacity: ramp(t, [0, 0.4, INTRO - 0.4, INTRO], [0, 1, 1, 0]),
      transform: `translateY(${ramp(t, [0, 0.4], [16, 0])}px)`}}>
      <div style={{fontFamily: font.mono, fontWeight: 700, fontSize: 140, color: color.text}}>cleon</div>
      <div style={{fontFamily: font.mono, fontSize: 44, color: color.subtext, marginTop: 24}}>
        One Claude Code chat, many accounts.
      </div>
    </AbsoluteFill>
  );
};

const Footage = () => {
  let start = 0;
  return PIECES.map((p) => {
    const from = start;
    start += frames(p.length);
    const video = <OffthreadVideo src={staticFile('run.mp4')} muted trimBefore={frames(p.src)}
      style={{width: '100%', height: '100%'}} />;
    return (
      <Sequence key={from} from={from} durationInFrames={frames(p.length)} layout="none">
        {p.still ? <Freeze frame={0}>{video}</Freeze> : video}
      </Sequence>
    );
  });
};

const Recording = () => {
  const t = useCurrentFrame() / fps;
  const zoom = ZOOMS.find((z) => t > z.from && t < z.to);
  const scale = zoom ? ramp(t, [zoom.from, zoom.from + 0.6, zoom.to - 0.5, zoom.to], [1, zoom.scale, zoom.scale, 1], glide) : 1;
  return (
    <AbsoluteFill style={{opacity: ramp(t, [0, 0.3], [0, 1])}}>
      <div style={{position: 'absolute', left: terminal.left, top: terminal.top, width: terminal.width,
        height: terminal.height, borderRadius: terminal.radius, overflow: 'hidden', background: color.base,
        boxShadow: `0 0 0 2px ${color.surface1}`}}>
        <div style={{width: '100%', height: '100%', transform: `scale(${scale})`,
          transformOrigin: zoom ? `${zoom.x * 100}% ${zoom.y * 100}%` : 'center'}}>
          <Footage />
        </div>
      </div>
      {CAPTIONS.map(([event, text], k) => {
        const start = at[event];
        const end = k + 1 < CAPTIONS.length ? at[CAPTIONS[k + 1][0]] : LENGTH + 1;
        // The old caption is gone before the new one comes in, so two never overlap.
        const opacity = Math.min(ramp(t, [start, start + 0.25], [0, 1]), ramp(t, [end - 0.15, end], [1, 0]));
        return (
          <div key={event} style={{position: 'absolute', left: 0, right: 0, top: terminal.top + terminal.height,
            bottom: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity,
            transform: `translateY(${ramp(t, [start, start + 0.25], [8, 0])}px)`,
            fontFamily: font.mono, fontSize: 40, color: color.text}}>
            {text}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

export const Demo = () => (
  <AbsoluteFill style={{background: color.crust}}>
    <Sequence durationInFrames={frames(INTRO)}><Title /></Sequence>
    <Sequence from={frames(INTRO)}><Recording /></Sequence>
  </AbsoluteFill>
);
