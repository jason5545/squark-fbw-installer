import os from 'os';

/**
 * Hosts where the simulator runs inside a Steam compatibility prefix (Proton on Linux, Squark/Wine on macOS)
 * instead of natively. The installer cannot start or autostart Windows background services there.
 */
export const isCompatHost = (): boolean => os.platform() === 'linux' || os.platform() === 'darwin';
