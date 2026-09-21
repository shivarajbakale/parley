/**
 * electron-builder afterPack hook — ad-hoc sign the macOS bundle.
 *
 * There is no Developer ID yet, so electron-builder skips signing. That leaves
 * Electron's original linker signature on a bundle whose contents changed, and
 * Apple Silicon refuses to launch it ("damaged"). An ad-hoc signature over the
 * finished bundle is valid locally; Gatekeeper still asks for a right-click
 * Open on a downloaded copy, which is the expected cost of being un-notarized.
 */
const { execFileSync } = require('node:child_process');
const { join } = require('node:path');

exports.default = async function adhocSign(context) {
  if (context.electronPlatformName !== 'darwin') return;
  const app = join(context.appOutDir, `${context.packager.appInfo.productFilename}.app`);
  execFileSync('codesign', ['--force', '--deep', '--sign', '-', app], { stdio: 'inherit' });
};
