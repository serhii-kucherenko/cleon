import {Composition} from 'remotion';
import {Demo, LENGTH} from './Demo';
import {fps, size} from './theme';

export const Root = () => (
  <Composition id="Demo" component={Demo} fps={fps} width={size.width} height={size.height}
    durationInFrames={Math.ceil(LENGTH * fps)} />
);
